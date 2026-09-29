# Handoff: Foodrun iOS worker app

## Overview

The worker-facing Foodrun app: a food-truck crew member sees their next shift, browses
the schedule week by week, sees who else is rostered, sets their availability, clocks in
by holding the phone to an NFC tag on the truck, works a gated shift checklist, submits
hours, and reads an agent/manager inbox.

Target repo: **`foodrun-IOS`** (native SwiftUI, iOS 17+, Supabase auth, bundle
`nl.foodrun.app`). Today that repo builds two screens — `AuthView` and the `HomeView`
design-system showcase — on top of a complete token + primitive layer (`FoodrunUI/`).
This handoff is the next slice: **8 screens, 2 sheets, a tab bar, and the shift-domain
components the repo README lists as "what's next".**

## About the design files

The files in this bundle are **design references created in HTML** — a running prototype
of the intended look and behaviour, **not production code to copy**. The task is to
recreate them in SwiftUI using the repo's existing `FoodrunUI` tokens and primitives.

Open `Foodrun iOS App.dc.html` in a browser to click through the whole flow. It renders
inside a 402×874pt iPhone frame — that frame is scaffolding, not part of the design.

**Do not port the HTML's layout technique.** Flexbox `gap`, `box-shadow` pairs and
`position:absolute` overlays are prototype mechanics; the SwiftUI equivalents are
`VStack(spacing:)`, the `.frNeu(_:)` modifier, and `.overlay`/`.sheet`.

## Fidelity

**High-fidelity.** Colors, type sizes, radii, spacing and copy are final and should be
matched. Two deliberate translations from HTML to iOS:

1. **Type.** The prototype uses Cabinet Grotesk (display) + Inter (body) because it runs
   in a browser. **The app does not bundle fonts** — `FRFont` maps everything to SF Pro
   by Apple licence. Recreate the *hierarchy* (see Typography below), not the typefaces.
2. **Shadows.** The prototype hardcodes CSS neumorphic pairs. In SwiftUI use
   `.frNeu(.raised)` / `.frNeu(.raisedLg)` / `.frNeu(.pressed)` and `.frCTAShadow()`,
   which already encode the same two-light-source model.

---

## Token reconciliation — do this first

The prototype was designed against the **dashboard** canvas, which is a hair warmer than
the marketing off-white currently in `FRColor`. Three token edits before building:

| Token | Today in `FRColor.swift` | Change to | Why |
|---|---|---|---|
| `background` | `#F4F5F0` | **`#F3F1EF`** | The neumorphic pair only reads as "extruded" on the warmer canvas. This is the design system's documented app canvas. |
| `card` | `#F4F5F0` | **`#FFFFFF`** | Every card in these screens is a white floating surface on the warm canvas. Keep `#F4F5F0` as `backgroundInverseInk` for text on the black hero. |
| `border` | `#E7E7E1` | **`#E0DDD9`** | Design-system warm neutral; `#E7E7E1` reads slightly cool next to `#F3F1EF`. |

Then **add** these to `FRColor`, since the prototype uses them throughout and they have
no token today:

```swift
public let mutedForegroundSoft = Color(hex: 0x8A8A8A)  // secondary label (was 0x6B6B6B)
public let bodySoft            = Color(hex: 0x5C5C5C)  // tertiary body copy
public let neuTrack            = Color(hex: 0xE8E5E0)  // recessed segmented-control track
public let neuPill             = Color(hex: 0xFBFAF7)  // raised active pill
public let neuShadowDark       = Color(hex: 0xD1CECA)  // neumorphic dark side
public let disabledInk         = Color(hex: 0xC9C4BE)

public struct Truck {                 // activity palette — chips, bars, dots ONLY
    public let mees   = Color(hex: 0xFBE27A)  // yellow
    public let mike   = Color(hex: 0x86EFAC)  // green
    public let mama   = Color(hex: 0xF0A8C8)  // pink
    public let extraBlue = Color(hex: 0x7AA6F5)
}
```

Each truck color also has an 18%-alpha tint used as a card fill
(`rgba(251,226,122,.18)` etc.) — express as `.opacity(0.18)`.

**Semantic colors** (already partly in `FRColor.Subject`): approved/positive `#16A34A`,
pending/warning `#F97316` (amber pill `#F59E0B`), unavailable/destructive `#DC2626`,
swap-open ink `#A15C07`, agent-note blue `#3B82F6` on a `rgba(122,166,245,.14)` field,
on-the-clock green `#86EFAC`.

---

## Typography

The prototype's two families map onto SF Pro weights. Add these cases to `FRFont`:

| Prototype role | Prototype spec | SwiftUI |
|---|---|---|
| Screen title ("Hey Sanne", "Your hours") | Cabinet Grotesk 700 · 28px · −0.03em | `.system(size: 28, weight: .bold)` + `.tracking(-0.8)` |
| Hero clock ("19:00") | Cabinet 800 · 52px · −0.04em | `.system(size: 52, weight: .heavy)` + `.tracking(-2)` + `.monospacedDigit()` |
| KPI number | Cabinet 800 · 34–40px · −0.03em | `.system(size: 34, weight: .heavy).monospacedDigit()` |
| Section header ("Still to work") | Cabinet 700 · 18px · −0.02em | `.system(size: 18, weight: .bold)` + `.tracking(-0.4)` |
| Eyebrow ("NEXT SHIFT") | Inter 800 · 10px · **+0.25em** · uppercase | `.system(size: 10, weight: .heavy)` + `.tracking(2.5)` + `.textCase(.uppercase)` |
| Screen kicker ("WEDNESDAY 16 SEP") | Inter 600 · 11px · +0.18em · uppercase | `.system(size: 11, weight: .semibold)` + `.tracking(2)` |
| Field label ("ROLE", "BREAK") | Inter 700 · 10.5px · +0.14em · uppercase | `.system(size: 10.5, weight: .bold)` + `.tracking(1.5)` |
| Row title | Inter 600 · 14px | `.system(size: 14, weight: .semibold)` |
| Row subtitle | Inter 400 · 12px · `#8A8A8A` | `.system(size: 12)` |
| Body | Inter 400 · 13–14px · line-height 1.45 | `.system(size: 13.5)` + `.lineSpacing(3)` |
| Segmented pill label | Inter 600 · 12.5px | `.system(size: 12.5, weight: .semibold)` |
| Tab label | Inter 600 · 9.5px | `.system(size: 9.5, weight: .semibold)` |

**Every time value, hour count, date number and counter is tabular** — always
`.monospacedDigit()`. Numbers are Dutch-formatted with a comma decimal: `6,3 h`, `3,2 °C`.

---

## Shape & elevation

| Role | Radius | Elevation |
|---|---|---|
| Hero / large card | 22pt | `.frNeu(.raisedLg)` (hero is black: `0 10px 24px rgba(0,0,0,.18)` → `.shadow(color:.black.opacity(0.18), radius:12, y:6)`) |
| Standard card | 20pt | `.frNeu(.raisedLg)` for KPI / feature cards |
| List row card | 14–18pt | `.frNeu(.raised)` |
| Inner tile, input | 10–12pt (`FRRadius.row`) | `.frNeu(.pressed)` (recessed) |
| Sheet | 26pt top corners only | `0 -10px 40px rgba(0,0,0,.2)` |
| Tab bar | 26pt | `0 12px 30px rgba(0,0,0,.28)` |
| Buttons, chips, badges, avatars | Capsule | CTA: `.frCTAShadow()` |
| Day cell (carousel) | 12pt | selected-today: `0 4px 10px rgba(0,0,0,.2)` |
| Month cell | 10pt | selected: inset |

Base padding: **20pt horizontal** on every screen. Screen content starts 60pt from the
top (status bar) and ends 108pt from the bottom (floating tab bar clearance).

Row spacing: 8pt between cards, 6pt in dense lists. Section header → first row: 8–10pt.
Section → previous section: 22pt.

---

## Motion

House easing is `cubic-bezier(0.22, 1, 0.36, 1)` → `Animation.timingCurve(0.22, 1, 0.36, 1)`.
`FRAnimation` already holds the presets; add `.weekStep` if missing.

| Interaction | Spec |
|---|---|
| Week step (arrow tap) | Content slides in 16pt from the direction of travel + fades, 320ms house easing |
| Month step | Same, 300ms |
| Day select | Background color cross-fade 200ms |
| Any CTA press | `scaleEffect(0.98)`, 180ms |
| Neumorphic button press | raised → pressed (inset) + `scale(0.94)`, 160ms |
| Checklist progress bar | width 300ms house easing |
| NFC "Tag detected" flash | full-screen overlay, visible 0–55% of 1.5s then fades out |
| NFC result sheet | rises 34pt + fades, 320ms |
| NFC badge | pop-in `scale(0.5 → 1.06 → 1)`, 420ms |
| NFC pulse rings | ring scales 0.6 → 1.5 while fading out, 1.5–2s, infinite, second ring offset 0.4s |
| On-the-clock timer | ticks every second; progress bar width transitions 1s linear |

All animation respects `prefers-reduced-motion` → `@Environment(\.accessibilityReduceMotion)`.

---

## New FoodrunUI components to build

These are the shift-domain components the repo README lists as next. Build them into
`FoodrunUI/Components/` so screens stay thin.

| Component | Used by | Notes |
|---|---|---|
| `FRNextShiftCard` | Shifts | Black hero; collapsed + expanded states; owns the clock panel |
| `FRSegmentedPills` | Shifts, Hours | The design system's signature recessed-track / raised-pill control |
| `FRWeekCarousel` | Shifts (all 3 modes) | Arrows + 7 day cells + optional fold-out month grid |
| `FRMonthGrid` | inside carousel | 5–6 rows × 7, truck dots per day |
| `FRShiftRow` | Shifts | Two densities: full (selected day) and compact (still-to-work) |
| `FRRosterRow` | Roster | Avatar + name + role + time; "You" variant outlined |
| `FRAvailabilityCard` | Availability | Big range readout + dual-handle slider + 2 state buttons + reason |
| `FRStepperRow` | Availability | Label + − / value / + (the + is a black filled circle) |
| `FRTaskRow` | Tasks | Checkbox + title + note + optional input/photo affordance |
| `FRHoursRow` | Hours, Approved | Truck dot + day + place + hours + state |
| `FRNFCSheet` | global | Tag-detected flash + result sheet |
| `FRTabBar` | global | Floating black pill, 5 items, dot badges |

`FRCard`, `FRPrimaryButton`, `FRSecondaryButton`, `FRRow`, `FRStatusBadge`,
`FRSectionHeader`, `FRTextField`, `FRPageHeader`, `Pressable`, `Haptic` already exist —
compose with them; don't fork.

---

## Screens

Screen order below matches the prototype's navigation.

### 1. Sign in (`AuthView`, revise)

**Purpose:** get into the app; join an org via invite.

Centered stack, 20pt padding. Logo image 76pt tall, wordmark "Foodrun" (20pt bold,
−0.02em) below it. Display headline 30pt bold, two lines: *"Your shifts. / One tap away."*
Sub-copy 14pt `#8A8A8A`, max 280pt wide: *"Sign in to see your schedule, log your hours
and finish your shift checklists."*

Two fields (label 11pt uppercase +0.12em `#8A8A8A`; field white, 12pt radius, 1pt
`#E0DDD9` border, 14×16pt padding): Email, Password (with eye toggle).

Primary CTA `FRPrimaryButton` — **"Log in"**, 54pt min height, capsule, `#1A1A1A`,
`.frCTAShadow()`. Secondary `FRSecondaryButton` — **"Make an account"** with
`person.badge.plus` icon, 1pt `#1A1A1A` outline.

Footer, 12pt `#8A8A8A`, centered, two lines: *"Joining a team? Open the invite link your
manager sent — it connects you automatically."*

> **Change from current repo:** the existing screen sends a Supabase magic link. The
> design keeps email+password as primary and reframes the second button as account
> creation. Magic link can stay as the underlying mechanism — see *Invitations* below.

### 2. Shifts — the home screen

Header row: kicker "WEDNESDAY 16 SEP" + title "Hey Sanne"; right, a 40pt circular
avatar chip (`#FBE27A`, initials "SV", `.frNeu(.raised)`) that opens Profile.

**Next-shift hero** — black `#1A1A1A` card, 22pt radius, 20pt padding, white-ish ink
`#F4F5F0`. **Opens collapsed** (see State). A 34×26pt pill at top-center holds a
minus/plus glyph and toggles the two states; tapping anywhere else opens Shift detail.

- Top row: eyebrow "NEXT SHIFT" + truck chip (7pt yellow dot + "Truck Mees" on
  `rgba(255,255,255,.1)` capsule).
- *Collapsed:* one line — `19:00` at 26pt heavy + `– 23:00 · Wed · Kitchen` at 13pt at
  60% opacity. If clocked in, a green dot + running timer sits at the trailing edge.
- *Expanded:* `19:00` at 52pt heavy with `– 23:00` at 17pt; location line with a map-pin
  icon; then the clock panel (if clocked in) and two buttons.
- **Clock panel** (only when clocked in): inset field `rgba(244,245,240,.07)` with a
  `rgba(134,239,172,.28)` border, 18pt radius. Pulsing green dot + "ON THE CLOCK" +
  "since 19:02"; elapsed time `H:MM:SS` at 38pt heavy; "of 4h 00m · 2h 14m left";
  5pt progress bar filling green.
- **Buttons row:** a dashed-outline listening strip (NFC icon with pulsing ring +
  *"Hold your phone to the tag on Truck Mees — clock-in starts by itself"*), and a
  compact outline button showing a lock or checklist icon + `3/7`.

**Mode pills** — `FRSegmentedPills`: **Shifts · Roster · Availability**. Track `#E8E5E0`
with the paired inset shadow, 6pt padding; active pill `#FBFAF7` with the raised pair;
inactive ink `#6A6A6A`.

**Week carousel** — white card, 20pt radius, `.frNeu(.raised)`.
Header: 28pt circular ‹ button, center "Week 38" (12.5pt semibold) over
"14 – 20 Sep · 3 shifts" (10.5pt `#8A8A8A`), a calendar toggle button (fills black when
the month grid is open), 28pt › button. Below: 7 columns — 2-letter day label, a 34pt
rounded-square date cell (today = black fill + white ink + drop shadow; selected =
`#E8E5E0` fill), and a 16×3pt bar underneath colored by the first truck that day (in
Availability mode the bar turns green/red by availability instead).

Month fold-out (when the calendar button is on): divider, month stepper with the month
name at 15pt bold, 7 day-initial headers, then a 7-wide grid of 40pt cells. Each cell:
date number (bold if it has shifts) + up to N 5pt truck dots. Out-of-month days at 32%
opacity. Today black; selected `#E8E5E0` inset.

#### 2a. Shifts mode

- **Selected day section:** header = "Wed 16 Sep" (18pt bold) + "1 shift" trailing.
  Rows are tinted cards (truck tint fill, 4pt truck-colored left border, 18pt radius,
  `.frNeu(.raised)`): time 15pt semibold + "Truck Mees" 12pt; venue line 13pt; trailing
  a status capsule (uppercase 10.5pt bold) over the role, 11.5pt `#8A8A8A`.
  **Empty state:** dashed `#E0DDD9` card, calendar-off icon, "No shift on this day" +
  the current availability sentence + an "Edit" pill that jumps to Availability mode.
- **"Still to work":** header + "11 shifts · 69,3 h". Every unworked shift, ascending,
  as compact rows (9×12pt padding, 14pt radius, 6pt gaps) so ~8 fit on screen:
  32pt date block (day 11pt uppercase over date 17pt bold), a 3×30pt truck bar,
  time + venue, then status word + role right-aligned.

#### 2b. Roster mode

Shows **only the day selected in the carousel**. Header = that day's label +
"3 people on shift". Rows: 36pt circular avatar in the person's color, name (+ a black
"YOU" capsule on your own rows), "Kitchen · Truck Mees", trailing an 8pt truck dot +
time. Your own row is filled with the truck tint and outlined 1.5pt `#1A1A1A` and is
tappable; other crew rows are white and inert. Empty state: dashed card, "Nobody
rostered / No crew is scheduled on Thu 17 Sep."

#### 2c. Availability mode

1. **Two stepper rows** (white card, 20pt radius): *"Shifts you want this week"* and
   *"Standard shifts per week"*. Each: label, a 34pt recessed − button, the value at
   20pt heavy, a 34pt **black filled** + button. Clamp 0…7; − greys to `#C9C4BE` at 0.
2. **Day card** — white, 22pt radius, `.frNeu(.raisedLg)`, for the **selected day only**:
   - Range readout centered: `07:00 – 15:00` at 36pt heavy, date `20-9-2026` below at
     12pt `#8A8A8A`.
   - **Dual-handle slider**, 0–24 in 1h steps: 5pt `#E8E5E0` track, filled segment in
     green (`#16A34A`) when available or red (`#DC2626`) when not, two 22pt white-ringed
     handles. Handles clamp against each other with a 1h minimum window.
     *(SwiftUI: two overlaid `Slider`s won't work — build a `GeometryReader` +
     `DragGesture` control, or use two `Slider`s with a custom track. Handles must be
     ≥44pt hit targets even though they draw at 22pt.)*
   - Scale labels 00:00 / 12:00 / 24:00, 11.5pt `#8A8A8A`.
   - **Two big state buttons**, 48pt min height, 12pt radius, side by side:
     **"Not available"** (active = `#DC2626`, white ink) and **"Available"**
     (active = `#16A34A`, white ink); inactive = `#F3F1EF` recessed with `#6A6A6A` ink.
   - **Reason field**, 12pt radius, 1pt `#E0DDD9` border, placeholder "Reason (optional)".
3. Legend (green/red dots) + an amber "CLOSES THU 23:59" capsule (`#F59E0B`, black ink).
4. Agent note on `rgba(251,226,122,.3)`, sparkles icon: contrasts requested shifts against
   open days, e.g. *"You want 3 shifts this week (standard 4). The agent will schedule
   inside your open windows."*
5. Primary CTA "Save Week 38" → returns to Shifts mode.

### 3. Shift detail

Back chevron (40pt white circle) · "SHIFT DETAIL" kicker · overflow button.

**Summary card** (white, 22pt, `.frNeu(.raisedLg)`): truck dot + "TRUCK MEES" eyebrow +
green "CONFIRMED" capsule; date "Wed 16 September" 15pt bold `#8A8A8A`; `19:00` at 44pt
heavy + `– 23:00`; divider; three columns — ROLE / BREAK / HOURS.

**Location card:** 56pt `#E8E5E0` map tile, venue name + address, "Route" pill.

**Crew on this truck:** three `FRRosterRow`-style rows.

**"What you need to do"** — the gate. Collapsed: clipboard icon, title, summary line, a
chevron. Expanding reveals all 7 tasks as read-only preview rows (18pt rounded checkbox,
title, note), then **one of two footers**:

- **Locked** (recessed `#F3F1EF` note with a lock icon):
  - today's shift, not clocked in → *"The checklist opens once you clock in at 19:00 —
    hold your phone to the tag on the truck."*
  - any other day → *"This shift has not started yet. The checklist opens when you clock
    in on Fri 18 Sep at 12:00."*
- **Unlocked:** black pill **"Open checklist · 3 of 7 done"** + a 6pt progress bar.

**Rule: the checklist is reachable only when the open shift is today AND the user is
clocked in.** This also gates the `3/7` button on the hero — tapping it while locked
opens this card expanded instead of navigating.

Bottom: the dashed NFC listening strip (white, recessed) and a "Request a swap" outline
button.

### 4. Tasks / checklist

Kicker "TRUCK MEES · PARADIGM" + title "Shift checklist".

Black progress card: "COMPLETED" eyebrow, `3` at 38pt heavy `/ 7`, right-aligned
"Submitted to your manager at 23:15", and a 6pt yellow (`#FBE27A`) progress bar.

Section "Before service" + "Tap to complete". Seven rows (white, 18pt radius): a 24pt
rounded checkbox (unchecked = recessed `#F3F1EF`; checked = black fill, white tick),
title 14.5pt (struck through when done), note 12.5pt. Completed rows drop to 55% opacity
and show a timestamp. Incomplete rows that need data reveal an input chip plus a dashed
"Photo" chip (camera icon). Real content: prep station, gas bottles, opening stock count,
fridge temperature (`3,2 °C`), POS test, closing waste (`2,4 kg`), truck-clean photo.

Footer: "Submit checklist" CTA + two-line note about the manager and inventory agent.

### 5. Hours

Header: "PERIOD 9 · SEPTEMBER" kicker + "Your hours"; trailing an **"Approved ›"** chip
(white, `.frNeu(.raised)`, green dot) that opens the full ledger.

**Month stepper** — recessed track (`#E8E5E0`) with two 30pt `#FBFAF7` circular arrows
and the month name centered. **Every number on this screen is scoped to the shown month.**

Two KPI cards side by side, 20pt radius, `.frNeu(.raisedLg)`: **Approved** (`38,5 h`,
"Sep 2026 only") and **Pending** (`6,3 h` in `#F97316`, "1 shift to submit").

**"Waiting for you"** (current month only): white card with truck dot + "Mon 14 Sep ·
Truck Mike" + venue; three recessed tiles Start / End / Break (`17:00` / `23:20` / `30m`);
an agent note on `rgba(122,166,245,.14)` — *"Clock-in said 17:04. The scheduling agent
pre-filled 17:00 — edit if that's wrong."*; CTA "Submit 6,3 hours".

**Month log:** section header = month, trailing "See all →". Rows: truck dot, day label,
venue, hours, and a state word (`Approved` green / `Pending` orange). Empty months show a
dashed "No hours logged in Aug 2026."

### 6. Approved hours

Back chevron + "APPROVED" kicker. Black summary card: "EVERYTHING WORKED" eyebrow,
`126,0` at 40pt heavy + "h · 15 shifts", and "Since you joined Vietnamama in March".
Then one group per month: month name + hairline + month total, and compact rows
(truck dot, day, venue, hours). Newest month first.

### 7. Inbox

Kicker "3 UNREAD" + title "Inbox". Rows (white, 18pt): 36pt avatar — the Foodrun agent
uses a **black rounded-square** (11pt radius, white "F"), people use circular colored
avatars — then sender + relative time, body copy 12.5pt, an unread dot (`#F97316`) at the
trailing edge, and Accept/Decline pills on actionable messages.

### 8. Profile

76pt avatar (`#FBE27A`, `.frNeu(.raisedLg)`), name 22pt bold, "Kitchen · Vietnamama
fleet". Three stat cards (14 shifts / 92% checklists / 3 trucks). "Account" section:
Language, Notifications, Payslips, Contract (24 h/wk), Help & contact — use `FRRow`.
Destructive outline "Log out" + version line "Foodrun 1.0 · nl.foodrun.app".

### Sheets

**Swap sheet** — scrim `rgba(0,0,0,.5)`, sheet `#F3F1EF`, 26pt top radius, grabber.
Title "Request a swap" + context line. Three candidate rows, selected one outlined 1.5pt
black and shadowless. "Send request" CTA + "Ask the whole crew instead" text button.

**NFC clock-in** — see below.

### Tab bar

Floating black pill, inset 12pt left/right, 22pt from the bottom, 8pt padding, 26pt
radius. Five items: Shifts (`calendar`), Tasks (`checklist`), Hours (`clock`),
Inbox (`message`), Me (`person`). Active item = `#F4F5F0` rounded-rect fill (18pt) with
black ink; inactive ink `rgba(244,245,240,.55)`. Inactive items with news show a 7pt
orange dot badge ringed in the bar color. Hidden on Sign in.

---

## The clock-in interaction (most important behaviour)

**Design intent: the worker never presses a button to clock in.** They open the app, hold
the phone near the truck's NFC tag, and the app reads it.

1. Arriving on Shifts or Shift detail **arms a listening window**. The listening strip
   pulses and reads *"…clock-in starts by itself"*. The window re-arms on every arrival,
   not once at launch.
2. A tag read (in the prototype: auto-fires ~2.8s after arrival, or on tap) triggers a
   full-screen **"Tag detected"** flash — dark scrim `rgba(10,10,9,.72)`, a 64pt yellow
   NFC badge with two expanding rings — visible ~0.8s, then fading.
3. A result **sheet** rises: green check badge + *"You're clocked in"*, two tiles
   (Clocked in `19:02` / Truck Mees), an agent note, primary **"Open shift checklist"**,
   and a text button **"Not me — undo clock-in"**.
4. While clocked in, the hero card shows the live panel — running `H:MM:SS`, shift
   progress, remaining — and the collapsed hero shows a green dot + timer.
5. A second tag read clocks out: black flag badge, *"Shift complete"*, a "Worked" tile
   with the total and the `19:02 – 23:14` span, primary **"Review my hours"**, undo
   **"Wasn't done — stay clocked in"**.

**iOS implementation:** Core NFC. Background tag reading (`NFCTagReaderSession` is
foreground-only; true passive reads need **background NDEF reading**, supported on
iPhone XS+ when the app is installed and the tag holds a `ndef://` universal link, or an
App Clip). Practical path for v1: `NFCNDEFReaderSession` started automatically in
`onAppear` of Shifts/Detail so the system scan UI appears without a tap — plus the
tag-detected/result UI above, which replaces Apple's minimal feedback. **Confirm the
target devices support background reads before promising the no-tap flow.**
Haptics: `.success` notification on a valid read (`Haptic` already exists).

---

## State

| State | Type | Notes |
|---|---|---|
| `screen` | enum | signin · shifts · detail · tasks · hours · approved · inbox · profile |
| `tab` | enum | drives the tab bar independently of pushed detail screens |
| `mode` | enum | Shifts · Roster · Availability (the pill row) |
| `heroExpanded` | Bool | **starts `false`** — the app always opens with the collapsed hero |
| `monthOpen` | Bool | the carousel's month fold-out |
| `weekOffset` / `monthOffset` | Int | steps from the current week/month |
| `selectedDate` | Date | the day picked on the carousel; drives Shifts-day, Roster, Availability |
| `openShift` | Shift | which shift the detail screen shows (date + start time gate the checklist) |
| `gateExpanded` | Bool | "What you need to do" |
| `clockedIn` / `clockInAt` | Bool / Date | drives every timer and the checklist unlock |
| `nfcResult` | enum? | nil · in · out — presents the NFC sheet |
| `hoursMonth` | Int | month offset on the Hours screen |
| `availability` | [Date: State] | available / unavailable per day |
| `availabilityWindow` | [Date: (Int, Int)] | from/until hour, default 00–24 |
| `availabilityReason` | [Date: String] | optional |
| `wantShifts` / `standardShifts` | Int | 0…7 |
| `taskDone` | [String: Bool] | 7 checklist items |

**Data fetching:** all of it is Supabase today. The prototype's `SHIFTS`, `OTHERS`,
`WORKED`, `CREW` arrays are the shape each query should return — treat them as fixture
data for previews.

---

## Invitations — recommended model

The prototype's sign-in copy assumes this; it isn't built yet.

The **organisation owns the invite**, not the person. A manager adds a worker in the
dashboard (name, role, truck, contract hours), which mints a **single-use invite link and
a 6-digit code**, delivered by email or WhatsApp. Opening the link deep-links into the app
(`foodrun://invite/<token>` — the URL scheme already exists for the magic-link callback)
with the org pre-attached, so the worker only sets a password or uses Apple/Google
sign-in. The code is the fallback for a dead link or a shared phone. Invites expire in
7 days and are revocable; a worker can belong to several orgs (switcher in Profile).
"Make an account" without an invite creates an orphan account whose only screen asks for
an invite code. Payroll identity stays manager-verified.

Screens still to design: manager invite composer, worker join-from-link, enter-code,
orphan-account state.

---

## Assets

- `assets/foodrun-logo.png` — the official mark. Already in the design-system bundle; add
  to `Assets.xcassets`. Never recolored, never in a circle.
- **Icons:** the prototype uses Lucide. Map to **SF Symbols**:
  `calendar-days`→`calendar`, `list-checks`→`checklist`, `clock`→`clock`,
  `message-square`→`message`, `user`→`person`, `nfc`→`wave.3.right`,
  `chevron-left/right/up/down`→`chevron.*`, `map-pin`→`mappin.and.ellipse`,
  `clipboard-list`→`list.clipboard`, `lock`→`lock.fill`, `sparkles`→`sparkles`,
  `arrow-left-right`→`arrow.left.arrow.right`, `check`→`checkmark`,
  `plus`/`minus`→`plus`/`minus`, `user-plus`→`person.badge.plus`, `eye`→`eye`,
  `calendar-off`→`calendar.badge.minus`, `log-out`→`rectangle.portrait.and.arrow.right`,
  `camera`→`camera`, `globe`→`globe`, `bell`→`bell`, `receipt`→`doc.text`,
  `building-2`→`building.2`, `help-circle`→`questionmark.circle`,
  `more-horizontal`→`ellipsis`, `flag`→`flag.fill`, `map`→`map`.
  Weight: `.medium` (the prototype strokes at 1.8 on a 24 grid).
- No photography. The location card uses a neutral icon tile, not a map image.

## Copy & language

All copy in this bundle is **English** and final — use it verbatim. The app ships EN + NL;
Dutch strings run ~20% longer, so **every label must wrap rather than truncate**, and the
pill row, stepper rows and state buttons must survive "Beschikbaarheid" /
"Niet beschikbaar". Put all strings in a catalog from the start.

## Accessibility

- Minimum tap target 44pt. The 34pt stepper buttons, 28pt carousel arrows, 34pt day cells
  and 22pt slider handles all need padded hit areas.
- Text contrast: body and label ink is full-opacity on its ground everywhere. On the black
  hero, secondary text is `rgba(244,245,240,.6)` at ≥13pt only.
- Support Dynamic Type at least to XL; the fixed-height rows must grow.
- Respect reduce-motion (kill the pulse rings and slide transitions; keep opacity fades).

## Files in this bundle

| File | What it is |
|---|---|
| `Foodrun iOS App.dc.html` | The full prototype — all 8 screens, both sheets, the tab bar, live clock-in. Open in a browser. |
| `Foodrun iOS - Current Build.dc.html` | A faithful recreation of what the repo builds **today** (AuthView + HomeView showcase), for before/after comparison. |
| `support.js`, `ios-frame.jsx` | Prototype runtime + the iPhone frame. Scaffolding only — nothing to port. |
| `assets/foodrun-logo.png` | The logo used on Sign in. |

## Suggested build order

1. Token reconciliation + the new `FRFont` cases (half a day, unblocks everything).
2. `FRTabBar` + navigation shell + the 8 empty screens.
3. `FRSegmentedPills`, `FRWeekCarousel`, `FRMonthGrid` — the spine of the Shifts screen.
4. Shifts mode + `FRShiftRow`, then Shift detail + the gated checklist, then Tasks.
5. `FRNextShiftCard` and the clock-in flow (`FRNFCSheet` + Core NFC). Biggest unknown —
   spike the background-read capability early.
6. Hours + Approved.
7. Roster, Availability (`FRAvailabilityCard`'s dual-handle slider is the fiddly one).
8. Inbox, Profile, swap sheet.
9. Invitations, once the four missing screens are designed.
