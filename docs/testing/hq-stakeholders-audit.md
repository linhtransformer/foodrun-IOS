# Prompt — Foodrun HQ (desktop): test every Stakeholders feature, think through every flow

Paste everything below the line into the Claude session that works on the HQ desktop app.
Its partner prompt for the iOS app is `docs/testing/ios-feature-audit.md` in the iOS repo
(https://github.com/linhtransformer/foodrun-IOS). The two sessions exchange the handoff
files described at the end.

---

You are testing **Foodrun HQ**, the desktop app operators use, and in particular everything
under the **Stakeholders** nav, plus the parts of an activity that feed the crew app:
the script editor, Crew-app access and tasks. The goal is that **every feature works**,
that **every flow is finished** (after any click there is a way forward, a way back and a
clear result) and that **everything the iOS crew app writes shows up correctly here**, and
the other way round.

## Rules

- **Only test data.** Use only the organisation **Foodrun Testbedrijf**, events whose name
  starts with **`[iOS test]`**, and test employees (Sanne Tester `ios.worker@test.foodrun.nl`,
  Linh Tran as owner, and any extra test people you create). Never change a real event,
  employee or customer: approvals, roster changes and invites send real notifications.
- **Schema changes are allowed only as a migration** in the HQ repo, written down in the
  iOS contract (`FoodrunApp/Supabase/SchemaContract.md` in the iOS repo) and reported in
  the handoff. Don't change an RPC's arguments or return shape without saying so: the iOS
  app decodes them exactly.
- Don't write passwords, keys or invite tokens into files or commits.
- Fix small things in HQ straight away, one change per commit. Bigger ones go on the
  findings list.

## Step 0 — set up what the iOS session needs

Read `docs/testing/handoff/ios-needs.md` from the iOS session. The user gives it to you, or
it's in the iOS repo. Create every item in the test organisation. If it isn't there yet,
use this standard set:

1. **Accounts.** Test worker Sanne Tester, approved, with a colour. Owner Linh Tran, who
   also works a shift. One worker not yet approved, waiting under Aanmeldingen.
2. **Shifts for Sanne**, all `[iOS test]`:
   - **today**, on a truck with an NFC tag
   - **tomorrow**
   - **3 days ago**
   - a **multi-day event** where she's rostered on 2 of its days
   - one event with **"Hide name from workers"** on
   - one roster entry with break, note, shift type and a checklist
   - one shift **opened for availability**, not rostered
3. **A full draaiboek** on today's event:
   - day note
   - menu with a dish that has a recipe and allergens
   - two locations with coordinates
   - three sections: bold text + a link / two pictures / a PDF + per-person visibility
   - links, files, a ticket
   - team
   - build-up, power plan, teardown
4. **Crew-app access** for Sanne: briefing, dishes, prep, stock.
5. **Tasks** on today's shift, one of each kind (`check`, `count`, `number`, `text`,
   `photo`), plus a week goal and a library checklist.
6. **Hours:** one pending, one approved, one rejected with a reason.
7. **Availability rules:**
   - a closed day next week
   - a deadline still to come
   - reason required
8. **People:**
   - Sanne and Linh on the same shift
   - an open place on a coming shift
   - a swap offered to Sanne
   - leave: one pending, one decided
9. **Codes:** the join code, one email invite to a fresh address, and a second test
   organisation.
10. **History:** one "uit dienst" employee with past shifts.
11. **For the clocking scenarios** (step 2b): a shift that started 2 hours ago, one that
    ended yesterday, one tonight 22:00–02:00, and a second truck with its own tag.

Write what you created to **`docs/testing/handoff/hq-done.md`**: per item the name, date and
id, or "blocked: <reason>" if HQ can't make it.

## Step 1 — inventory

Open the **Stakeholders** nav and list **every** screen, tab, button, filter and dialog in
`hq-results-<date>.md`, before testing anything. Expect at least the items below, and add
whatever else is there:

**Medewerkers**
- Add employee, including "has a Foodrun account" (`find_worker_account`)
- Edit
- Colour
- Roles
- Koppelcode (join code)
- Uitnodigen (email invite)
- Uit dienst / archive / reactivate
- Delete
- Clock rules per person: tag only, or the button allowed

**Rooster**
- Planning board: add / move / remove a person
- Times per day
- Break, note, shift type, checklists on an entry
- Publish
- Wanted vs planned shifts
- Availability shown on the board
- "Visible to workers" and "Hide name from workers" on an activity

**Ruilverzoeken**
- Approve / decline offers, open places and asks
- "Swaps happen at once" setting

**Beschikbaarheid (availability rules)**
- Deadline
- Closed days
- Reason required
- Reminders

**Uren**
- Approve / reject with a reason
- Edit
- Clock events next to the submitted hours

**Aanmeldingen**
- Join requests: approve / decline, including "recently declined"

**Verlof**
- Approve / reject leave

**Kloktags**
- One tag per truck / vestiging
- Make / replace a tag
- The link `https://foodrun.nl/clock/<token>`
- Organisation-wide button rule

**Activity → Crew-app**
- Sections per person
- Script editor: headings, icons, pictures, attachments, per-person visibility, links,
  files, locations, Setup part
- Crew tasks, prep list, stock counts coming back
- Crew pins on the map

## Step 2 — test each feature with these questions

For **every** feature, go through all of these, one line each ("n/a" is an answer, a blank
is not):

1. **Way in.** Can an operator find it without being told? Does the label say what it does?
2. **Action and feedback.** After the click, is there a visible result: toast, changed row,
   spinner? Is a double click harmless?
3. **The next step exists.** After saving, is there a way on: back to the list, "Send",
   "Publish", "Undo", the next item? **Look for dead ends:**
   - a dialog with no save or close
   - a success state with nothing to click
   - a disabled button with no reason
   - a required field that isn't marked
4. **Way back.** Cancel / Escape / back. Does unsaved input get lost without warning?
5. **It stuck.** Reload the page, log out and back in. Is it still there? **Does it reach the
   crew app?** Write it in `hq-did.md` so iOS can check.
6. **The other direction.** For every item in `ios-did.md`, does HQ show it correctly, in the
   right place, with the right person, time and status?
7. **States.**
   - empty
   - loading
   - error: network off, server refusing
   - large lists: 100+ employees, a long event
   Each needs plain words, never a raw error or a silent failure.
8. **Roles and visibility.**
   - Does "Hide name from workers" really hide the name in the crew app?
   - Does per-person visibility in the script only reach that person?
   - Does an archived employee lose access but keep their history?
   - Does a non-owner see only what they should?
9. **Dates and time zones.**
   - today / past / future
   - multi-day
   - past midnight
   - week boundaries
   - Europe/Amsterdam vs UTC, so a clock event at 00:30 lands on the right shift
10. **Notifications.** Every action that should notify a worker does so exactly once, with
    the right type:
    - hours decision
    - task assigned
    - swap kinds
    - leave decision
    - availability reminder
    - roster updated
    - profile edited
    No action notifies when it shouldn't, for example on a test that's undone.

## Step 2b — clocking when things go wrong

The iOS session plays these out on `[iOS test]` shifts and writes them in `ios-did.md`
(scenarios C1–C8). For each one, check what **HQ** shows and what an operator can do about
it:

| # | Scenario (done in the app) | Check in HQ |
|---|---|---|
| C1 | **Forgot to clock in**, sent hours anyway | Does Uren show the hours without a clock event, and mark that clearly (e.g. "geen inklok")? Can the operator approve, edit or reject knowingly? |
| C2 | **Clocked in late** | Are planned, clocked and submitted times side by side, with the difference visible? |
| C3 | **Forgot to clock out** | Does HQ show an open clock-in that is hours or days old? Is there a list or warning of "still clocked in"? Does the server ever close it automatically? It should not do so silently. |
| C4 | **Scanned twice** within a minute | An in and an out seconds apart: is that visible as a probable mistake? Can the operator remove it? |
| C5 | **Wrong truck** | Nothing written. If something was written, that's a bug. |
| C6 | **Night shift**, 22:00–02:00 | Both events on the same shift and the same work day, in Europe/Amsterdam. |
| C7 | **Operator corrects the time** | **Can an operator change someone's clock-in / clock-out, or the hours, here, and where?** After saving: <br>• is it stored as `source = 'manual'`, with who changed it and when (audit)? <br>• does the original time stay visible? <br>• does the worker get exactly one notification that says what changed? <br>Write each change in `hq-did.md` so iOS can check that the app follows. |
| C8 | **Operator adds a missing clock-in or clock-out** for C1 / C3 | Possible? Is it marked as added by the operator? Does the app pick it up (via `hq-did.md`)? |

If something can't be done in HQ at all (for example there's no way to correct a time, no
"still clocked in" overview, or no audit of who changed it), mark it `gap` with a short
proposal. Don't build it without the user's OK.

## Step 3 — record and fix

`hq-results-<date>.md`, one row per feature:

`| Feature | Where | Q1–Q10 notes | Result: ok / bug / gap | Severity: blocker / major / minor |`

- **blocker** — an operator can't plan, approve or pay
- **major** — wrong data, a dead end, a notification missing or doubled, or the app and HQ
  disagreeing
- **minor** — looks or wording

Fix what you can in HQ and retest. Anything that needs the iOS app to change goes to
`mismatches.md`.

## Handoff with the iOS session

Plain Markdown under `docs/testing/handoff/`, carried across by the user:

- `ios-needs.md` (iOS writes, you read): data to create in step 0.
- `hq-done.md` (you write): what you created, with names, dates and ids.
- `ios-did.md` (iOS writes, you read): every action done in the app. Check each one in HQ
  and mark it `seen ok` / `seen wrong: …` / `not seen`. In particular:
  - clock in / out by tag and by button
  - submitted hours, with times and note
  - availability, reasons and wanted shifts
  - swap offers, asks and open-place requests
  - leave requests
  - task answers, including the photo
  - prep ticks and stock counts
  - pins (with the pinner's name)
  - join requests and redeemed invites
- `hq-did.md` (you write): every change made in HQ that the app should follow, each with
  time, event and day. For example:
  - "moved Sanne's 25 Oct shift to 09:00"
  - "rejected hours of 21 Oct with reason X"
  - "added picture to section TEST Pictures"
  - "closed 30 Oct for availability"
  - "archived employee Y"
- `mismatches.md` (both): each disagreement between HQ and the app, with which side should
  change.

When you're done, summarise for the user:
- how many Stakeholders features you checked
- the blockers and majors, fixed or open
- what the iOS side still needs to do
- what you couldn't test, and why
