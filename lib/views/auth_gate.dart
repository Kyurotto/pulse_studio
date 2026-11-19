import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/auth_service.dart';
import '../auth/saved_credential_store.dart';
import '../data/local_database.dart';
import '../services/biometric_auth_service.dart';
import '../theme/app_theme.dart';
import 'forgot_password_dialog.dart';
import 'music_dashboard_view.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object?>(
      stream: AuthService.instance.authChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        if (!AuthService.instance.isInitialized &&
            AuthService.instance.currentUser == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data ?? AuthService.instance.currentUser;
        if (user == null) {
          return const AuthView();
        }
        return StreamBuilder<bool>(
          stream: AuthService.instance.lockChanges,
          initialData: AuthService.instance.isAppLocked,
          builder: (context, lockSnapshot) {
            final isLocked =
                lockSnapshot.data ?? AuthService.instance.isAppLocked;
            if (isLocked) {
              return BiometricLockView(user: user);
            }
            return const MusicDashboardView();
          },
        );
      },
    );
  }
}

class BiometricLockView extends StatefulWidget {
  final Object user;
  const BiometricLockView({super.key, required this.user});

  @override
  State<BiometricLockView> createState() => _BiometricLockViewState();
}

class _BiometricLockViewState extends State<BiometricLockView> {
  bool _isBusy = false;
  String? _errorMessage;

  String get _displayName {
    final u = widget.user;
    if (u is LocalUser && u.displayName.trim().isNotEmpty) {
      return u.displayName.trim();
    }
    if (u is User && (u.displayName ?? '').trim().isNotEmpty) {
      return u.displayName!.trim();
    }
    final name = AuthService.instance.userDisplayName.trim();
    if (name.isNotEmpty && name.toLowerCase() != 'guest') {
      return name;
    }
    final email = _email;
    if (email.isNotEmpty && email.contains('@')) {
      return email.split('@').first;
    }
    return 'User';
  }

  String get _email {
    final u = widget.user;
    if (u is LocalUser) return u.email.trim();
    if (u is User) return (u.email ?? '').trim();
    return '';
  }

  Future<void> _unlock() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final success = await AuthService.instance.unlockWithBiometrics();
      if (!success && mounted) {
        setState(() {
          _errorMessage =
              'Biometric verification was not completed. Please try again or use your password.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _usePassword() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await AuthService.instance.lockToPasswordSignIn();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final unlockButtonLabel = isWindows
        ? 'Unlock with Windows Hello'
        : 'Unlock with Biometrics';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 52,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pulse Studio Locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Welcome back, $_displayName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  if (_email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Verify your identity using device biometrics to unlock Pulse Studio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withAlpha(100)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton.icon(
                    onPressed: _isBusy ? null : _unlock,
                    icon: const Icon(Icons.fingerprint_rounded, size: 22),
                    label: Text(unlockButtonLabel),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isBusy ? null : _usePassword,
                    icon: const Icon(Icons.password_rounded, size: 18),
                    label: const Text('Use Password Instead'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                  if (_isBusy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthView extends StatefulWidget {
  /// Optional test seams. Production uses the app-wide singletons.
  final SavedCredentialStore? credentialStore;
  final BiometricAuthService? biometricService;

  const AuthView({super.key, this.credentialStore, this.biometricService});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFieldKey = GlobalKey();
  final _emailFieldLink = LayerLink();
  final _savedAccountsMenu = OverlayPortalController();
  late final SavedCredentialStore _credentials;
  late final BiometricAuthService _biometrics;
  List<Map<String, Object?>> _rememberedAccounts = const [];
  Set<String> _fingerprintEmails = const {};
  Set<String> _savedPasswordEmails = const {};
  String? _selectedAccountEmail;
  double _savedAccountsMenuWidth = 320;
  bool _loadingSavedAccounts = true;
  bool _isRegistering = false;
  bool _isBusy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = true;

  /// Accounts whose tap can go straight to the device biometric prompt.
  /// Includes accounts with a saved password and local-only accounts that can
  /// be restored after verification, even if an older build never stored a
  /// password for them.
  bool _canUseFingerprintFor(String email) =>
      _fingerprintEmails.contains(email);

  bool get _canSignInWithFingerprint =>
      !_isRegistering &&
      _selectedAccountEmail != null &&
      _canUseFingerprintFor(_selectedAccountEmail!);

  @override
  void initState() {
    super.initState();
    _credentials = widget.credentialStore ?? SavedCredentialStore.instance;
    _biometrics = widget.biometricService ?? BiometricAuthService.instance;
    _loadSavedAccounts();
  }

  /// Loads the accounts saved by "Remember me" and fills the most useful one.
  ///
  /// A one-shot email from the accounts drawer takes priority. Otherwise the
  /// most recently used saved account is selected automatically, so its saved
  /// password is autofilled and the fingerprint button is visible immediately.
  /// The panel still lets the user pick a different saved account.
  Future<void> _loadSavedAccounts({String? preferredEmail}) async {
    try {
      final accounts = await LocalDatabase.instance.getRememberedAccounts();

      var oneShotEmail = '';
      if (preferredEmail == null) {
        oneShotEmail =
            (await LocalDatabase.instance.getSetting(
              AuthService.authPrefillEmailKey,
            ))?.trim().toLowerCase() ??
            '';
        if (oneShotEmail.isNotEmpty) {
          await LocalDatabase.instance.removeSetting(
            AuthService.authPrefillEmailKey,
          );
        }
      }

      final passwordEmails = <String>{};
      final fingerprintEmails = <String>{};
      // Device biometrics is what gates the prompt, not a previously saved
      // toggle: an account remembered by an older build may have neither a
      // password nor the biometric flag yet, and the first tap should still be
      // able to set both up.
      final biometricsAvailable =
          _biometrics.isPlatformSupported &&
          await _biometrics.isBiometricEnrolled();
      for (final row in accounts) {
        final email = (row['email'] as String? ?? '').trim().toLowerCase();
        if (email.isEmpty) continue;
        try {
          final savedPassword = await _credentials.readPassword(email);
          if (savedPassword != null && savedPassword.isNotEmpty) {
            passwordEmails.add(email);
          }
        } catch (_) {}
        if (!biometricsAvailable) continue;
        if (passwordEmails.contains(email)) {
          fingerprintEmails.add(email);
          continue;
        }
        try {
          // Local-only accounts can be restored after the device verifies the
          // user, so existing remembered accounts work even when their
          // plaintext password was never stored by an older build.
          if (await AuthService.instance.canSignInLocallyWithBiometrics(
            email,
          )) {
            fingerprintEmails.add(email);
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _rememberedAccounts = accounts;
        _fingerprintEmails = fingerprintEmails;
        _savedPasswordEmails = passwordEmails;
        _loadingSavedAccounts = false;
      });

      String selected = '';
      if (preferredEmail != null && preferredEmail.trim().isNotEmpty) {
        selected = preferredEmail.trim().toLowerCase();
      } else if (oneShotEmail.isNotEmpty) {
        selected = oneShotEmail;
      } else if (accounts.isNotEmpty) {
        // getRememberedAccounts() returns the most recently used account
        // first. Selecting it keeps the fingerprint button visible after
        // signing out, even when more than one account is saved.
        selected = (accounts.first['email'] as String? ?? '')
            .trim()
            .toLowerCase();
      }
      if (selected.isNotEmpty) {
        await _selectSavedAccount(selected);
      }
    } catch (error) {
      debugPrint('[AuthView] Could not load saved accounts: $error');
      if (mounted) setState(() => _loadingSavedAccounts = false);
    }
  }

  /// Fills the form with a remembered account and its securely stored
  /// password. Never stores or logs the password anywhere else.
  Future<void> _selectSavedAccount(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;

    _closeSavedAccountsMenu();

    String? savedPassword;
    try {
      savedPassword = await _credentials.readPassword(cleanEmail);
    } catch (_) {}

    if (!mounted) return;
    final hasSavedPassword = savedPassword != null && savedPassword.isNotEmpty;
    setState(() {
      _isRegistering = false;
      _selectedAccountEmail = cleanEmail;
      if (hasSavedPassword) {
        _savedPasswordEmails = {..._savedPasswordEmails, cleanEmail};
      }
      _emailController.text = cleanEmail;
      _emailController.selection = TextSelection.collapsed(
        offset: cleanEmail.length,
      );
      _passwordController.text = savedPassword ?? '';
      _passwordController.selection = TextSelection.collapsed(
        offset: _passwordController.text.length,
      );
    });

    if (hasSavedPassword) {
      // Clears any stale "invalid email/password" validation error.
      _formKey.currentState?.validate();
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Handles a tap on a saved account in the autofill dropdown.
  ///
  /// The account always fills both fields with its encrypted saved password.
  /// When fingerprint login is set up for it, the device biometric prompt opens
  /// immediately and a successful check signs in with that same saved
  /// password — no retyping needed.
  Future<void> _useSavedAccount(String email) async {
    if (_isBusy) return;
    final cleanEmail = email.trim().toLowerCase();
    final canUseFingerprint = _canUseFingerprintFor(cleanEmail);
    await _selectSavedAccount(cleanEmail);
    if (!mounted || !canUseFingerprint) return;
    await _signInWithFingerprint(email: cleanEmail);
  }

  bool get _hasSavedAccountsToShow =>
      !_isRegistering &&
      !_loadingSavedAccounts &&
      _rememberedAccounts.isNotEmpty;

  /// Floats the saved-account menu directly under the email field, the same
  /// way a password manager autofill popup appears.
  void _openSavedAccountsMenu() {
    if (!_hasSavedAccountsToShow) return;
    final fieldBox =
        _emailFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (fieldBox != null && fieldBox.hasSize) {
      _savedAccountsMenuWidth = fieldBox.size.width;
    }
    if (!_savedAccountsMenu.isShowing) {
      _savedAccountsMenu.show();
    }
  }

  void _closeSavedAccountsMenu() {
    if (_savedAccountsMenu.isShowing) {
      _savedAccountsMenu.hide();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode(bool isRegistering) {
    if (_isRegistering == isRegistering) return;
    _closeSavedAccountsMenu();
    final previousSelected = _selectedAccountEmail;
    setState(() {
      _isRegistering = isRegistering;
      _selectedAccountEmail = null;
      _formKey.currentState?.reset();
      _confirmPasswordController.clear();
    });
    if (!isRegistering && previousSelected != null) {
      _selectSavedAccount(previousSelected);
    }
  }

  Future<void> _submit() async {
    _closeSavedAccountsMenu();
    if (!_formKey.currentState!.validate()) return;
    if (_isRegistering &&
        _passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match.');
      return;
    }
    setState(() => _isBusy = true);
    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      if (_isRegistering) {
        // Works online + offline: AuthService falls back to local SQLite
        // when Firebase is unreachable (no Wi-Fi/data), so the same
        // button creates the account either way.
        await AuthService.instance.register(
          email: email,
          password: password,
          persistSession: _rememberMe,
        );
      } else {
        await AuthService.instance.signInWithEmail(
          email: email,
          password: password,
          persistSession: _rememberMe,
        );
      }
      // Save the account + password first so a platform autofill hiccup can
      // never leave a successful sign-in without its remembered credentials.
      await _rememberSignedInAccount(email: email, password: password);

      // Tell the browser / OS the autofill context is complete so Chrome,
      // Edge, Safari, etc. offer to SAVE the email+password into their
      // built-in password manager. Next visit the browser autofills BOTH
      // fields automatically.
      try {
        TextInput.finishAutofillContext(shouldSave: true);
      } catch (_) {}
    } on FirebaseAuthException catch (error) {
      _showError(_friendlyError(error));
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Keeps the "Remember me" contract:
  /// - checked: save the account, store the password in encrypted storage,
  ///   and enable fingerprint login for it when the device has biometrics.
  /// - unchecked: forget the account and delete its saved password.
  ///
  /// The SQLite session row is always kept for the current run because it is
  /// also the clock for claimAnonymousPlaylists; persistence is decided at the
  /// next startup from [LocalDatabase.setPersistSession].
  Future<void> _rememberSignedInAccount({
    required String email,
    required String password,
  }) async {
    try {
      await LocalDatabase.instance.setPersistSession(_rememberMe);
      if (!_rememberMe) {
        await LocalDatabase.instance.removeRememberedAccount(email);
        await _credentials.deletePassword(email);
        final accountId = AuthService.instance.currentUserId;
        if (accountId.isNotEmpty &&
            await _biometrics.isBiometricUnlockEnabled(accountId)) {
          await _biometrics.disableBiometricUnlock();
        }
        return;
      }

      await LocalDatabase.instance.saveRememberedAccount(
        email: email,
        displayName: AuthService.instance.userDisplayName,
      );
      await _credentials.savePassword(email, password);

      final accountId = AuthService.instance.currentUserId;
      if (accountId.isEmpty || !_biometrics.isPlatformSupported) return;
      if (!await _biometrics.isBiometricEnrolled()) return;
      await _biometrics.enableBiometricUnlock(accountId);
      if (!mounted) return;
      setState(() {
        _fingerprintEmails = {..._fingerprintEmails, email};
        _selectedAccountEmail = email;
      });
    } catch (error) {
      debugPrint('[AuthView] Could not remember account: $error');
    }
  }

  /// Verifies the device fingerprint, then signs in with the password saved
  /// for [email] in the platform keystore.
  ///
  /// Local-only accounts remembered before encrypted password storage existed
  /// have no saved password; those are restored directly from SQLite after the
  /// biometric check, and biometric login is enabled for the next tap.
  Future<void> _signInWithFingerprint({String? email}) async {
    if (_isBusy) return;
    final cleanEmail = (email ?? _selectedAccountEmail ?? _emailController.text)
        .trim()
        .toLowerCase();
    if (cleanEmail.isEmpty) {
      _showError('Choose a saved account first.');
      return;
    }

    setState(() => _isBusy = true);
    try {
      final local = await LocalDatabase.instance.getUserByEmail(cleanEmail);
      final accountId = (local?['id'] as String?) ?? '';
      final password = await _credentials.readPassword(cleanEmail);
      final hasSavedPassword = password != null && password.isNotEmpty;
      final canRestoreLocally = await AuthService.instance
          .canSignInLocallyWithBiometrics(cleanEmail);
      final biometricsAvailable =
          _biometrics.isPlatformSupported &&
          await _biometrics.isBiometricEnrolled();

      if (!biometricsAvailable) {
        _showError(
          'Biometric sign-in is not set up on this device. '
          'Add a fingerprint or Windows Hello in device settings.',
        );
        return;
      }
      if (!hasSavedPassword && !canRestoreLocally) {
        _showError(
          'No saved password for $cleanEmail. '
          'Sign in with your password once to enable fingerprint login.',
        );
        return;
      }

      final verified = await _biometrics.authenticateForUnlock(
        customReason: 'Sign in to Pulse Studio',
      );
      if (!verified) {
        _showError(
          'Fingerprint verification was not completed. '
          'Try again or use your password.',
        );
        return;
      }

      if (hasSavedPassword) {
        await AuthService.instance.signInWithSavedPassword(
          email: cleanEmail,
          password: password,
        );
      } else {
        await AuthService.instance.signInWithLocalBiometrics(cleanEmail);
      }

      // Mark this account as fingerprint-ready so the next tap signs in
      // immediately, even though no plaintext password could be saved.
      if (accountId.isNotEmpty) {
        await _biometrics.enableBiometricUnlock(accountId);
        if (mounted) {
          setState(() {
            _fingerprintEmails = {..._fingerprintEmails, cleanEmail};
          });
        }
      }
      try {
        TextInput.finishAutofillContext(shouldSave: true);
      } catch (_) {}
    } on FirebaseAuthException catch (error) {
      _showError(_friendlyError(error));
    } catch (error) {
      debugPrint('[AuthView] Fingerprint sign-in failed: $error');
      _showError('Fingerprint sign-in failed. Please use your password.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _openForgotPassword() {
    _closeSavedAccountsMenu();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
        onPasswordResetSuccess: (email) {
          if (!mounted) return;
          setState(() {
            _isRegistering = false;
            _confirmPasswordController.clear();
          });
          // The dialog already saved the account and the new password in
          // encrypted storage. Reloading fills the form with both.
          _loadSavedAccounts(preferredEmail: email);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'Password reset successfully! Please sign in with your new password.',
              ),
            ),
          );
        },
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already uses that email address.';
      case 'account-exists-with-different-credential':
        return error.message ??
            'An account already exists with this email address using a different sign-in method.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email address or password.';
      case 'weak-password':
        return 'Use a password with at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'login-cancelled':
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Sign-in was cancelled.';
      case 'operation-not-allowed':
        return 'Authentication failed. Please verify your credentials and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your connection and try again — your account is saved on this device and works offline.';
      case 'app-not-authorized':
      case 'unauthorized-domain':
        return 'This app or domain is not authorized for social login. Check your Facebook and Firebase settings.';
      case 'configuration-not-found':
        return error.message ??
            'Authentication failed. Please verify your credentials and try again.';
      default:
        final msg = (error.message ?? '').toLowerCase();
        if (msg.contains('network') ||
            msg.contains('socket') ||
            msg.contains('offline') ||
            msg.contains('unreachable')) {
          return 'No internet connection. Please check your connection and try again — your account is saved on this device and works offline.';
        }
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// Full-screen barrier plus the floating card anchored under the email
  /// field. Tapping anywhere outside the card dismisses it.
  Widget _buildSavedAccountsOverlay(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeSavedAccountsMenu,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _emailFieldLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: SizedBox(
              width: _savedAccountsMenuWidth,
              child: _buildSavedAccountsCard(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedAccountsCard(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final border = AppTheme.borderActiveOf(context);
    final textMuted = AppTheme.textMutedOf(context);

    return Material(
      color: AppTheme.cardSurfaceOf(context),
      elevation: 12,
      shadowColor: Colors.black.withAlpha(isDark ? 170 : 45),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeSavedAccountsMenu,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 12, 9),
                child: Row(
                  children: [
                    Icon(
                      Icons.manage_accounts_outlined,
                      size: 16,
                      color: textMuted,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Saved accounts',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: textMuted,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: textMuted,
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: AppTheme.borderOf(context)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (
                      var index = 0;
                      index < _rememberedAccounts.length;
                      index++
                    ) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 58,
                          endIndent: 12,
                          color: AppTheme.borderOf(context),
                        ),
                      _buildSavedAccountMenuItem(
                        context,
                        _rememberedAccounts[index],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAccountMenuItem(
    BuildContext context,
    Map<String, Object?> account,
  ) {
    final email = (account['email'] as String? ?? '').trim();
    final name = (account['display_name'] as String? ?? '').trim();
    final displayName = name.isEmpty ? email.split('@').first : name;
    final cleanEmail = email.toLowerCase();
    final isSelected = _selectedAccountEmail == cleanEmail;
    final hasSavedPassword = _savedPasswordEmails.contains(cleanEmail);
    final canUseFingerprint = _canUseFingerprintFor(cleanEmail);
    final primary = AppTheme.primaryOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    final textMuted = AppTheme.textMutedOf(context);

    return Semantics(
      button: true,
      label: canUseFingerprint
          ? 'Use saved account $email and sign in with fingerprint'
          : 'Use saved account $email',
      child: Material(
        color: isSelected ? primary.withAlpha(14) : Colors.transparent,
        child: InkWell(
          onTap: _isBusy ? null : () => _useSavedAccount(email),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: primary.withAlpha(26),
                  child: Text(
                    _initialsFor(displayName, email),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            hasSavedPassword
                                ? Icons.lock_outline_rounded
                                : canUseFingerprint
                                ? Icons.fingerprint_rounded
                                : Icons.lock_open_rounded,
                            size: 11,
                            color: textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hasSavedPassword
                                  ? '••••••••'
                                  : canUseFingerprint
                                  ? 'Fingerprint sign-in ready'
                                  : 'Password not saved',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                letterSpacing: hasSavedPassword ? 1.6 : 0,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canUseFingerprint)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 20,
                      color: primary,
                    ),
                  ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 20, color: primary)
                else
                  const SizedBox(width: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _initialsFor(String name, String email) {
    final source = name.trim().isNotEmpty
        ? name.trim()
        : email.split('@').first;
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final value = parts.first;
      return value.substring(0, value.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
              ),
              // AutofillGroup lets the browser / OS password manager treat the
              // email + password as one credential, so picking an account
              // fills BOTH fields. Without it, only the email gets filled
              // and the password stays blank (the bug in the screenshot).
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  // Each field opts into onUserInteraction individually. If the
                  // whole Form validated on interaction, programmatically
                  // selecting a saved account would immediately flag the
                  // still-empty password field before the user touches it.
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        size: 52,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isRegistering ? 'Create account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRegistering
                            ? 'Enter your email and choose a password to get started.'
                            : 'Sign in to continue to Pulse Studio.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 18),

                      OverlayPortal(
                        controller: _savedAccountsMenu,
                        overlayChildBuilder: _buildSavedAccountsOverlay,
                        child: CompositedTransformTarget(
                          link: _emailFieldLink,
                          child: TextFormField(
                            key: _emailFieldKey,
                            controller: _emailController,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            // Tapping the field (or its floating label) opens
                            // the saved-account autofill popup, like a password
                            // manager dropdown.
                            onTap: _openSavedAccountsMenu,
                            onChanged: (value) {
                              _closeSavedAccountsMenu();
                              final clean = value.trim().toLowerCase();
                              if (_selectedAccountEmail != null &&
                                  clean != _selectedAccountEmail) {
                                setState(() {
                                  _selectedAccountEmail = null;
                                });
                              }
                            },
                            // Tells Chrome/Edge/Safari this is the
                            // username/email of the credential. The browser
                            // saves + autofills email AND password together.
                            autofillHints: _isRegistering
                                ? const [AutofillHints.email]
                                : const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                            enableSuggestions: true,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              hintText: 'name@example.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return 'Enter an email address.';
                              if (!v.contains('@') || !v.contains('.')) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        obscureText: _obscurePassword,
                        // password = existing credential (browser autofills the
                        // saved password automatically, just like the email);
                        // newPassword = new credential (browser offers to save).
                        autofillHints: _isRegistering
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        enableSuggestions: !_isRegistering,
                        autocorrect: false,
                        textInputAction: _isRegistering
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: _isRegistering
                            ? null
                            : (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) => value != null && value.length >= 6
                            ? null
                            : 'Use at least 6 characters.',
                      ),
                      if (!_isRegistering &&
                          _selectedAccountEmail != null &&
                          _passwordController.text.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            'Saved password filled — tap the eye icon to view it.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      if (_isRegistering) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          obscureText: _obscureConfirmPassword,
                          autofillHints: const [AutofillHints.newPassword],
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: const Icon(
                              Icons.lock_reset_outlined,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (!_isRegistering) return null;
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password.';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppTheme.primary,
                                  onChanged: _isBusy
                                      ? null
                                      : (v) => setState(
                                          () => _rememberMe = v ?? true,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _isBusy
                                    ? null
                                    : () => setState(
                                        () => _rememberMe = !_rememberMe,
                                      ),
                                child: const Text(
                                  'Remember me',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_isRegistering)
                            Flexible(
                              child: TextButton(
                                onPressed: _isBusy ? null : _openForgotPassword,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isBusy ? null : _submit,
                        child: Text(
                          _isRegistering ? 'Create account' : 'Sign in',
                        ),
                      ),
                      if (_canSignInWithFingerprint) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _isBusy
                              ? null
                              : () => _signInWithFingerprint(),
                          icon: const Icon(Icons.fingerprint_rounded, size: 22),
                          label: const Text('Sign in with fingerprint'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: BorderSide(
                              color: AppTheme.primary.withAlpha(120),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      const Text(
                        'Works offline — no Wi-Fi or data needed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (_isBusy)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _isRegistering
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: _isBusy
                                ? null
                                : () => _toggleMode(!_isRegistering),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _isRegistering ? 'Sign in' : 'Create account',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text.rich(
                        TextSpan(
                          text: 'By continuing, you agree to Pulse Studio\'s ',
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
