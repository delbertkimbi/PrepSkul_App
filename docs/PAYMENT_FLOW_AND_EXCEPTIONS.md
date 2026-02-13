# Payment Flow and Exceptions (Production vs Sandbox)

## Mode selection

- **Production**: `AppConfig.isProduction = true` (in `lib/core/config/app_config.dart`)  
  - Fapshi base URL: `https://live.fapshi.com`  
  - Credentials: `FAPSHI_COLLECTION_API_USER_LIVE`, `FAPSHI_COLLECTION_API_KEY_LIVE`  
  - Real money is charged; user receives payment request on phone.

- **Sandbox**: `AppConfig.isProduction = false`  
  - Fapshi base URL: `https://sandbox.fapshi.com`  
  - Credentials: `FAPSHI_SANDBOX_API_USER`, `FAPSHI_SANDBOX_API_KEY`  
  - No real money; sandbox test numbers auto-succeed/fail without real requests.

---

## Payment flow (high level)

1. User enters phone (MTN/Orange) and confirms amount.
2. App calls `FapshiService.initiateDirectPayment()` → POST to Fapshi `direct-pay`.
3. App receives `transId` and polls `FapshiService.pollPaymentStatus()` (or in production can rely on webhook + DB).
4. On **SUCCESSFUL**: app completes payment (e.g. marks trial/session as paid, may call backend).
5. On **FAILED** or **timeout**: app shows error and does not complete payment.

---

## Exceptions by step

### 1. Before calling Fapshi (validation)

| Condition | Exception / behavior |
|-----------|----------------------|
| Missing API user/key | `Payment service is not configured. Please contact support.` |
| Amount &lt; 100 XAF | `Amount must be at least 100 XAF` |
| Invalid phone (normalize fails) | `Please enter a valid phone number. Use format: 67XXXXXXX or 69XXXXXXX (MTN or Orange Cameroon)` |
| Sandbox + test number | Log warning only; request still sent (sandbox may auto-succeed/fail). |

### 2. Initiate payment (POST direct-pay)

| Case | Production | Sandbox |
|------|------------|--------|
| **200 + valid JSON** | Returns `FapshiPaymentResponse` with `transId`. | Same. |
| **200 + “Direct Pay disabled/not enabled/not available” in message** | `Payment processing encountered an unexpected issue. Please try again in a moment, or contact support if the problem persists.` | Same. |
| **200 + body not parseable** | `Received an invalid response from the payment provider. Please try again.` | Same. |
| **Non-200 + JSON body** | Error message from Fapshi (e.g. `message` / `error`) converted to user-friendly text and thrown. | Same. |
| **Non-200 + non-JSON (e.g. HTML)** | 401/403 → `Payment service authentication failed. Please contact support.`; 400 → `Invalid payment request. Please check your phone number and try again.`; 5xx → `Payment service is temporarily unavailable. Please try again later.`; else → `Payment request failed. Please try again.` | Same. |
| **Request timeout (30s)** | `Payment request timed out. Please check your internet connection and try again.` | Same. |
| **Network (e.g. ClientException)** | `Network error. Please check your internet connection and try again.` | Same. |
| **Other** | Converted to user-friendly message via `_convertToUserFriendlyError`. | Same. |

### 3. Poll payment status (GET payment-status/:transId)

| Case | Production | Sandbox |
|------|------------|--------|
| **200 + valid JSON** | Returns `FapshiPaymentStatus` (e.g. SUCCESSFUL, FAILED, PENDING). | Same. |
| **200 + non-JSON (e.g. HTML)** | `Unexpected response from payment provider while checking status. Please try again shortly.` | Same. |
| **200 + JSON parse error** | `Received an invalid response from the payment provider while checking status.` | Same. |
| **Non-200 + JSON** | `Fapshi API Error: <message>` | Same. |
| **Non-200 + non-JSON** | `Payment status request failed with status <code>. Please try again.` | Same. |
| **Any error during polling** | Re-thrown so UI can show feedback instead of spinning. | Same. |

### 4. Polling behavior (success “too fast”)

- **Both modes**: If status becomes SUCCESSFUL before `minWaitTime` (default 10s), app waits the remaining time and re-checks.
- **Sandbox**: Log warns that payment succeeded without phone notification (normal for test numbers).
- **Production**: Ensures the user had time to receive and confirm the request on their phone.

### 5. After max polling attempts

- App calls `getPaymentStatus(transId)` once more and returns that final status (e.g. still PENDING, or SUCCESSFUL/FAILED).
- **Sandbox**: In some flows, “still pending after max attempts” can be treated as success for testing (see `payment_confirmation_screen` / booking payment screen).
- **Production**: Typically treat only explicit SUCCESSFUL as success.

---

## Sandbox-only behavior

- **Test numbers** (e.g. 670000000, 670000002, 690000000, 670000001, 690000001): No real payment request is sent; Fapshi sandbox may auto-succeed or auto-fail. App still calls the same APIs; only the backend behavior differs.
- **Fake transId on error**: If `initiateDirectPayment` fails in sandbox, the booking payment screen may create a placeholder `transId` (e.g. `sandbox_error_...`) so you can still test the rest of the flow.
- **“Mark as paid” / manual webhook**: In sandbox, the UI may show a button to simulate success (calls `FapshiWebhookService.handleWebhook` locally) for testing.

---

## Production-only behavior

- **Real charges**: Every successful payment charges real money.
- **Webhook**: Backend receives Fapshi webhooks at `/api/webhooks/fapshi` and updates DB; app may also poll status.
- **Database-first check**: In production, polling may check DB (e.g. `trial_sessions.payment_status`, `session_payments`) for webhook updates before calling Fapshi again.

---

## Quick reference: where exceptions are thrown

- **FapshiService.initiateDirectPayment**: validation, timeout, HTTP/JSON errors, network, and generic user-friendly conversion.
- **FapshiService.getPaymentStatus**: non-JSON response, parse error, non-200 with/without JSON.
- **FapshiService.pollPaymentStatus**: rethrows errors from `getPaymentStatus`; no extra exception types.
- **BookingPaymentScreen / TrialPaymentScreen**: catch errors from Fapshi and show `ErrorHandler.getUserFriendlyMessage()` or similar.

---

## Flutter run issue: “Failed host lookup: pub.dev”

This is a **network/DNS** error: the machine cannot resolve `pub.dev` when Flutter tries to fetch package advisories during `flutter pub get` / `flutter run`.

**What to do:**

1. **Check internet**: Ensure the device has internet and can open https://pub.dev in a browser.
2. **Run offline (if packages were already resolved once):**
   ```bash
   cd prepskul_app
   flutter pub get --offline
   flutter run
   ```
3. **Bypass advisory fetch (Flutter 3.16+):**
   ```bash
   flutter pub get --no-pub-auth
   ```
   Or set:
   ```bash
   export PUB_HOSTED_URL=https://pub.dev
   export FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
   ```
   and retry `flutter run`.
4. **DNS**: If you use VPN/proxy, try turning it off. On macOS you can flush DNS:
   ```bash
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
   ```
   Then try `flutter run` again.
5. **Different network**: Try another Wi‑Fi or mobile hotspot to rule out firewall/DNS blocking of pub.dev.

Once `pub.dev` is reachable (or you use `--offline` with a valid cache), `flutter run` should get past “Downloading packages” and start the app.
