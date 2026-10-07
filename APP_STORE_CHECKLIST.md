# App Store checklist — Foodrun iOS

Go through this before every **first submission** and every **major update**.
Built from Apple's App Review Guidelines plus the rejection reasons that come up
again and again from developers (≈45 App Store review videos, 2026-10).

Legend: ✅ done in code · ⬜ to do · 🖐 manual step in Xcode / App Store Connect / server

---

## 1. Things that get apps rejected most

| # | Rule | Foodrun status |
|---|---|---|
| 1 | **Privacy policy link** inside the app **and** in App Store Connect | ✅ Profile → Privacy policy + login footer (`https://foodrun.nl/legal/privacy`) · 🖐 paste the same URL in App Store Connect → App Privacy |
| 2 | **Account deletion inside the app**, easy to find | ✅ Profile → *Delete account* (and on the "waiting for employer" screen) → edge fn `delete-my-account` |
| 3 | **Sign in with Apple** when you offer Google / Facebook login | ✅ both buttons on the login screen · 🖐 enable providers on the VPS (see `XCODE_SETUP.md` → Auth providers). If Google is on, Apple **must** be on too. |
| 4 | **No dead buttons, no "coming soon"** — reviewers tap everything | ✅ removed: shift "⋯" menu, swap request, fake profile rows/stats, "undo clock-in". Tasks tab hidden (`AppConfig.Features.checklists = false`). |
| 5 | **Demo account** for the reviewer + clear review notes | 🖐 see §4 |
| 6 | **Paid digital features use In-App Purchase** | n/a — the worker app sells nothing. Don't mention prices, plans or "upgrade" anywhere in the app. |
| 7 | **Permission pop-ups explain why** (and the button before them says "Continue", not "Grant access") | ✅ NFC string set. The app does **not** ask for location, camera, photos or contacts — don't add a request without a real feature behind it. |
| 8 | **Login in an in-app browser, never bounce to Safari** | ✅ Google uses `ASWebAuthenticationSession` (supabase-swift `signInWithOAuth`) |
| 9 | **Screenshots match the real app** | 🖐 take them from the simulator signed in as the demo worker |
| 10 | **Not a website in a wrapper** | ✅ native SwiftUI |
| 11 | **App Store Connect answers accurate** (privacy, age rating, encryption) | 🖐 see §3 |

## 2. Build settings (Xcode)

- ✅ **iPhone only** — already set: `TARGETED_DEVICE_FAMILY: "1"` in `project.yml`
  (XcodeGen). To double-check in Xcode: Target *Foodrun* → **General → Supported
  Destinations** → only *iPhone* listed. Never re-add iPad, or Apple tests on iPad and
  asks for iPad screenshots.
- 🖐 Minimum iOS 17.0.
- ✅ Entitlements in `project.yml`: Sign In with Apple, NFC tag reading (needs a paid
  developer team for signing).
- ✅ Info.plist (via `project.yml`): `NSNFCReaderUsageDescription`, URL scheme `foodrun`.
- ✅ `ITSAppUsesNonExemptEncryption = NO` in `project.yml` (only standard HTTPS).
- ⬜ **App icon** 1024×1024, no transparency — `Assets.xcassets` has none yet (`project.yml`
  blanks `ASSETCATALOG_COMPILER_APPICON_NAME`). Uploads are refused without one.
- 🖐 Version + build number bumped for every upload.

## 3. App Store Connect

- 🖐 **Privacy policy URL:** `https://foodrun.nl/legal/privacy`
- 🖐 **Support URL:** `https://foodrun.nl/contact` (must load, must show a way to reach you)
- 🖐 **App Privacy ("nutrition label")** — data collected, all *linked to the user*,
  **not** used for tracking:
  - Contact info: name, email address (account)
  - User content: work hours, availability, notes on hours
  - Identifiers: user ID
  - Usage/diagnostics: only if a crash/analytics SDK gets added — none today
  - Precise location: **no** (clock-in sends no GPS)
- 🖐 **Age rating:** 4+ (no objectionable content). Answer every question; don't skip.
- 🖐 **Category:** Business. **Copyright:** "2026 Foodrun".
- 🖐 **Description:** say plainly it's the worker app for teams that use Foodrun; you
  need an employer on Foodrun to see shifts. Put the privacy link at the bottom.
- 🖐 **Screenshots:** 6.9" iPhone set (iPhone 16 Pro Max simulator), signed in as the
  demo worker with shifts showing. No iPad set needed once iPhone-only.

## 4. Review notes + demo account

- 🖐 Run the seed right before submitting so the demo worker has shifts on the review
  dates (they move around "today"):
  `npx tsx tests/rostering/seed-ios-test-accounts.ts` (HQ repo)
- 🖐 Demo login (App Store Connect → App Review Information → Sign-in required):
  `ios.worker@test.foodrun.nl` / password from `D:\vault\services\foodrun-ios-test-accounts.txt`.
  Must be a **normal password login** — no one-time codes, nothing that expires when
  the reviewer logs out and back in.
- 🖐 Notes for the reviewer (paste, adjust):
  > Foodrun is the staff app for food-truck businesses that plan their crew in Foodrun
  > (foodrun.nl). Workers see their shifts, set availability, clock in/out and submit
  > hours; their employer approves hours on the web dashboard.
  > Demo worker: ios.worker@test.foodrun.nl / [password]. It is linked to a test
  > company with shifts today and in the coming days.
  > Clock-in works by tapping an NFC tag on the truck; without a tag, use the
  > "Clock in" button on today's shift.
  > A new account without an employer sees a screen explaining how to get added —
  > that is expected.
  > Account deletion: Me → Delete account.

## 5. Final test pass (TestFlight build, real iPhone)

- ⬜ Fresh install → make account → confirmation email arrives → log in → "waiting for
  employer" screen shows the email + Share works.
- ⬜ Add that email in HQ → Stakeholders → Add employee → HQ shows "has a Foodrun
  account" → save → in the app tap *Check again* → shifts appear.
- ⬜ Forgot password → code email arrives → code accepted → new password → log in.
- ⬜ Sign in with Apple (incl. "Hide my email") and Google both land in the app.
- ⬜ Every button on every screen does something. No sample/demo data anywhere.
- ⬜ Airplane mode: app doesn't crash, shows an error/empty state.
- ⬜ Log out → log back in. Delete account → can't log in any more.
- ⬜ Clock in/out with a real tag; hours submit; approval shows in Inbox.

## 6. Timing

First review of a new app has been taking 1–3 weeks (2026); updates usually 1–2 days.
If a rejection is unclear, reply in App Store Connect or request a call — reviewers
answer faster that way.
