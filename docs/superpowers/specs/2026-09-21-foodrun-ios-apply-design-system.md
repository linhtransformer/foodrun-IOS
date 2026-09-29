# Foodrun iOS — apply design-system handoff

**Status:** in progress · **Date:** 2026-09-21
**Source of truth:** `iOS UI design system.zip` (bundled at repo root as `.tmp-ios-zip/design_handoff_foodrun_worker_app/`)
— specifically its `README.md` (spec) and `Foodrun iOS App.dc.html` (working prototype).

This doc is intentionally thin: it captures decisions and directs the reader to the
handoff for details. The bundle is 530 lines of spec; do not re-say it here.

## Scope

Take `D:\foodrun-IOS` from AuthView + HomeView showcase to the full worker app per the
handoff: 8 screens, 2 sheets, floating tab bar, 12 new `FoodrunUI/Components/*`,
token/font reconciliation, live NFC clock-in, invitations (blocked on design),
dark-mode structural readiness, Live Activities/Widget targets deferred but planned.

Nothing is deferred at the user's request. Where designs don't exist yet (invitations,
Live Activities visuals), stubs land with `README.md` explaining what's needed.

## Verification model

The user runs Windows; Xcode runs on a Mac. The verification loop is:

1. **HTML mirror at `mirror/index.html`** — literally the bundle's `Foodrun iOS App.dc.html`
   copied verbatim. This is what the SwiftUI aims to match.
2. **Playwright specs at `mirror/tests/*.spec.ts`** — assert every interaction the
   design specifies (tab nav, mode pills, week carousel, hero expand/collapse, NFC flash
   timing, sheet presentation, tap targets, reduce-motion). Runs on Windows.
3. **SwiftUI `#Preview` blocks** — every component and screen ships one, wired to
   fixture data on the corresponding store's `.preview` static.
4. **Mac-side compile check** — user pulls, opens Xcode, hits ⌘R.

Playwright verifies the *design spec is met by the mirror*. The mirror is verbatim from
the design bundle, so this is really a regression fence — if a future change to the
mirror breaks a spec, the design has drifted. SwiftUI matches the mirror by eye and by
following the token/type/component contract.

## Backend — same Supabase, same tables

The iOS app is a native worker portal replacing the web PWA at `/me/*` in the HQ repo.
It talks to the same self-hosted Supabase (`https://supabase.foodrun.nl`), the same
tables, the same RPCs:

| iOS store | Web hook it mirrors | Tables / RPC |
|---|---|---|
| `ScheduleStore` | `useMyAvailability.ts:87-250` | `employees`, `activities`, `daily_times`, `daily_employee_times`; RPC `lookup_my_operators()` |
| `ClockStore` | `useShiftClock.ts` | `employee_shift_clock` (verify in Slice 0; if absent, migration lands there) |
| `AvailabilityStore` | `useMyAvailability.ts` (write side) | `daily_employee_times` |
| `HoursStore` | `useEmployeeHours.ts` | `employee_hours` |
| `TasksStore` | new — no web equivalent | `shift_checklist` (new; migration in Slice 8) |
| `InboxStore` | `useWorkerInbox.ts` | `worker_notifications` |

Auth is identical: magic link → `employee-identity-link` edge fn → multi-operator
`employees` rows share one `auth.users.id`. `SchemaContract.md` is the drift audit
document — every table the iOS app hits gets a row with the web hook + iOS store name
and last-verified date.

## File organization

```
FoodrunApp/
  Auth/  Home/  Supabase/     (existing)
  Screens/    Sheets/    Navigation/    State/    NFC/    Invitations/    (new)
FoodrunUI/
  Tokens/  Primitives/  Modifiers/    (existing — edited in place)
  Components/                          (new — 12 shift-domain components)
Localization/en.lproj/ nl.lproj/       (new — bundle §Copy mandates catalog from day 1)
mirror/                                (new — HTML mirror + Playwright)
  index.html, support.js, ios-frame.jsx, assets/
  package.json, playwright.config.ts
  tests/*.spec.ts
docs/superpowers/specs/  plans/        (this doc + the plan)
```

## Token / type decisions

Per bundle §Token reconciliation:

**FRColor edits** — `background` #F4F5F0 → **#F3F1EF**; `card` #F4F5F0 → **#FFFFFF**;
`border` #E7E7E1 → **#E0DDD9**. Retire the old `card` value into
`backgroundInverseInk` (for text on the black hero).

**FRColor additions** — `mutedForegroundSoft`, `bodySoft`, `neuTrack`, `neuPill`,
`neuShadowDark`, `disabledInk`, plus `Truck` struct with `mees`/`mike`/`mama`/`extraBlue`.
Each truck color also exposed as an `.opacity(0.18)` tint helper.

**FRColor semantic** — reuse existing `Subject.revenue` for `positive`
(`#16A34A`), add `warning` (`#F97316`), `warningPill` (`#F59E0B`),
`destructive` (`#DC2626`), `swapOpenInk` (`#A15C07`), `agentNoteBlue` (`#3B82F6`) with
a `.opacity(0.14)` field, `onTheClockGreen` (`#86EFAC`).

**FRFont additions** — 11 new cases: `screenTitle`, `heroClock`, `kpiNumber`,
`sectionHeader`, `eyebrow`, `screenKicker`, `fieldLabel`, `rowTitle`, `rowSubtitle`,
`segmentedLabel`, `tabLabel`. All SF Pro via `.system(size:weight:)` with tracking as
specified in §Typography. Every numeric case uses `.monospacedDigit()`.

**FRAnimation additions** — `weekStep` (320ms house easing), `monthStep` (300ms),
`dayFade` (200ms), `nfcPulse` (1.5s infinite), `nfcResultRise` (320ms).

**FRRadius additions** — `heroHero` (22pt), `heroDay` (12pt), `heroTile` (10pt).

**FRSpacing additions** — `screenH` (20pt), `rowGap` (8pt), `denseGap` (6pt),
`sectionGap` (22pt), `sectionHeadGap` (10pt).

## Interaction rules that shape the code

- **Hero opens collapsed always** (`heroExpanded` starts `false`).
- **Checklist gate**: reachable only when the open shift is today AND `clockedIn`.
  Every path to Tasks passes through this gate — no direct route.
- **Listening window** re-arms on every arrival at Shifts or Detail, not once at launch.
- **Dual-handle slider** in Availability: two overlaid `Slider`s won't work — one
  `GeometryReader` + two `DragGesture`s + 44pt hit targets even though handles draw at 22pt.
- **Numbers are Dutch-formatted** (`6,3 h`) via `NumberFormatter` with `nl_NL` locale.
- **Localization from day 1** — `Localizable.strings` `en` + `nl`; every label wraps
  rather than truncates.
- **Reduce-motion** kills the pulse rings and slide transitions; opacity fades stay.

## Build order (drives the plan)

Numbered per bundle §Suggested build order + our verification model:

0. **Backend audit** — verify `employee_shift_clock` exists; if not, note migration for
   Slice 8. Write `SchemaContract.md` seed.
1. **Foundations** — token + font + animation reconciliation.
2. **Mirror + Playwright scaffold** — mirror/ folder populated verbatim from bundle;
   `smoke.spec.ts` proves the harness works.
3. **TabBar + navigation shell + 8 empty screens** — clickable skeleton on Mac.
4. **Segmented pills + week carousel + month grid** — the Shifts spine.
5. **Shifts mode + ShiftRow + selected-day + still-to-work** + empty state.
6. **Shift detail + gated checklist preview.**
7. **Tasks screen** (full checklist behaviour).
8. **NextShiftCard + NFC clock-in** — foreground `NFCNDEFReaderSession` first;
   `NFCBackgroundReadSpike.md` records what needs to change for the passive-read path.
9. **Hours + Approved.**
10. **Roster mode + Availability mode** — dual-handle slider lives here.
11. **Inbox + Profile + Swap sheet.**
12. **Invitations stub** (README explains 4 screens still to design).
13. **Localization sweep** — every hardcoded string moved to catalog; NL translations.
14. **Dark mode wiring** — token-file edit only, per structural readiness.
15. **Live Activities + Widget** — separate extension targets.

Each slice ends with: (a) SwiftUI files + `#Preview`; (b) HTML mirror sanity check;
(c) Playwright spec added or extended; (d) short commit.

## Out of scope

- Marketing site changes (HQ repo).
- Manager/dashboard changes (HQ repo).
- Photography — location card uses a neutral icon tile.
- Legacy Vietnamama brand references.

## Open questions (tracked, don't block)

- Background NFC reads on iPhone XS+ require an installed app + `ndef://` universal
  link or an App Clip. Confirmed device support before the Slice 8 UI copy commits to
  "no-tap". Spike doc lands with Slice 8.
- Invitations: 4 screens undesigned — manager invite composer, worker join-from-link,
  enter-code, orphan-account. Slice 12 stubs the folder; UI ships when design lands.
- `employee_shift_clock` schema: does it already exist on the HQ Supabase? If not,
  migration in Slice 8.
