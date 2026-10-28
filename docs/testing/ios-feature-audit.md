# Prompt — iOS app: test every feature, think through every flow

Paste everything below the line into a Claude Code session on the Mac (repo
`~/Developer/foodrun-IOS`). Its partner prompt for the desktop is
`docs/testing/hq-stakeholders-audit.md`: the two sessions exchange the handoff
files described at the end.

---

You are testing the Foodrun crew app for iOS (SwiftUI, repo `~/Developer/foodrun-IOS`,
backend `https://supabase.foodrun.nl`). The goal is that **every feature works** and that
**every flow is finished**: after any tap there is a way forward, a way back and a clear
result. You run the app in the iOS Simulator, and on the user's iPhone for NFC.

## Rules

- **Don't change the backend or the schema.** If the app and the server disagree, write it
  down for HQ (see "Handoff"). The contract is `FoodrunApp/Supabase/SchemaContract.md`.
- **Only test data.** Use only the organisation **Foodrun Testbedrijf** and events whose
  name starts with **`[iOS test]`**. Never touch a real event, a real employee or a real
  customer: notifications go to real phones.
- **No accounts of your own.** The user signs in, or gives you the test login in chat. Never
  write a password into a file, a commit or a reply.
- `FoodrunApp/Supabase/SupabaseManager.swift` holds the anon key and is skip-worktree.
  Never print, diff or commit it.
- Fix small things straight away: one change per commit, built and checked in the
  simulator, then pushed to `main`. Put anything bigger on the findings list instead.
- Keep `Localizable.strings` EN and NL in step. After every edit, check that
  `plutil -p <file> | grep -c '=>'` equals `grep -c '^"' <file>` for both.

## Step 0 — what the account must have before you start

Many screens only show up when the right data exists, for example an open swap, a
rejected hour or a closed day. Before testing, **write `docs/testing/handoff/ios-needs.md`**
listing the data you need, and ask the user to give it to the HQ session. Start from this
list, keep what still applies and add what you find missing:

1. **Accounts.** Test worker `ios.worker@test.foodrun.nl` (Sanne Tester), approved at Foodrun
   Testbedrijf, with a colour. An owner account that also works a shift (Linh Tran). A
   second worker who has *not* been approved yet, so the waiting screen can be tested.
2. **Shifts for the test worker**, all `[iOS test]`:
   - one **today**, on a truck with an NFC tag
   - one **tomorrow**
   - one **3 days ago**, so hours are waiting
   - one **multi-day event**, rostered on 2 of its days
   - one with **"Hide name from workers"** on
   - one with break, note, shift type and a checklist on the roster entry
   - one shift **opened for availability**, not rostered
3. **One full draaiboek** on the shift for today. It needs:
   - day note
   - menu with dishes, one of them with recipe and allergens
   - event block
   - two locations with coordinates
   - three sections: one with **bold** text and a link, one with two pictures, one with
     a PDF attachment and per-person visibility
   - links and files (including a ticket)
   - team
   - build-up, power plan and teardown
4. **Crew-app sections on for the worker:** briefing, dishes, prep and stock.
5. **Tasks for today's shift:** one of every kind (`check`, `count`, `number`, `text`,
   `photo`), plus a week goal and a checklist from the library.
6. **Hours:** one shift pending, one approved and one rejected with a reason.
7. **Availability rules:**
   - one closed day next week
   - a deadline that is still coming
   - "reason required" on
8. **People:**
   - a colleague (Sanne ↔ Linh) on the same shift
   - an open place on a coming shift
   - a swap offered to the test worker
   - a leave request: one pending, one decided
9. **Codes:** the organisation's join code, an email invite link for a fresh address, and a
   second organisation (also test) that the worker can join with that code.
10. **A former employer:** an "uit dienst" employee row with past shifts, to test history only.
11. **Clocking scenarios** (step 2b): a shift that started 2 hours ago (for a late clock-in), one
    that ended yesterday (for a forgotten clock-out), one tonight 22:00–02:00, and a second
    truck with its own tag (for the wrong-truck scan).

Wait until HQ confirms each item, with ids or names, in
`docs/testing/handoff/hq-done.md`. Items that HQ can't create stay on the list, marked
"blocked: <reason>".

## Step 1 — inventory

Before testing, list every feature with its entry point in
`docs/testing/results/ios-<date>.md`. Start from this list and add anything you find in
`FoodrunApp/Screens`, `Sheets`, `Auth` and `Invitations` that isn't on it:

**Signing in**
- Log in with email and password
- Show / hide password
- Sign up, then "check your email"
- Resend the confirmation email
- Sign in with Apple and Google
- Forgotten password: code, then a new password
- Password AutoFill and saving the password
- Session expired
- Waiting screen (not linked yet): Share, "Check again"
- Join with a code: check the code, then send the request
- Invite link (`https://foodrun.nl/invite/<token>`), signed in and signed out, and for
  another account

**Diensten (shifts tab)**
- Today's shift card floating above the tab bar: fold / open, timer, **Klok in / Klok uit**
  pill. Only shown on the day itself
- "Nog te werken" list
- Pull to refresh
- **Bezetting:**
  - week carousel and month grid
  - colleagues by name
  - tapping a colleague opens their shift, view only, with "Vraag om deze dienst over te
    nemen"
  - open places: "Ik wil deze"
  - owner only: **+ add shift** (multi-day, search, floating Save) and editing or removing
    a rostered person
- **Beschikbaarheid:**
  - shifts wanted this week and per week
  - day window slider
  - available / not available, with a reason
  - colours: green / red / grey = there is work, and "Werk op deze dag"
  - closed day, deadline pill, Save week

**Shift screen**
- Summary card, folded / open
- NFC strip and the **Klok in** button. A shift that isn't today shows "Inklokken kan op…"
  or the next shift
- **Draaiboek:**
  - day note
  - your day / tickets
  - menu with recipes
  - event
  - locations with Route
  - **Locatie pinnen**: name, note, photo, the pinner's label top right, removing your
    own pin
  - sections with bold text, links, pictures and attachments
  - links, files, team
- **Setup:** build-up, power, teardown. Setup pins only once `AppConfig.Features.setupPins`
  is on
- **Taken:**
  - every task kind, including the photo upload
  - prep list (tick, amount, note)
  - stock count
- Ruilverzoek: offer a shift, see its status, withdraw it

**Taken (tasks tab)**
- Today and coming days
- Week goals
- Checklists grouped under their title
- Badge count

**Uren (hours tab)**
- Waiting cards: always open, wheel, note, Send
- Month list and statuses
- Approved hours
- Badge

**Berichten (inbox)**
- Every notification type opens the right place:
  - hours approved / rejected
  - `task_assigned`
  - every swap kind
  - leave approved / rejected
  - availability reminder
  - `roster_updated`
  - shift changes made in HQ
- Swap cards that wait for an answer: give / keep
- Unread dot and badge

**Ik (me tab)**
- Your organisations
- Ruilen (with badge), Verlof (ask, withdraw)
- Join an organisation
- Language NL / EN
- Privacy, Help
- Log out, delete account (only as a dry run — never confirm on the real test account)

**Outside the app**
- Tag scanned with the app closed, in the background, or open
- `foodrun://clock/<token>` and `foodrun://` links
- Shift-change notifications and the background refresh

## Step 2 — test each feature with these questions

For **every** feature, go through all of these. Write one line per question in the results
file. "n/a" is an answer, a blank is not.

1. **Way in.** Can a crew member find it without being told? Does the label say what it
   does?
2. **Action and feedback.** After the tap, does something visibly happen within a second:
   spinner, haptic, a changed state? Is a double tap harmless?
3. **The next step exists.** After the action, is there a button for what comes next:
   Close, Done, Undo, "Mijn uren bekijken", back to the list? **Look for dead ends:**
   - a sheet without a close or save button
   - a keyboard covering the only button
   - a success screen with no way out
   - a disabled button with no hint why
4. **Way back.** Back arrow, swipe down, Cancel. Does leaving halfway lose input without
   warning?
5. **It stuck.** Pull to refresh, then fully quit and reopen the app. Is the result still
   there? Does the result show up in HQ? Check this through the handoff.
6. **The other direction.** Change the same thing in HQ, then refresh the app. Does the
   app follow, within a refresh or the next time the screen opens?
7. **States.**
   - empty (no data)
   - loading
   - server error: Airplane Mode, or Network Link Conditioner "100% Loss"
   - the server refusing: deadline passed, closed day, `tag_required`, `in_the_past`
   Each one needs plain words a crew member can act on, never a raw error. "Check je
   verbinding" is only correct when it really is the connection.
8. **Roles.** Worker, owner, colleague (view only), former employer (history only),
   someone not approved yet. Does each one see exactly what fits, and nothing that looks
   editable but isn't?
9. **Dates.**
   - today
   - tomorrow
   - in the past
   - a multi-day event
   - a shift past midnight
   - the week boundary on Sunday → Monday
   - another month in the month grid
10. **Looks.**
    - NL and EN, so no missing keys and no English left in Dutch
    - longest names
    - iPhone SE size and Dynamic Type at its largest
    - dark mode if supported
    - nothing cut off or overlapping (for example a pill over the **+**)

## Step 2b — clocking when things go wrong

People forget, scan twice, or scan at the wrong truck. Test each scenario below on
`[iOS test]` shifts. Write down what the **app** shows, what the worker can do about it, and
which line in `ios-did.md` lets HQ check its side. Then answer the question at the end of
each scenario.

| # | Scenario | Do this | Check in the app |
|---|---|---|---|
| C1 | **Forgot to clock in**, worked the whole shift | No scan, no button, let the shift end | Does the hours card still let them send hours? Which times does it suggest (roster, not clock)? Is there a hint that no clock-in exists, and room for a note? |
| C2 | **Clocked in late**, 2 hours after the start | Clock in mid-shift | Timer, and "sinds …": does it show the clock-in time, not the shift start? Hours card: clock window vs roster times. |
| C3 | **Forgot to clock out**, still "on the clock" the next day | Clock in, don't clock out, look the day after | Does the home card keep a timer running past 24 h? Is there a prompt like "Je bent nog ingeklokt sinds gisteren 12:00"? Can they still clock out? Hours card with a clock-in but no clock-out. |
| C4 | **Scanned twice** within a minute | Scan, then scan again | The second scan clocks out: is that clear, and can it be undone? Should a scan within a few minutes ask first? |
| C5 | **Wrong truck** | (a) Scan a tag of a truck they aren't rostered on today. (b) While clocked in on truck A, scan the tag of truck B. (c) Two workers on the same truck each scan the same tag | (a) Message names the right place or the next shift; nothing gets written. (b) Refused: it must **not** clock them out on A. (c) Each phone clocks only its own account, never the other worker. |
| C6 | **Night shift** past midnight | Clock in 22:00, clock out 02:00 | Clock-out lands on the same shift. Hours card and Uren show one shift, not two days. |
| C7 | **Admin corrects the time in HQ** | HQ changes the clock-in / clock-out or the hours, then writes it in `hq-did.md` | After a refresh: do the hours card, Uren status and month total show the corrected times? Does the worker get a notification that says what changed and by whom? Can the worker see the old and new time? |
| C8 | **Admin adds a missing clock-in or clock-out** | HQ adds the event for C1 / C3 | The app shows the shift as clocked, the timer stops, and the hours card picks up the times. |

For each scenario, also ask whether the app should **help** here. For example:
- a reminder when a shift has started without a clock-in
- a reminder when it ended and the worker is still clocked in
- a "forgot to clock" option when sending hours

Mark each one `gap` with a short proposal. Don't build it without the user's OK.

## Step 3 — record and fix

In `docs/testing/results/ios-<date>.md`, give each feature one row:

`| Feature | Where | Q1–Q10 notes | Result: ok / bug / gap | Severity: blocker / major / minor | Screenshot |`

Save screenshots in the scratchpad and name them in the row. Severity:

- **blocker** — a crew member can't finish the job: can't clock, can't send hours, can't
  sign in
- **major** — wrong data, a dead end, or a misleading message
- **minor** — looks or wording

Fix blockers and majors you can fix in the app, one commit each, then retest the row. A
cause on the server goes to the handoff instead, never into a workaround that hides it.

## Handoff with the desktop session

Both sessions write plain Markdown under `docs/testing/handoff/`. The user carries the
files across, or pushes them to GitHub.

- `ios-needs.md` (you write): the data from step 0, plus anything new you find you need.
- `ios-did.md` (you write): every action you did in the app that HQ should now see, each
  with time, account, event and day. For example:
  - "13:58 Sanne clocked in with tag, [iOS test] NFC-test vandaag, 24 Oct"
  - "submitted hours 12:00–22:00 with note X"
  - "asked to take over Linh's shift on 22 Oct"
  - "pinned 'TEST pin from iOS'"
- `hq-done.md` and `hq-did.md` (HQ writes, you read): what HQ set up, and what HQ changed so
  you can check that the app follows. Check every line of `hq-did.md` in the app and mark it
  `seen ok` / `seen wrong: …` / `not seen`.
- `mismatches.md` (both): every place where the app and HQ disagree, for example a field
  that isn't sent, a different name, or an error code the app doesn't know. Say which side
  should change.

When you're done, summarise for the user:
- how many features you checked
- the blockers and majors, fixed or open
- what HQ still needs to do
- what you couldn't test, and why
