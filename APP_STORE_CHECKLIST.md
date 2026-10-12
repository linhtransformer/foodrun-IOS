# App Store checklist — Foodrun iOS

Go through this before every **first submission** and every **major update**.
Built from Apple's App Review Guidelines plus the rejection reasons that come up
again and again from developers (≈45 App Store review videos, 2026-10).

Legend: ✅ done in code · ⬜ to do · 🖐 manual step — each one says **where** to do it.

Last checked against the project: 2026-10-12.

---

## 0. Once, before the first upload

| # | Step | Where |
|---|---|---|
| 1 | 🖐 **Paid Apple Developer Program** (needed for Sign in with Apple, NFC, TestFlight) | developer.apple.com → **Account**. "Membership details" shows whether it is active and your **Team ID**. |
| 2 | 🖐 **Xcode knows your team** | Xcode → **Settings → Accounts → +** (Apple ID). Then target *Foodrun* → **Signing & Capabilities → Team**. Automatic signing registers the bundle ID `nl.foodrun.app` with its capabilities. Tip: add `DEVELOPMENT_TEAM: <Team ID>` under `settings.base` in `project.yml`, or the Team field is empty again after every `xcodegen generate`. |
| 3 | 🖐 **Create the app record** | appstoreconnect.apple.com → **Apps → + → New App**. Platform iOS · Name "Foodrun" (must be free on the store; otherwise e.g. "Foodrun Crew") · Primary language Dutch or English (the app has both) · Bundle ID `nl.foodrun.app` · SKU `foodrun-ios` · Full Access. |

## 1. Things that get apps rejected most

| # | Rule | Foodrun status |
|---|---|---|
| 1 | **Privacy policy link** inside the app **and** in App Store Connect | ✅ Profile → Privacy policy + login footer (`https://foodrun.nl/legal/privacy`) · 🖐 same URL in App Store Connect (§3) |
| 2 | **Account deletion inside the app**, easy to find | ✅ Profile → *Delete account* (and on the "waiting for employer" screen) → edge fn `delete-my-account` |
| 3 | **Sign in with Apple** when you offer Google / Facebook login | ✅ both buttons on the login screen · ✅ Apple + Google switched on on the VPS (auth settings checked 2026-10-12). If Google is on, Apple **must** stay on too. |
| 4 | **No dead buttons, no "coming soon"** — reviewers tap everything | ✅ removed: shift "⋯" menu, swap request, fake profile rows/stats, "undo clock-in". The **Tasks tab is live** with the employer's real tasks, checklists and week goals (`AppConfig.Features.crewTasks = true`); the old sample checklist stays off (`checklists = false`). The demo account must have tasks in it — the seed does that (§4). |
| 5 | **Demo account** for the reviewer + clear review notes | 🖐 see §4 |
| 6 | **Paid digital features use In-App Purchase** | n/a — the worker app sells nothing. Don't mention prices, plans or "upgrade" anywhere in the app. |
| 7 | **Permission pop-ups explain why** | ✅ Four prompts, each with a real feature behind it: **NFC** (clock-in tag), **camera** (a task asks for a photo), **location while using** (pinning a spot on the event — asked when the pin sheet opens, not at launch), **notifications** (shift changes). Reasons are in `project.yml`. Picking a photo from the library uses `PhotosPicker`, which needs no permission. Don't add a request without a feature. |
| 8 | **Login in an in-app browser, never bounce to Safari** | ✅ Google uses `ASWebAuthenticationSession` (supabase-swift `signInWithOAuth`) |
| 9 | **Screenshots match the real app** | 🖐 see §3 |
| 10 | **Not a website in a wrapper** | ✅ native SwiftUI |
| 11 | **App Store Connect answers accurate** (privacy, age rating, encryption) | 🖐 see §3 |

## 2. Build settings + upload (Mac)

- ✅ **iPhone only** — `TARGETED_DEVICE_FAMILY: "1"` in `project.yml` (XcodeGen). To
  double-check in Xcode: target *Foodrun* → **General → Supported Destinations** → only
  *iPhone*. Never re-add iPad, or Apple tests on iPad and asks for iPad screenshots.
- ✅ Minimum iOS 17.0 (`deploymentTarget` in `project.yml`).
- ✅ Entitlements in `project.yml`: Sign In with Apple, NFC tag reading.
- ✅ Info.plist (via `project.yml`): NFC, camera and location reasons, URL scheme
  `foodrun`, background fetch for shift changes.
- ✅ `ITSAppUsesNonExemptEncryption = NO` in `project.yml` (only standard HTTPS) — no
  export-compliance question on upload.
- ✅ **App icon** — `Assets.xcassets/AppIcon.appiconset/AppIcon.png`: the Foodrun logo as
  a full black square, 1024×1024, no transparency (Apple rounds the corners itself).
  Made from the HQ repo's `Brand guidelines test/Foodrun Logo.png`. To change it, replace
  that one PNG with another 1024×1024 PNG without transparency.
- 🖐 **Version + build number** for every upload.
  **Where:** `project.yml` → `MARKETING_VERSION` (1.0, 1.1 … what users see) and
  `CURRENT_PROJECT_VERSION` (1, 2, 3 … must go up with **every** upload), then
  `xcodegen generate`. Not in Xcode's General tab — `xcodegen` overwrites that.
- 🖐 **Upload the build.**
  **Where:** Xcode → device menu at the top → **Any iOS Device (arm64)** →
  **Product → Archive** → the Organizer window opens → **Distribute App → App Store
  Connect → Distribute**. After 10–30 minutes of processing (Apple emails you) the build
  is in App Store Connect → **TestFlight**.

## 3. App Store Connect

Everything here is at appstoreconnect.apple.com → **Apps → Foodrun**. The left sidebar
has the pages that are filled in once (*App Information*, *Pricing and Availability*,
*App Privacy*) and the **version page** (*iOS App → 1.0 Prepare for Submission*), which
is filled in per release.

| What | Where | Fill in |
|---|---|---|
| 🖐 Category | App Information | Business |
| 🖐 Age rating | App Information → Age Rating → Edit | Answer every question (all "none") → 4+ |
| 🖐 Price + countries | Pricing and Availability | Free · the countries you want (at least the Netherlands) |
| 🖐 Privacy policy URL | App Privacy → Privacy Policy | `https://foodrun.nl/legal/privacy` |
| 🖐 Data collection ("nutrition label") | App Privacy → Get Started | see the list below |
| 🖐 Screenshots | version page → Previews and Screenshots → iPhone 6.9" | 3–10, see below |
| 🖐 Description | version page | Say plainly it is the worker app for teams that use Foodrun; you need an employer on Foodrun to see shifts. Privacy link at the bottom. |
| 🖐 Support URL | version page | `https://foodrun.nl/contact` (must load and show a way to reach you) |
| 🖐 Copyright | version page | `2026 Foodrun` |
| 🖐 Build | version page → Build → + | the build you tested in TestFlight |
| 🖐 Demo login + notes | version page → App Review Information | see §4 |

**App Privacy answers** — "Yes, we collect data". For every type: purpose *App
Functionality*, *linked to the user*, **not** used for tracking.

- **Contact Info** → Name, Email Address (the account)
- **Location** → Precise Location (only when a crew member pins a spot on the event;
  clock-in sends no GPS)
- **User Content** → Photos or Videos (photo tasks) · Other User Content (hours,
  availability, notes, task answers)
- **Identifiers** → User ID
- Usage Data / Diagnostics → none today. Add them if a crash or analytics SDK goes in.

**Screenshots** — on the Mac: run the app in the **iPhone 16 Pro Max** simulator (6.9",
or a newer Pro Max), log in as the demo worker, then in the Simulator menu **File → Save
Screen** (⌘S); the picture lands on the Desktop in the right size. Good set: shifts,
a shift's Draaiboek, Tasks with a checklist, clock-in, hours. No iPad set needed.

## 4. Review notes + demo account

- 🖐 **Fill the demo account** right before you press Submit, so the worker has shifts,
  tasks and briefings on the review dates (they move around "today").
  **Where:** Windows, terminal in the HQ repo:
  `npx tsx tests/rostering/seed-ios-test-accounts.ts`
  Don't run it again while the review is going — it signs the test accounts out.
- 🖐 **Demo login.** **Where:** version page → **App Review Information** → tick
  *Sign-in required* → user name `ios.worker@test.foodrun.nl`, password from
  `D:\vault\services\foodrun-ios-test-accounts.txt`. Must be a **normal password
  login** — no one-time codes, nothing that expires when the reviewer logs out and
  back in. Fill in *Contact Information* too (your name, phone, email).
- 🖐 **Notes** — same box, field *Notes* (paste, adjust):
  > Foodrun is the staff app for food-truck and restaurant businesses that plan their
  > crew in Foodrun (foodrun.nl). Workers see their shifts and the briefing for each
  > shift, do the tasks their employer sets (checklists, photos, week goals), set
  > availability, clock in/out and submit hours; their employer approves hours on the
  > web dashboard.
  > Demo worker: ios.worker@test.foodrun.nl / [password]. It is linked to a test
  > company with shifts today and in the coming days.
  > Clock-in works by tapping an NFC tag on the truck; without a tag, use the
  > "Clock in" button on today's shift.
  > The camera is only asked for when a task needs a photo, and location only when
  > you pin a spot on the event map. Both can be refused; the rest keeps working.
  > A new account without an employer sees a screen explaining how to get added —
  > that is expected.
  > Account deletion: Me → Delete account.

## 5. Final test pass (TestFlight build, real iPhone)

🖐 **Get the build on your phone.** **Where:** App Store Connect → **TestFlight →
Internal Testing → +** → make a group, add yourself, pick the build. On the iPhone:
install the **TestFlight** app from the App Store, open the invitation email, Install.

- ⬜ The home-screen icon is the Foodrun logo.
- ⬜ Fresh install → make account → confirmation email arrives → log in → "waiting for
  employer" screen shows the email + Share works.
- ⬜ Add that email in HQ → Stakeholders → Add employee → HQ shows "has a Foodrun
  account" → save → in the app tap *Check again* → shifts appear.
- ⬜ Forgot password → code email arrives → code accepted → new password → log in.
- ⬜ Sign in with Apple (incl. "Hide my email") and Google both land in the app.
- ⬜ Open a shift: the Draaiboek shows the script headings with their icons and the
  standing briefing cards.
- ⬜ Tasks: tick a checklist row, take a photo for a photo task (camera question shows
  its reason), answer a week goal.
- ⬜ Pin a spot on the event (location question shows its reason). Choose "Don't
  allow" once: no crash, a note with a Settings button shows, and the pin can still be
  placed by moving the map.
- ⬜ Every button on every screen does something. No sample/demo data anywhere.
- ⬜ Airplane mode: app doesn't crash, shows an error/empty state.
- ⬜ Log out → log back in. Delete account → can't log in any more.
- ⬜ Clock in/out with a real tag; hours submit; approval shows in Inbox.

## 6. Submit + timing

🖐 **Where:** the version page → **Add for Review** (top right) → **Submit for Review**.
The status goes *Waiting for Review* → *In Review* → *Ready for Distribution*.

First review of a new app has been taking 1–3 weeks (2026); updates usually 1–2 days.
If a rejection is unclear, reply in App Store Connect or request a call — reviewers
answer faster that way.
