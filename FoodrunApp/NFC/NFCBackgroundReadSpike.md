# NFC background-read spike

**Goal:** worker doesn't tap a button to clock in. They open the app, hold the phone
near the truck's NFC tag, and iOS reads it.

**Research finished 2026-09-24.** Full implementation plan and Apple docs citations
in `C:\Users\litli\.claude\plans\now-i-want-you-wild-reef.md`. Phase 1 (foreground)
has shipped; this file remains as the Phase 2 spike record.

**Phase 1 status (SHIPPED):** foreground `NFCNDEFReaderSession` wired to Supabase
via `ClockStore.handleTagRead`. Trigger is a tap on the branded NFC listening
strip; Apple's scan sheet appears with our hint copy; on success we present
`TagDetectedFlash` + `NFCResultSheet`. Same tag toggles clock-in and clock-out —
`ClockStore` decides direction from the latest `shift_clock_events` row.

## Options

### 1. `NFCNDEFReaderSession` (implemented)
- **How:** `.begin()` on the session in `onAppear` of Shifts + Shift detail. Apple's
  system UI appears; user holds phone near tag.
- **Pros:** works on all NFC iPhones (iPhone 7+). No universal link plumbing.
- **Cons:** shows Apple's scan sheet, which competes with our branded flash. Not truly
  "no-tap" — the sheet is a modal.

### 2. Background NDEF reading (aspirational)
- **How:** the tag holds a URL like `https://foodrun.nl/clock/<truck_id>`; iOS
  auto-launches the app when it reads that URL (Notification Center → banner → tap).
  App parses the URL in `.onOpenURL` and fires the clock-in flow.
- **Pros:** truly passive — no scan sheet.
- **Cons:**
  - Requires **iPhone XS or later**.
  - Requires **universal links** configured on `foodrun.nl` with
    `apple-app-site-association` served at `/.well-known/apple-app-site-association`.
  - The user still taps the notification banner unless the app is already frontmost.
    Only fully passive reads happen on the lock screen when the user has never
    opened the app that session.
  - Tag write flow: someone (probably the operator) has to write each truck tag
    with the right URL via a companion iOS app or a third-party writer.

### 3. App Clip (alternative to #2)
- **How:** tag holds a URL bound to an App Clip. iOS presents a small banner even for
  users without the app installed.
- **Pros:** onboarding is instant for new workers.
- **Cons:** extra target, extra provisioning, App Clip has size + capability limits.
  Probably overkill for a workforce app where everyone has the full app installed.

## Recommendation for v2

Ship #2 alongside #1 as fallback. Concrete tasks when landing:

- [ ] Register `foodrun.nl` for universal links (`apple-app-site-association` on the
      VPS at `https://foodrun.nl/.well-known/…`).
- [ ] Xcode target → Signing & Capabilities → Associated Domains: `applinks:foodrun.nl`.
- [ ] Info.plist: `NSNFCReaderUsageDescription` (already required for #1),
      `com.apple.developer.nfc.readersession.formats`.
- [ ] Handle inbound URL in `FoodrunApp.swift .onOpenURL`. Match
      `/clock/<truck_id>?activity=<uuid>` → dispatch to `ClockStore.recordClockIn`.
- [ ] Small "tag-write" mode inside a manager-only settings panel (or a dedicated
      one-off script) to burn URLs onto physical tags.
- [ ] Test devices: iPhone XR/XS, iPhone 13, iPhone 15. Confirm both foreground read
      **and** background auto-launch behaviour on each.

## Open question

The bundle copy — "Hold your phone to the tag on Truck Mees — clock-in starts by
itself" — commits us to the no-tap flow. Until #2 ships, the copy is aspirational;
adjust to something honest ("Hold your phone to the tag to clock in") if #1 is what
users experience for months.
