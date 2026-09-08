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
   Dependency Rule: **Up to Next Major Version** from `2.0.0`.
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

- Auth screen (email magic link, Sign in with Apple stubbed for v2)
- Post-auth Home showcase — a scrollable page rendering every design-system primitive so you can eyeball the visual language on-device

## What's next (per spec)

- Shift domain components (`FRShiftCard`, `FRShiftWeekStrip`, etc.) — see `docs/superpowers/specs/2026-09-08-foodrun-ios-design-system-design.md`
- Widget + Live Activity extension targets
- Dark mode wiring

## Windows ↔ Mac workflow

Per the earlier brainstorm: **VS Code Remote-SSH into the Mac** is the chosen setup. Files here live on Windows; on the Mac side, keep them in sync via git or SSH-mounted folder. Xcode always opens on the Mac.

Recommended: create a private git repo `foodrun-ios` and push from Windows, pull on Mac before opening Xcode. Keeps history clean and avoids sync-conflict edge cases.
