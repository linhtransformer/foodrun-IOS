# iOS → HQ: data the app audit still needs

Written by the iOS session, **Thu 29 Oct 2026**. Make these in **Foodrun Testbedrijf** on `[iOS test]` events and
write what you made (name, date, id) in `hq-done.md`.

| # | Need | Why | Detail |
|---|---|---|---|
| N1 | **A night shift for Sanne tonight**, Thu 29 Oct **22:00 – Fri 30 Oct 02:00**, on **Testtruck** | C6 (clock in before midnight, out after it — both on one shift and one work day) | The seeded "[iOS test] Klok: nachtdienst" was 28 Oct and has passed. Note Sanne already has Stadsfestival 10:00–18:00 on Testtruck today: the night shift must start after she is clocked out there. Please also say which tag link is on Testtruck right now (to the user, not in this file). |
| N2 | Keep **Testtruck 2** with its own active tag | C5 (wrong truck, and scanning truck B while clocked in on A) | Sanne has no shift on Testtruck 2. The user scans it with the phone. |
| N3 | Optional: one more Stadsfestival-style day **tomorrow** with a tag, for C4 (two scans within a minute) | C4 | If tomorrow's Stadsfestival shift on Testtruck stays, that is enough. |

Re-seeding moves every date with "today"; if you re-seed, write the new dates for N1–N3 in `hq-done.md`.

## Forgot to clock out with the tag (asked by the user, 29 Oct)

| # | Need | Detail |
|---|---|---|
| N4 | **A note in HQ on hours without an NFC clock-out** | When a shift has a clock-in but **no clock-out** (the worker forgot the tag), HQ shows on that shift's line in Uren — and on the hours when they are sent — a clear note: **"Niet uitgeklokt met NFC — eindtijd door medewerker ingevuld"** (or "… nog niet ingevuld" while no hours are sent). So the manager knows the end time comes from the worker, not from the tag. The app already lets the worker set the real end time on the hours card; no app change and no notifications (to the worker or the manager). |
| N5 | **The next scan must not close the old shift** (`clock_with_tag`) | Today a clock-in stays "open" for 18 hours. A worker who forgot to clock out at 22:00 and scans the same truck at 10:00 the next morning is **clocked out of yesterday's shift** instead of clocked in on today's. Rule: only clock out on the open shift while its **planned end + 4 hours** has not passed (that keeps night shifts working: 22:00–02:00, clocked out at 03:00, still lands on the night shift). After that, the scan clocks in on today's shift, and the old shift keeps its open clock-in with the N4 note. Never close it silently. Please add a test for: forgot to clock out → next-day scan clocks in; night shift → clock-out after midnight still closes the night shift. |

## Rate limits (asked by the user, 30 Oct)

Server only; the app already reads the error codes below (from build 12) and shows a plain message.
Keep the messages as `P0001` with the code as `message`, like the existing `too_many_attempts` of the join code.

| # | Where | Limit | Error code → app says |
|---|---|---|---|
| N6 | `clock_with_tag` | Per account: max **30 calls per hour**, and after **10 `invalid_tag` in a row** a **15-minute** pause (counts reset on a valid scan). Normal use (in, out, a mis-scan, scan again) stays far below. | `too_many_attempts` → "Te veel scans in korte tijd. Wacht een paar minuten en probeer het opnieuw." |
| N7 | `request_shift_swap`, `request_shift_takeover`, `request_open_shift` | Per account: max **20 new requests per day** (Europe/Amsterdam), counted together. Withdrawn ones still count. Answering (`respond_shift_swap`) and withdrawing are not limited. | `too_many_requests` → "Je hebt vandaag al veel verzoeken gestuurd. Probeer het morgen weer, of vraag het je planner." |
| N8 | HQ → Aanwezigheid → **Herinnering sturen** | A **confirmation** before sending ("Herinnering sturen naar N medewerkers?") and at most **once per week per organisation** (show when the last one went out). | HQ only |

Not needed: the invite `peek` (32-character token, can't be guessed) and the invite link itself (already 7 days, single use, replaced by a newer invite).
Please add a test for N6 and N7 and write the migration name in `hq-done.md`.

## Overnight clock-out test (asked by the user, Thu 5 Nov)

| # | Need | Detail |
|---|---|---|
| N9 | **An overnight shift for Sanne** (`ios.worker@test.foodrun.nl`, employee `909021d9`) on **Testtruck**: **Thu 5 Nov 14:00 → Fri 6 Nov 08:00**, published, `[iOS test]` event | The user clocks in with the Testtruck tag this afternoon and clocks out with the same tag **tomorrow morning**. With N5 the clock-out still lands on this shift until **planned end + 4 h = Fri 12:00**. Make sure Sanne has **no other Testtruck shift** from Thu 12:00 to Fri 14:00 (the scan picks the open / nearest shift), that her row is **approved**, the Testtruck tag is active, and her scan count (N6) is empty. Write the event name / id in `hq-done.md`. Afterwards: check in HQ that both clock events sit on this one shift, on **Thu 5 Nov** (the shift's date), and that Uren shows one line with the overnight hours. |

## Tell the employer about odd clock times (asked by the user, Fri 6 Nov)

Only the **employer / planner** is told; the worker gets nothing extra. One message per shift and case,
never repeated for the same shift. Nothing changes in the app.

| # | Need | Detail |
|---|---|---|
| N10 | **Not clocked out with the NFC tag** | When a shift has a clock-in but **no clock-out by its planned end + 4 h** (the N5 window has closed), the employer gets **one** notification: "Sanne Tester is niet uitgeklokt met NFC · [event], do 5 nov (gepland tot 08:00)". It links to that line in Uren, which already carries the N4 note "Niet uitgeklokt met NFC". Also when the worker later clocks out with the **button** instead of the tag: the line says "Uitgeklokt met de knop" so the employer sees the tag was skipped. |
| N11 | **Hours far from the planned shift** | When hours are **sent** (or a shift is clocked in + out) and the worked time differs **3 hours or more** from the planned shift (longer or shorter), the employer gets **one** notification: "Sanne Tester: 18 u 32 min gewerkt, gepland 18 u (do 5 nov, [event]) · 3 u 55 min later uitgeklokt". The Uren line gets a flag "Wijkt 3+ uur af van het rooster". Make the 3 hours a setting per employer in HQ (default 3). |

Where the employer sees it: HQ's own notifications / inbox (and the operator's phone if the owner uses the app,
as a `worker_notifications` type the app can show in Berichten). Write the new type names in the contract.

## The hours flow from start to end (asked by the user, Sat 7 Nov)

The user wants to see in the app, as **Sanne** (`ios.worker@test.foodrun.nl`), every stage of hours. Make this in
**Foodrun Testbedrijf**, `[iOS test]` events, dates relative to today (Sat 7 Nov). Write names / dates in `hq-done.md`.

| # | Stage | Make |
|---|---|---|
| N12 | **Worked, no hours yet** | Two finished shifts this week (e.g. Wed 4 Nov 10:00–16:00 and Thu 5 Nov 12:00–20:00) with a clock-in and clock-out, **no** `employee_hours` row. They show under Uren → "Wachtend op jou" with the clock times filled in. The user sends one of them from the phone. |
| N13 | **Sent, waiting** | One shift last week with hours `pending` and a note ("Iets later gestopt, kassa telde niet"). Shows in the month list as "In behandeling". |
| N14 | **Approved** | Three shifts in October and two in November with hours `approved` (different lengths, one with a 30 min break). They show in the month list as "Goedgekeurd", count in the "Goedgekeurd" total, and on the approved-hours page. One of them approved **today**, so its `hours_approved` message is new in Berichten. |
| N15 | **Rejected** | One shift with hours `rejected` and a reason ("Je eindtijd klopt niet met de klok, pas aan"). It comes back under "Wachtend op jou" with the reason, ready to correct and send again. |
| N16 | **The user's own send, live** | When the user sends the overnight shift (Thu 5 Nov, 17:23 → 11:55) or one of N12 from the phone: **approve it in HQ within a few minutes** (Uren → the line → Goedkeuren), so the user sees it go from "In behandeling" to "Goedgekeurd" and gets the message. Write the time you approved it in `hq-did.md`. |

Also check in HQ that every sent line shows the note, planned vs clocked vs sent, and (for the overnight one) the N11 flag.


## Admins in the app (asked by the user, Mon 9 Nov)

The owner can make **certain employees admin**. An admin keeps their normal worker app, and also sees **every event
of that company** in the roster. They can open any event's script (draaiboek) and do the crew work there: prep checklist,
tasks, stock count, setup pins — as if they were on the shift. They do **not** edit the roster or hours (that stays the
owner's). The app only shows what the server allows; nothing in the app decides who is admin.

| # | Need | Detail |
|---|---|---|
| N17 | **An admin flag per employee, set by the owner** | In HQ → Medewerkers, a switch "Admin in de app" on an employee (owner only). If HQ already has a role that fits (team lead / planner / org member role), reuse it instead of a new column, and tell us its name. Write it in the contract. |
| N18 | **The admin's events** | One RPC the app calls on load, e.g. `get_my_admin_events(p_from date, p_to date)`: for each organization where I am admin, its **published** events in that range, the same shape as `get_my_worker_activities` rows (id, name, location, food_truck, color, dates, daily times), plus `organization_id`. Empty for non-admins (no error). Hidden names stay hidden as for workers. |
| N19 | **Script and crew work for admins** | `get_my_event` returns the full event for an admin of its organization, also when they are not rostered (all sections the operator turned on for crew, all days). The crew writes accept an admin the same way: `set_my_prep_item`, `submit_my_task_response`, `submit_my_stock_count`, `submit_my_location_pin` / `delete_my_location_pin`. Each write is stored under the admin's own name, as now. |
| N20 | **Test data** | In Foodrun Testbedrijf: make **Sanne** (`ios.worker@test.foodrun.nl`) admin, and make sure there is at least one published `[iOS test]` event this week she is **not** rostered on, with a draaiboek and a prep checklist. Write its name in `hq-done.md`. |

The app side (roster shows the admin's events, opening one opens its script) follows once N17–N19 are in the contract.

## Who ticked a prep line (asked by the user, Mon 9 Nov)

Several people (crew, admins, the prep portal) work on one prep list. The app should show under each line who ticked
it, as HQ's prep portal already does ("Afgevinkt door Sanne Tester · don 10:11").

| # | Need | Detail |
|---|---|---|
| N21 | **Who and when on each prep item in `get_my_event`** | Four more keys on every `prep.items[]` row, null when unknown: **`checked_by_name`** (full name of who ticked it, only while `checked` is true), **`checked_at`** (timestamptz), **`packed_by_name`** and **`packed_at`** (who last set the packed amount). The same data the prep portal shows; ticks from the portal and from HQ count too. Use exactly these key names: the app (build 19) already reads them and shows nothing while they are missing. Write it in the contract. |
