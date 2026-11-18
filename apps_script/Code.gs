/**
 * Pulse Studio - Password Reset OTP Backend (Google Apps Script)
 *
 * Free alternative to Cloud Functions: no billing account, no card, and no
 * Gmail App Password. The script runs as the Google account that deploys it
 * and sends the OTP through MailApp.
 *
 * Endpoint contract (single Web App URL):
 *   POST { action: "request_password_reset", email }
 *        -> { success, requestId, message }
 *   POST { action: "verify_password_reset_otp", email, code, requestId }
 *        -> { success, resetToken, message }
 *   POST { action: "complete_password_reset", requestId, resetToken,
 *          newPassword }
 *        -> { success, message }
 *
 * Security:
 *   - OTPs are 6 digits, valid for 5 minutes, max 5 wrong attempts.
 *   - OTPs and reset tokens are stored only as HMAC-SHA256 hashes.
 *   - Reset tokens are single-use and expire after 15 minutes.
 *   - The new password is never stored by this backend.
 *   - Rate limited per Gmail address (5 requests / 15 minutes) and by the
 *     Gmail daily sending quota (100/day for consumer accounts).
 *
 * Deployment (see apps_script/README.md for screenshots-level steps):
 *   Deploy > New deployment > Web app
 *     Execute as: Me
 *     Who has access: Anyone
 *   Copy the /exec URL into lib/auth/password_recovery_api.dart or pass it
 *   with --dart-define=PULSE_BACKEND_URL=<url>.
 */

var CONFIG = {
  OTP_TTL_MS: 5 * 60 * 1000,
  RESEND_COOLDOWN_MS: 60 * 1000,
  MAX_OTP_ATTEMPTS: 5,
  RESET_TOKEN_TTL_MS: 15 * 60 * 1000,
  MAX_REQUESTS_PER_WINDOW: 5,
  RATE_WINDOW_MS: 15 * 60 * 1000,
  DAILY_EMAIL_LIMIT: 90,
  SESSION_RETENTION_MS: 24 * 60 * 60 * 1000,
  MIN_PASSWORD_LENGTH: 6,
  MAX_PASSWORD_LENGTH: 128
};

var KEYS = {
  SESSION: 'session:',
  ACTIVE: 'active:',
  RATE: 'rate:',
  DAILY: 'daily:',
  SECRET: 'OTP_HMAC_SECRET'
};

var GMAIL_PATTERN =
  /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@gmail\.com$/;

// ---------------------------------------------------------------------------
// HTTP entry points
// ---------------------------------------------------------------------------

/** Health check: open the /exec URL in a browser to confirm deployment. */
function doGet() {
  return json_({
    success: true,
    service: 'pulse-studio-password-reset',
    status: 'ok'
  });
}

function doPost(e) {
  try {
    var body = parseBody_(e);
    var action = String(body.action || '').trim();

    switch (action) {
      case 'request_password_reset':
        return json_(handleRequest_(body));
      case 'verify_password_reset_otp':
        return json_(handleVerify_(body));
      case 'complete_password_reset':
        return json_(handleComplete_(body));
      default:
        return json_({
          success: false,
          error: 'invalid_action',
          message: 'Invalid request.'
        });
    }
  } catch (err) {
    // Never log OTPs, reset tokens, or passwords.
    console.error('Unhandled OTP backend error: ' +
      (err && err.message ? err.message : 'unknown'));
    return json_({
      success: false,
      error: 'server_error',
      message: 'Something went wrong. Please try again.'
    });
  }
}

function parseBody_(e) {
  if (!e || !e.postData || !e.postData.contents) return {};
  try {
    var parsed = JSON.parse(e.postData.contents);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    return {};
  }
}

function json_(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}

// ---------------------------------------------------------------------------
// Action: request a reset code
// ---------------------------------------------------------------------------

function handleRequest_(body) {
  var email = normalizeEmail_(body.email);
  if (!GMAIL_PATTERN.test(email)) {
    return error_('invalid_email',
      'Please enter a valid @gmail.com address.');
  }

  return withLock_(function () {
    var now = Date.now();
    cleanup_(now);

    var rateKey = KEYS.RATE + emailKey_(email);
    var attempts = readJson_(rateKey, []);
    attempts = attempts.filter(function (t) {
      return now - t < CONFIG.RATE_WINDOW_MS;
    });
    if (attempts.length >= CONFIG.MAX_REQUESTS_PER_WINDOW) {
      return error_('rate_limited',
        'Too many code requests. Please try again later.');
    }

    var activeKey = KEYS.ACTIVE + emailKey_(email);
    var activeId = props_().getProperty(activeKey);
    if (activeId) {
      var activeSession = readJson_(KEYS.SESSION + activeId, null);
      if (activeSession &&
          activeSession.email === email &&
          activeSession.resendAvailableAt > now) {
        var waitSeconds = Math.ceil(
          (activeSession.resendAvailableAt - now) / 1000);
        return error_('resend_cooldown',
          'Please wait ' + waitSeconds +
          ' seconds before requesting another code.');
      }
    }

    if (getDailyCount_(now) >= CONFIG.DAILY_EMAIL_LIMIT) {
      return error_('email_quota_exceeded',
        'The email service is temporarily unavailable. Please try again later.');
    }

    var remainingQuota = 0;
    try {
      remainingQuota = MailApp.getRemainingDailyQuota();
    } catch (_) {
      remainingQuota = 1; // let sendEmail surface the real error
    }
    if (remainingQuota < 1) {
      return error_('email_quota_exceeded',
        'The email service is temporarily unavailable. Please try again later.');
    }

    var requestId = Utilities.getUuid();
    var otp = generateOtp_();
    var session = {
      requestId: requestId,
      email: email,
      otpHash: hmacHex_(requestId + ':' + otp),
      createdAt: now,
      expiresAt: now + CONFIG.OTP_TTL_MS,
      resendAvailableAt: now + CONFIG.RESEND_COOLDOWN_MS,
      attempts: 0,
      otpConsumedAt: null,
      resetTokenHash: null,
      resetTokenExpiresAt: null,
      resetTokenConsumedAt: null,
      completedAt: null
    };

    if (activeId && activeId !== requestId) {
      var oldSession = readJson_(KEYS.SESSION + activeId, null);
      if (oldSession) {
        oldSession.invalidatedAt = now;
        writeJson_(KEYS.SESSION + activeId, oldSession);
      }
    }

    writeJson_(KEYS.SESSION + requestId, session);
    props_().setProperty(activeKey, requestId);

    try {
      sendOtpEmail_(email, otp);
    } catch (err) {
      // Roll back so the user can retry immediately.
      deleteKey_(KEYS.SESSION + requestId);
      if (props_().getProperty(activeKey) === requestId) {
        deleteKey_(activeKey);
      }
      console.error('OTP email delivery failed: ' +
        (err && err.message ? err.message : 'unknown'));
      return error_('email_delivery_failed',
        'We could not send the verification email. Please try again.');
    }

    attempts.push(now);
    writeJson_(rateKey, attempts);
    incrementDailyCount_(now);

    return {
      success: true,
      requestId: requestId,
      message: 'A 6-digit verification code was sent to ' + email + '.'
    };
  });
}

// ---------------------------------------------------------------------------
// Action: verify the 6-digit code
// ---------------------------------------------------------------------------

function handleVerify_(body) {
  var email = normalizeEmail_(body.email);
  var code = String(body.code || '').trim();
  var requestId = String(body.requestId || '').trim();

  if (!GMAIL_PATTERN.test(email) || !/^\d{6}$/.test(code) || !requestId) {
    return error_('missing_parameters',
      'Email, verification code, and request ID are required.');
  }

  return withLock_(function () {
    var now = Date.now();
    var session = readJson_(KEYS.SESSION + requestId, null);

    if (!session || session.email !== email) {
      return error_('invalid_request',
        'Invalid or expired verification request. Please request a new code.');
    }

    var activeId = props_().getProperty(KEYS.ACTIVE + emailKey_(email));
    if (activeId !== requestId || session.invalidatedAt) {
      return error_('invalid_request',
        'This code is no longer valid. Please request a new code.');
    }

    if (now >= session.expiresAt) {
      return error_('otp_expired',
        'Verification code has expired. Please request a new one.');
    }

    if (session.otpConsumedAt) {
      return error_('otp_already_used',
        'This code was already used. Please request a new one.');
    }

    if (session.attempts >= CONFIG.MAX_OTP_ATTEMPTS) {
      return error_('too_many_attempts',
        'Too many incorrect attempts. Please request a new code.');
    }

    var expected = hmacHex_(requestId + ':' + code);
    if (!safeEqual_(expected, session.otpHash)) {
      session.attempts += 1;
      writeJson_(KEYS.SESSION + requestId, session);
      var remaining = CONFIG.MAX_OTP_ATTEMPTS - session.attempts;
      return error_('invalid_code', remaining > 0
        ? 'Invalid verification code. Please try again.'
        : 'Too many incorrect attempts. Please request a new code.');
    }

    var resetToken = generateToken_();
    session.otpConsumedAt = now;
    session.resetTokenHash = hmacHex_(requestId + ':' + resetToken);
    session.resetTokenExpiresAt = now + CONFIG.RESET_TOKEN_TTL_MS;
    writeJson_(KEYS.SESSION + requestId, session);

    return {
      success: true,
      resetToken: resetToken,
      message: 'Code verified successfully.'
    };
  });
}

// ---------------------------------------------------------------------------
// Action: consume the single-use reset token
// ---------------------------------------------------------------------------

function handleComplete_(body) {
  var requestId = String(body.requestId || '').trim();
  var resetToken = String(body.resetToken || '').trim();
  var newPassword = String(body.newPassword || '');

  if (!requestId || !resetToken) {
    return error_('missing_parameters',
      'Request ID and reset token are required.');
  }

  if (newPassword.length < CONFIG.MIN_PASSWORD_LENGTH ||
      newPassword.length > CONFIG.MAX_PASSWORD_LENGTH) {
    return error_('weak_password',
      'Use a password with at least ' + CONFIG.MIN_PASSWORD_LENGTH +
      ' characters.');
  }

  return withLock_(function () {
    var now = Date.now();
    var session = readJson_(KEYS.SESSION + requestId, null);

    if (!session || !session.resetTokenHash) {
      return error_('invalid_reset_token',
        'Invalid or expired reset token. Please request a new code.');
    }

    if (session.resetTokenConsumedAt) {
      return error_('invalid_reset_token',
        'This reset token was already used. Please request a new code.');
    }

    if (!session.resetTokenExpiresAt ||
        now >= session.resetTokenExpiresAt) {
      return error_('invalid_reset_token',
        'Your verification expired. Please request a new code.');
    }

    var expected = hmacHex_(requestId + ':' + resetToken);
    if (!safeEqual_(expected, session.resetTokenHash)) {
      return error_('invalid_reset_token',
        'Invalid or expired reset token. Please request a new code.');
    }

    // Consume the token. The app updates the on-device password hash only
    // after this response confirms the token was used exactly once.
    session.resetTokenConsumedAt = now;
    session.completedAt = now;
    writeJson_(KEYS.SESSION + requestId, session);
    deleteKey_(KEYS.ACTIVE + emailKey_(session.email));

    return {
      success: true,
      message: 'Password reset successfully. You can now sign in with your ' +
        'new password.'
    };
  });
}

// ---------------------------------------------------------------------------
// OTP / token helpers
// ---------------------------------------------------------------------------

function normalizeEmail_(email) {
  return String(email || '').trim().toLowerCase();
}

function emailKey_(email) {
  return bytesToHex_(Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256, email));
}

function generateOtp_() {
  var hex = Utilities.getUuid().replace(/-/g, '');
  var value = parseInt(hex.substring(0, 8), 16) % 900000 + 100000;
  return String(value);
}

function generateToken_() {
  return (Utilities.getUuid() + Utilities.getUuid()).replace(/-/g, '');
}

function getSecret_() {
  var p = props_();
  var secret = p.getProperty(KEYS.SECRET);
  if (!secret) {
    secret = Utilities.getUuid() + Utilities.getUuid() +
      Utilities.getUuid();
    p.setProperty(KEYS.SECRET, secret);
  }
  return secret;
}

function hmacHex_(value) {
  return bytesToHex_(Utilities.computeHmacSha256Signature(
    value, getSecret_()));
}

function bytesToHex_(bytes) {
  var out = '';
  for (var i = 0; i < bytes.length; i++) {
    var b = bytes[i];
    if (b < 0) b += 256;
    var h = b.toString(16);
    out += h.length === 1 ? '0' + h : h;
  }
  return out;
}

function safeEqual_(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length !== b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function error_(code, message) {
  return {
    success: false,
    error: code,
    message: message
  };
}

// ---------------------------------------------------------------------------
// Storage, locking, cleanup, quota
// ---------------------------------------------------------------------------

function props_() {
  return PropertiesService.getScriptProperties();
}

function readJson_(key, fallback) {
  var raw = props_().getProperty(key);
  if (!raw) return fallback;
  try {
    return JSON.parse(raw);
  } catch (_) {
    return fallback;
  }
}

function writeJson_(key, value) {
  props_().setProperty(key, JSON.stringify(value));
}

function deleteKey_(key) {
  props_().deleteProperty(key);
}

function withLock_(fn) {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    return error_('busy', 'Please try again in a moment.');
  }
  try {
    return fn();
  } finally {
    lock.releaseLock();
  }
}

function cleanup_(now) {
  var p = props_();
  var all = p.getProperties();
  var todayKey = KEYS.DAILY + dateKey_(now);

  Object.keys(all).forEach(function (key) {
    if (key.indexOf(KEYS.SESSION) === 0) {
      var session = null;
      try {
        session = JSON.parse(all[key]);
      } catch (_) {
        session = null;
      }
      if (!session || !session.createdAt ||
          now - session.createdAt > CONFIG.SESSION_RETENTION_MS) {
        p.deleteProperty(key);
      }
      return;
    }

    if (key.indexOf(KEYS.RATE) === 0) {
      var attempts = null;
      try {
        attempts = JSON.parse(all[key]);
      } catch (_) {
        attempts = null;
      }
      if (!Array.isArray(attempts)) {
        p.deleteProperty(key);
        return;
      }
      var fresh = attempts.filter(function (t) {
        return now - t < CONFIG.RATE_WINDOW_MS;
      });
      if (fresh.length === 0) {
        p.deleteProperty(key);
      } else if (fresh.length !== attempts.length) {
        p.setProperty(key, JSON.stringify(fresh));
      }
      return;
    }

    if (key.indexOf(KEYS.DAILY) === 0 && key !== todayKey) {
      p.deleteProperty(key);
    }
  });
}

function dateKey_(now) {
  var d = new Date(now);
  return d.getFullYear() + '-' +
    ('0' + (d.getMonth() + 1)).slice(-2) + '-' +
    ('0' + d.getDate()).slice(-2);
}

function getDailyCount_(now) {
  return Number(props_().getProperty(KEYS.DAILY + dateKey_(now)) || 0);
}

function incrementDailyCount_(now) {
  props_().setProperty(
    KEYS.DAILY + dateKey_(now),
    String(getDailyCount_(now) + 1));
}

// ---------------------------------------------------------------------------
// Email
// ---------------------------------------------------------------------------

function sendOtpEmail_(email, otp) {
  var expiryMinutes = Math.round(CONFIG.OTP_TTL_MS / 60000);

  var text =
    'Hello,\n\n' +
    'Your Pulse Studio password reset verification code is:\n\n' +
    '    ' + otp + '\n\n' +
    'This code expires in ' + expiryMinutes + ' minutes. ' +
    'If you did not request a password reset, you can safely ignore ' +
    'this email.\n\n' +
    '- Pulse Studio';

  var html =
    '<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;' +
    'margin:0 auto;padding:24px;background:#121212;color:#f5f5f5;' +
    'border-radius:12px;">' +
    '<h2 style="margin:0 0 12px;color:#1db954;">Pulse Studio</h2>' +
    '<p style="margin:0 0 16px;font-size:14px;line-height:1.5;' +
    'color:#cfcfcf;">Use this code to reset your password:</p>' +
    '<div style="font-size:32px;font-weight:bold;letter-spacing:8px;' +
    'text-align:center;padding:16px;background:#1e1e1e;' +
    'border-radius:8px;color:#ffffff;">' + otp + '</div>' +
    '<p style="margin:16px 0 0;font-size:13px;line-height:1.5;' +
    'color:#9e9e9e;">This code expires in ' + expiryMinutes + ' minutes. ' +
    'If you did not request a password reset, you can ignore this email.' +
    '</p>' +
    '</div>';

  MailApp.sendEmail({
    to: email,
    subject: 'Pulse Studio verification code',
    body: text,
    htmlBody: html,
    name: 'Pulse Studio'
  });
}
