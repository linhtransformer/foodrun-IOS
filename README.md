# Foodrun iOS (native SwiftUI)

Native worker app for Foodrun. SwiftUI, iOS 17+, Supabase auth via magic link.
Bundle ID `nl.foodrun.app` (matches the existing Capacitor config so provisioning carries over).

This folder holds only Swift source. The Xcode project is created **on the Mac** — see setup below.

## First-time setup (Mac)

You need Xcode 15.4 or newer.

1. **Create the Xcode project.**
   `File → New → Project… → iOS → App`
   - Product Name: `Foodrun`
   - Team: your Apple Developer team
   - Organization Identifier: `nl.foodrun`
   - Bundle Identifier auto-fills to `nl.foodrun.app`. ✅
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
   - Include Tests: unchecked (for now)
   - Save the `.xcodeproj` **inside this `foodrun-ios/` folder** so it sits next to the source.

2. **Delete the two stub files Xcode generated** — `FoodrunApp.swift` and `ContentView.swift`. We ship our own.

3. **Add the source folders to the project.**
   In Finder, drag these folders from `foodrun-ios/` into the Xcode file navigator (root of the target):
   - `FoodrunApp/`
   - `FoodrunUI/`
   When prompted: **Copy items if needed = OFF**, **Create groups**, add to target `Foodrun`.

4. **Add the Supabase Swift SDK.**
   `File → Add Package Dependencies…`
   URL: `https://github.com/supabase/supabase-swift`
   Dependency Rule: **Up to Next Major Version** from `2.20.0`.
   Add the `Supabase` product to the `Foodrun` target.

5. **Configure Supabase URL + anon key.**
   Edit `FoodrunApp/Supabase/SupabaseManager.swift`. The URL points to the self-hosted VPS (`https://supabase.foodrun.nl`); paste the anon key.

6. **Set minimum deployment target to iOS 17.0.**
   Project → Foodrun (target) → General → Minimum Deployments.

7. **Deep link URL scheme (for magic link callback).**
   Project → Info → URL Types → add:
   - Identifier: `nl.foodrun.app`
   - URL Schemes: `foodrun`
   Magic-link callback URL configured in Supabase Auth: `foodrun://auth-callback`.

8. **Run.** ⌘R on the iOS Simulator (iPhone 15 Pro or similar).

## What builds today

- **AuthViewRedesign** (email + password, "Make an account", invite-link footer — bundle §1)
- **AppShell** — floating tab bar + 5 tabs (Shifts / Tasks / Hours / Inbox / Me)
- **8 screens**: Shifts (with 3 modes), Shift detail, Tasks, Hours, Approved hours, Inbox, Profile
- **2 sheets**: Swap sheet, NFC result sheet
- **12 `FoodrunUI/Components/`**: FRTabBar, FRSegmentedPills, FRWeekCarousel, FRMonthGrid,
  FRNextShiftCard (collapsed + expanded), FRShiftRow, FRRosterRow, FRAvailabilityCard
  (with a custom dual-handle slider), FRStepperRow, FRTaskRow, FRHoursRow, FRNFCSheet
- **Tokens** reconciled to bundle §Token reconciliation — new warm canvas, Truck palette,
  semantic worker-app colors, 11 new `FRFont` roles, new `FRAnimation` easings.
- **Localization** EN + NL from day 1 (`Localization/en.lproj/`, `nl.lproj/`).
- **NFC clock-in** foreground path via Core NFC; passive-read spike documented.
- **Supabase schema mirror** — `FoodrunApp/Supabase/SharedSchema.swift` + `SchemaContract.md`
  binding iOS stores to the same tables the web PWA uses.

## HTML mirror + Playwright (Windows-friendly)

The design bundle ships as an HTML prototype. We keep a verbatim copy at `mirror/index.html`
and run **Playwright specs** against it as a visual-regression fence.

```
cd mirror
npm install
npm run install-browsers
npm test           # runs 8 spec files against the mirror
npm run test:ui    # interactive mode
```

Playwright verifies the design contract on the mirror; SwiftUI is verified separately
on the Mac via `#Preview` blocks. See `mirror/README.md` for the split.

## What's next (per spec)

- **Backend audit (Slice 0)**: verify `employee_shift_clock` and `shift_checklist`
  tables exist on the VPS; if not, migrations land here (see
  `FoodrunApp/Supabase/SchemaContract.md`).
- **Widget + Live Activity extension targets** (planned per bundle roadmap).
- **Dark mode wiring** — structural readiness is in place (every `FRColor` value has a
  `dark:` companion comment); v2 is a token-file edit only.
- **Invitations** — 4 screens still to design; stub folder at
  `FoodrunApp/Invitations/README.md`.

The full spec + build order is at
`docs/superpowers/specs/2026-09-21-foodrun-ios-apply-design-system.md`.

## Windows ↔ Mac workflow

Per the earlier brainstorm: **VS Code Remote-SSH into the Mac** is the chosen setup. Files here live on Windows; on the Mac side, keep them in sync via git or SSH-mounted folder. Xcode always opens on the Mac.

Recommended: create a private git repo `foodrun-ios` and push from Windows, pull on Mac before opening Xcode. Keeps history clean and avoids sync-conflict edge cases.
