# Pulse Studio OTP backend (free Google Apps Script)

This replaces Cloud Functions for password recovery. It needs **no billing
account, no card, and no Gmail App Password**. The script runs as your Google
account and sends the 6-digit code through Gmail.

## What it does

- `request_password_reset` -> generates a 6-digit OTP, emails it, returns a
  `requestId`.
- `verify_password_reset_otp` -> checks the OTP (5 min expiry, 5 attempts max)
  and returns a single-use `resetToken`.
- `complete_password_reset` -> consumes the token (15 min expiry). Only then
  does the phone app change the local password hash.

The new password is **never stored** by the backend.

## One-time deployment (about 3 minutes)

1. Open <https://script.google.com/home> and sign in with the Gmail account
   that should send the codes (for example `johnlaurencenovicio@gmail.com`).
2. Click **New project**.
3. Rename it to **Pulse Studio OTP** (top-left title).
4. Delete the default `myFunction` code and paste the entire contents of
   `apps_script/Code.gs` from this repository.
5. Press **Ctrl+S** to save.
6. Click **Deploy** -> **New deployment**.
7. Click the gear icon next to "Select type" and choose **Web app**.
8. Set:
   - **Description:** Pulse Studio OTP v1
   - **Execute as:** Me
   - **Who has access:** Anyone
9. Click **Deploy**.
10. Click **Authorize access**, choose your Google account, then
    **Advanced** -> **Go to Pulse Studio OTP (unsafe)** -> **Allow**.
    (This warning is normal for your own personal script.)
11. Copy the **Web app URL**. It looks like:
    `https://script.google.com/macros/s/AKfycb.../exec`
12. Save that URL to:
    `C:\Users\johnl\AppData\Local\Temp\opencode\apps_script_url.txt`

Then tell the assistant "done" so it can wire the URL into the app, rebuild
the APK, and test the real email flow.

## Limits and notes

- Gmail consumer accounts can send 100 emails/day. The script stops at 90/day
  and limits each address to 5 requests per 15 minutes.
- The URL is the endpoint. Treat it like a password: do not post it publicly.
- To change the code later: edit the script, then
  **Deploy -> Manage deployments -> Edit (pencil) -> New version -> Deploy**.
- The first request creates `OTP_HMAC_SECRET` automatically in Script
  Properties. Do not delete it, or pending codes/tokens become invalid.

## Quick test (optional)

After deployment, open the `/exec` URL in a browser. It should show:

```json
{"success":true,"service":"pulse-studio-password-reset","status":"ok"}
```

To request a real code from a terminal (PowerShell):

```powershell
curl.exe -L -X POST "PASTE_WEB_APP_URL_HERE" `
  -H "Content-Type: application/json" `
  -d '{\"action\":\"request_password_reset\",\"email\":\"YOUR_ADDRESS@gmail.com\"}'
```

The response includes a `requestId` and Gmail should receive the code.
