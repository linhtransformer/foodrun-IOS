# Xcode setup — one-time steps for the Foodrun target

These clicks live only in the Xcode project (`Foodrun.xcodeproj` created on the Mac —
see `README.md` §First-time setup). Every step is required for the app to build with the
Phase 1 NFC clock-in code that just landed.

## 1. Enable Near Field Communication Tag Reading

- Project → target `Foodrun` → **Signing & Capabilities** → `+ Capability`.
- Add **Near Field Communication Tag Reading**.
- This does two things: adds `com.apple.developer.nfc.readersession.formats = ["NDEF"]`
  to the entitlements file, and registers the app ID for NFC in your Apple Developer
  account.

## 2. Add the NFC usage string to Info.plist

- Project → target `Foodrun` → **Info** → add a new row:
  - Key: `NSNFCReaderUsageDescription` (Xcode shows this as *"Privacy - NFC Scan Usage
    Description"*).
  - Value: `Foodrun uses NFC to let you clock in and out by tapping the tag on your truck.`
- Without this key, `NFCNDEFReaderSession.begin()` traps at runtime.

## 2b. Sign In with Apple capability + iPhone only

Both are already in `project.yml` — `xcodegen generate` applies them:
- Entitlement `com.apple.developer.applesignin = ["Default"]` (Signing & Capabilities
  shows **Sign In with Apple**). Needs a paid developer team.
- `TARGETED_DEVICE_FAMILY: "1"` → iPhone only (General → Supported Destinations).
  See `APP_STORE_CHECKLIST.md` §2.

## 2c. Auth providers + email (server side, VPS — not Xcode)

The app code for these is done; each needs the matching switch on the self-hosted
Supabase auth service: edit `/opt/supabase-vietnamama/.env` on the VPS (the names below;
`docker-compose.yml` maps them to `GOTRUE_*`), then
`docker compose -f docker-compose.yml -f deploy/docker-compose.override.yml up -d auth`.

**Status 2026-10-07: all of this is live** — Resend SMTP (`noreply@foodrun.nl`), Apple +
Google enabled, redirect allow-list incl. `foodrun://auth-callback`, and the reset email
template with the 6-digit code (`GOTRUE_MAILER_TEMPLATES_RECOVERY` in
`deploy/docker-compose.override.yml` → `https://foodrun.nl/email-templates/reset-password.html`,
served from the HQ repo's `public/`). Verified end to end. The steps below are kept as
reference for rebuilding the server.

**Email via Resend** (sign-up confirmation, password-reset code, invites):
1. Resend dashboard → Domains → add `foodrun.nl` → add the DNS records it shows
   (on `send.foodrun.nl` + a DKIM TXT — they don't touch the existing MX).
2. `.env`: `SMTP_HOST=smtp.resend.com`, `SMTP_PORT=587`, `SMTP_USER=resend`,
   `SMTP_PASS=<Resend API key>`, `SMTP_ADMIN_EMAIL=no-reply@foodrun.nl`,
   `SMTP_SENDER_NAME=Foodrun`.
3. Reset-password template must contain the code: `{{ .Token }}` (the app asks for the
   6-digit code instead of using a link).

**Redirects:** `.env` `ADDITIONAL_REDIRECT_URLS=foodrun://auth-callback,https://foodrun.nl/**`

**Sign in with Apple** (native, id-token flow):
1. developer.apple.com → Identifiers → App ID `nl.foodrun.app` → enable Sign In with Apple.
2. `.env`: `APPLE_ENABLED=true`, and `APPLE_CLIENT_ID` must **include the bundle ID** `nl.foodrun.app` (comma-separate it next to the web
   Services ID if there is one). Native id-token sign-in needs no secret.

**Google** (OAuth in an in-app browser sheet):
1. Google Cloud Console → APIs & Services → Credentials → the existing **Web** OAuth
   client → Authorized redirect URI `https://supabase.foodrun.nl/auth/v1/callback`.
   OAuth consent screen: app name Foodrun, privacy URL, publish (not "Testing").
2. `.env`: `GOOGLE_ENABLED=true`, `GOOGLE_CLIENT_ID=<web client id>`,
   `GOOGLE_SECRET=<secret>` (redirect URI is derived from `API_EXTERNAL_URL`).
3. If Google is on, Apple must be on too (App Review guideline 4.8).

Until a provider is live, turn its button off in `FoodrunApp/AppConfig.swift`
(`Features.googleSignIn` / `appleSignIn`) — a button that errors gets the app rejected.

## 3. (Phase 2 only — do not enable until universal-link setup is ready)

Everything below is aspirational until we serve `apple-app-site-association` on
`foodrun.nl`. Leaving it enabled without the server-side file causes tag reads to
silently fall back to Safari.

- Signing & Capabilities → `+ Capability` → **Associated Domains**.
- Add domain: `applinks:foodrun.nl`.
- Then serve at `https://foodrun.nl/.well-known/apple-app-site-association`:
  ```json
  {
    "applinks": {
      "apps": [],
      "details": [
        {
          "appID": "<TEAM_ID>.nl.foodrun.app",
          "paths": [ "/clock/*" ]
        }
      ]
    }
  }
  ```
- Serve with `Content-Type: application/json` (no `.json` extension in the URL).
- Validate at <https://search.developer.apple.com/appsearch-validation-tool/>.

## Verification (real device — CoreNFC does not run in the simulator)

1. Build with the entitlement + Info.plist key in place.
2. Sign in as a worker with an active shift today.
3. Expand the hero → tap the dashed **"Tap here, then hold your phone to the tag on
   Truck Mees to clock in"** strip.
4. Apple's scan sheet appears with the hint copy.
5. Hold the phone near a tag that holds `https://foodrun.nl/clock/mees`.
6. Expected: haptic success, tag-detected flash, then the "You're clocked in" sheet.
7. `select * from shift_clock_events order by event_at desc limit 1` on the VPS shows
   `kind='in'`, `source='mobile'` (the RPC's value — the column only allows mobile/kiosk/manual/pos).
8. Tap the same tag again → sheet says "Shift complete" and the DB row is `kind='out'`.
