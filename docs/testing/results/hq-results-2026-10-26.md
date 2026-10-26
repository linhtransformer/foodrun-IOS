# HQ Stakeholders audit — 2026-10-26

Prompt: `docs/testing/hq-stakeholders-audit.md`. Data: `handoff/hq-done.md`. HQ changes for the app: `handoff/hq-did.md`.
Tested on **foodrun.nl** (live build `f3d0b21`) signed in as `ios.operator@test.foodrun.nl` (owner of Foodrun Testbedrijf),
fixes checked on a local build of the same commit plus the fix. Inventory from the code and from clicking through
every tab. Severity: **blocker** (can't plan, approve or pay) / **major** (wrong data, dead end, notification missing or
doubled, app and HQ disagree) / **minor** (looks or wording).

Q1–Q10 = way in · action and feedback · next step · way back · it stuck · other direction · states · roles · dates ·
notifications. "→ D#" = a line in `hq-did.md` for the app to check; "ios" = waits for `ios-did.md`.

## Fixed in HQ today (HQ repo, one commit each)

| Commit | Fix |
|---|---|
| `8417214` | Rooster: someone still waiting under Aanmeldingen could be picked for a shift they would never see |
| `700b7eb` | Medewerkers / Rooster: a failed load showed "No employees yet" / "Geen activiteiten" + "Alle diensten zijn bezet"; now a red error |
| `afc2b69` | Medewerkers: grid-size and role menus that did nothing removed; Teams search now filters |
| `d7d7c5a` | Aanmeldingen: "Alles goedkeuren" also approved rows it doesn't show (no app account, own rows elsewhere) |
| `e814b97` | Uren: a night shift's clock-out after midnight showed "22:01 – …" + "Ingeklokt maar nooit uitgeklokt" (C6) |
| `f821853` | Uren: the Geklokt column showed the **planned** times when nobody clocked (black on the black-on-white screen, so it looked clocked); now "Niet geklokt" (C1) |
| `a6a157b` | Uren dialog: "Verwijder dienst / Dienst en uren definitief verwijderen?" only deletes the hours line; wording says so |
| `50a900a` | Draaiboek editor: **Delete** removed the whole draaiboek without a confirm |
| `3e8ac92` | Planning → Worker preview: "Hide name" was disabled unless the event asks for availability (10 of 11 coming events) |
| `9663c1e` | Seed: the Testtruck tag is no longer replaced on every seed run (a written sticker stopped working); audit extras |

Waiting for the owner's go-ahead: migration `20261026160000_crew_member_days_per_day` (M1, dry run passed).

## Inventory and results

| Feature | Where | Q1–Q10 notes | Result | Severity |
|---|---|---|---|---|
| Add employee + "has a Foodrun account" | Medewerkers → Add Employee | 1 English labels ("Add Employee", "Name", "Save Employee") on a Dutch screen · 2 typing an email shows "Heeft een Foodrun-account: <naam>. Wordt direct gekoppeld." and fills the name; the hint wraps into three broken columns · 3 saved row appears · 4 Esc/Cancel close, no warning for typed input · 7 n/a · 8 **any operator can see whether any email address has an account and its name** (also in Uitnodigen) · 10 adding someone with an account sends `hired` | bug | minor |
| Two invite paths | Add Employee "Stuur een uitnodigingsmail" vs Uitnodigen | Two different mails/flows (password mail to /me/login vs magic link to the app) for the same job | gap | minor |
| Edit employee | Medewerkers table, inline cells | 2 saved on blur · the old "Edit Employee" dialog can't be opened any more (dead code) | ok | — |
| Colour | Medewerkers → colour dot | ok, shows in Rooster and the app | ok | — |
| Roles (Team column) | Medewerkers | ok. **Teams tab "Assign Employees" and the "(N employees)" count live only in the browser** (never written to `employees.roles`) | bug | major |
| Koppelcode | Medewerkers → Koppelcode | 1–4 ok, Kopieer, Nieuwe code asks first · 5 code stays · 6 ios (join with code) | ok | — |
| Uitnodigen | Medewerkers → Uitnodigen | ok; open invites with valid-until and Intrekken (confirm). Can't copy or resend an open invite's link (only re-invite) · 6 ios (redeem) | ok | — |
| Aanmeldingen | Medewerkers → Aanmeldingen | 1 badge + pulsing bell · 2 Keur goed / Weiger · 3 ok · **Weiger has no confirm, no undo and there is no "recently declined" list** · "Alles goedkeuren" approved hidden rows (fixed `d7d7c5a`) · text mentions "/me/signup" (jargon) · 6 ios (Piet waits) | gap | minor |
| Pending / declined people in the lists | Medewerkers "In dienst", Aanwezigheid, Rooster picker | Piet (pending) shows as "In dienst" with Actief ✓, and was offered in "Dienst aanmaken" (fixed `8417214`); declined people stay in the table without a status | bug | major → fixed (picker), minor open (list) |
| Uit dienst / archive / reactivate | Medewerkers → row → Uit dienst zetten; Uit dienst tab | Archive is a confirm dialog, clears what lies ahead (Bram's 30 Oct shift went), keeps history (his hours stay in Uren) · Weer in dienst no confirm (fine) · 6 ios: Sanne's former employer | ok | — |
| Delete | Uit dienst → Definitief verwijderen | asks to type the name when there are hours | ok | — |
| Clock rule per person | Medewerkers → Klokknop column; Instellingen; Foodtrucks → Kloktag | ok · "Recent employee changes" (Planning) shows raw `clock_without_tag: false → (empty)` | ok | minor (wording) |
| Medewerkers states | — | server down: "No employees yet" (fixed `700b7eb`) · dead Filter / grid menus (fixed `afc2b69`) · three icon-only buttons without a name | bug | major → fixed |
| Rooster: add / move / remove | Rooster | Dienst toevoegen, + Dienst, drag; removal by drag becomes a concept (no confirm, undo "Terugzetten") · → D1, D2 | ok | — |
| Times per day | Shift dialog | ok → D2 | ok | — |
| Break, note, type, checklist | Shift dialog | ok (Foodtruck Weekend 31 Oct). The "FOODTRUCK" box shows the person's team ("Kitchen") when the event has no truck | ok | minor |
| Publish | Rooster → Publiceren / Meteen publiceren | 1 disabled with no reason when there are no concepts · 2 toast "Sanne heeft bericht gekregen" · 10 **publishing a new person sends two messages** (`hired` + `roster_updated`, D1, M2); a time change sends one (D2) | bug | major |
| Wanted vs planned | Rooster Per medewerker; Planning "10 / 3 diensten" | ok | ok | — |
| Availability on the board | Rooster band "Beschikbaarheid", Aanwezigheid | ok · Aanwezigheid also lists Piet (pending) and Invite Tester | ok | minor |
| Visible to workers / Hide name | Planning → board switch, Worker preview | Hide name was disabled unless Visible (fixed `3e8ac92`); the server shows "Festival" (feed checked); labels in English | bug | major → fixed |
| Ruilverzoeken | Rooster → Ruilverzoeken | dialog clear (Wacht op jou / op een collega / afgehandeld) · the button disappears when there were no requests in 14 days · **M1: a swap offered for a day the colleague is off on a multi-day event can't be accepted (`already_on_shift`) and sends no message** · "Swaps happen at once" = Instellingen → Diensten ruilen | bug | major (migration ready) |
| Availability rules | Aanwezigheid → Tools → Regels instellen; day lock | deadline, reason required ok; closed day by the lock → D3 (no toast, the lock icon changes) · **Herinnering sturen sends to everyone without a confirm**; no automatic reminders | gap | minor |
| Verlof | Aanwezigheid → Verlof | list, filters, + Verlof, approve / reject (reject no confirm) · approving doesn't take shifts off unless "Als concept van het rooster halen" · this header has no Instellingen gear | ok | minor |
| Uren: approve / reject / edit | Uren | ok; reject reason optional here but required in Planning → Uren te keuren · an approved line can't be reopened · group button reads "Keur [iOS goed" (first word of the event name) · ios for approve/reject of app hours | ok | minor |
| Uren: clock events next to hours | Uren dialog, list | dialog: Gepland / Geklokt (app) / payable side by side ✓ · list column showed planned times as clocked (fixed `f821853`) · night shift (fixed `e814b97`) | bug | major → fixed |
| Uren states | — | server down: "Uren konden niet worden geladen: …" ✓ (KPI tiles show 0) | ok | — |
| Kloktags | Foodtrucks → truck → Kloktag | link, QR, Kopieer, Vervang tag (confirm), org rule · only trucks HQ knows get a tab: "Testtruck" had an active tag but wasn't a truck of the company, so HQ couldn't show it (seeded now) · every company sees Vietnamama's built-in trucks (Mees, Mike, …) | ok | minor |
| Activity → Crew-app | Activity → Crew-app | sections per person, tasks, checklists ok · counts and answers coming back: ios · crew pins can't be removed in the draaiboek editor | ok | minor |
| Draaiboek editor | Draaiboeken → edit | headings, icons, pictures, PDF, per-person visibility, links, files, Setup (read-only) present · Delete without confirm (fixed `50a900a`) · ios for what reaches the app | bug | major → fixed |
| Planning board | Planning tab | **edits go straight to the published roster (no concept, Publish, Logboek or message) and its open shifts are stored in `open_shifts`, which the Rooster and the app never read** (M3) | bug | major |
| Teams | Teams tab | search didn't filter (fixed `afc2b69`); Assign Employees local only (see Roles) | bug | major |
| Language | everywhere | Dutch and English mixed (nav "Activities", "Tasks", "Dishes"; "Add Employee", "Worker preview", "Recent employee changes", `hired` / `removed` messages "You're on a new festival") | bug | minor |
| Notifications on roster changes | server trigger on `activities.employees` | `hired` / `removed` fire on the flat list only: adding someone to a second day of an event they're already on, or taking them off one day, sends nothing outside Publish; hidden events say "A festival" here and "Festival" elsewhere | bug | minor |

## Step 2b — clocking (HQ side)

| # | Can HQ see it / act on it? | Result |
|---|---|---|
| C1 forgot to clock in | Sent hours show "Niet geklokt" in the list (fixed) and "Geklokt (app): Niet geklokt" next to "Gepland" in the dialog; approve / edit / reject knowingly ✓. A shift with no hours and no clock (Afgelopen markt) only shows as a "Gepland" card in Uren → Per medewerker | ok (after fix) |
| C2 clocked in late | Dialog shows planned, clocked and payable side by side; "Afwijking" flag above the threshold ✓ | ok |
| C3 forgot to clock out | The "Nu aan het werk" strip only looks back 24 h: Sanne's seeded open clock-in (25 Oct 10:04) is **invisible everywhere in HQ** today. No warning, no "still clocked in" list, no "clock out for them". The server never closes it automatically (good: not silently) | **gap, major** — G2 |
| C4 scanned twice | Not detected; HQ can't remove a clock event | gap, minor — G3 |
| C5 wrong truck | `clock_with_tag` raises `no_shift_here_today` before writing anything (code) — confirm with ios | ios |
| C6 night shift 22:00–02:00 | Server pairs the clock-out with the open shift (code); Uren showed it as never clocked out (fixed `e814b97`) | ok (after fix) |
| C7 operator corrects the time | Only the **payable window** on the hours line (Uren dialog), logged in the Logboek with who and when; the original clock times stay visible in "Geklokt (app)". Clock events themselves can't be changed in HQ, `source = 'manual'` is never used, `shift_clock_events` has no who-changed columns, and **an edit sends the worker no message** (only approve / reject do) | **gap, major** — G1 |
| C8 operator adds a missing clock-in / out | Not possible in HQ (the database would allow it) | **gap, major** — G1 |

## Proposals for the gaps (not built — waiting for the owner)

- **G1 Clock corrections.** In the Uren dialog, "Geklokt (app)" gets "Corrigeer" / "Inklok toevoegen": writes `shift_clock_events` with
  `source = 'manual'`, plus `created_by`, `edited_by`, `edited_at`, `original_event_at` columns (or a small audit table), shows
  "aangepast door <naam>" next to the time, and sends the worker one message "Je inklok van 25 okt is aangepast: 10:04 → 10:00".
- **G2 Still clocked in.** Uren: a "Nog ingeklokt" list without the 24 h limit, flagged once the shift's end + 2 h has passed, with
  "Uitklokken om <eindtijd>" (a manual event from G1). Optional: a push to the worker 30 min after the shift end.
- **G3 Double scan.** Flag an in and out less than 2 min apart as "Waarschijnlijk dubbel gescand", with remove (needs G1).
- **G4 Aanmeldingen.** A confirm on Weiger and a "Recent geweigerd (30 dagen)" list with "Toch goedkeuren".
- **G5 One message per publish (M2).** Let Publish write the roster and the messages in one RPC that tells the `hired` / `removed`
  trigger to stay quiet (transaction-local setting), and make those two messages Dutch.
- **G6 Planning board.** Use the Rooster's concepts + Publish and `daily_required_headcount` (M3), or make it read-only.
- **G7 Teams.** Write "Assign Employees" to `employees.roles`.

## What I couldn't test (yet)

- Everything that needs the app's side: `ios-did.md` doesn't exist yet (Q5/Q6 for the app, C1–C8 with real clock events).
- Approve / decline of Piet and of Sanne's pending hours: left open on purpose, the app needs those states.
- Large lists (100+ employees): the test company has 7 rows; not seeded.
- A non-owner manager: there is no second operator account in the test company.
