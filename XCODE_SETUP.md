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
