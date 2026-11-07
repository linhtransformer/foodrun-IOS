# HQ → iOS: test data created (step 0)

Written by the HQ session on **Mon 26 Oct 2026**; **re-seeded on Wed 28 Oct 2026, 11:05 (Europe/Amsterdam)**, so every id
and date below is new. There was no `ios-needs.md` yet, so this is the standard set from `hq-stakeholders-audit.md`. All
times are Europe/Amsterdam.

Everything is in **Foodrun Testbedrijf** (org `52e824b3-e19e-41b9-bff5-04c8703dbe65`, owner `ios.operator@test.foodrun.nl`),
unless a line says otherwise. Passwords, join codes, the invite link and the clock-tag links are **not** in this file (this repo
is public): the user has them.

Re-seed (ids change, dates move with today), from the HQ repo:
`npx tsx tests/rostering/seed-ios-test-accounts.ts && npx tsx tests/rostering/seed-audit-extras.ts`

## Read this first

- **Never test owner features as `lit.linhtran@gmail.com`.** That account is the owner of the *real* Foodrun company; adding or
  removing shifts there reaches real staff. In the test company Linh Tran is a plain employee. For owner tests sign in as
  **`ios.operator@test.foodrun.nl`**: it owns the test company and is also employee "Eigenaar Test" with shifts.
- Sanne (`ios.worker@`) also owns an empty "Sanne Tester's Workspace" (every new account gets one at sign-up). If the app shows
  owner things to Sanne, that is why.
- **Server bug found while seeding (HQ will fix, needs a migration):** on a multi-day event `crew_member_days` counts everyone who
  is on *any* day as on *every* day. Effect: the swap the owner offered Sanne for Havenfestival 31 Oct is on her swap board, but
  she got **no inbox message** for it; and a worker can offer a day of a multi-day event they are not rostered on. Don't log
  these two as app bugs. See `mismatches.md`.
- `hq-did.md` D1–D3 were done on the data from before this re-seed. The events they touched were recreated, so D1 and D2 are
  gone; check those lines against what they describe, not against today's roster.
- Setup pins: the server has `submit_my_location_pin(…, p_section text)` live, so D9 can be switched on.

## Items

| # | Item | Created |
|---|---|---|
| 1 | Test worker | **Sanne Tester** `ios.worker@test.foodrun.nl`, employee `909021d9-c2db-4395-8d21-a531da3c33af`, approved, colour `#f0a8c8` |
| 1 | Owner who also works | **ios.operator@test.foodrun.nl** (owner) is also employee **"Eigenaar Test"** `53a72306-6250-441c-8e6b-8ddd20bad52d`: Stadsfestival 29 Oct 10:00–18:00, Havenfestival 31 Oct 11:00–19:00. Linh Tran (`lit.linhtran`, employee `b0c9b6a4-f4f7-4824-9fca-5714915897ef`) is an employee, **not** the owner (see above) |
| 1 | Worker not approved yet | **Piet Wachter** `ios.pending@test.foodrun.nl` asked to join through `worker-self-signup`; employee `d96899fe-7d35-47cf-b58d-b86a3fcf5e17`, status `pending`, under Aanmeldingen. Same password as the other test accounts |
| 2 | Shift today on a truck with an NFC tag | **[iOS test] Stadsfestival** `5ec682c2-5419-4c8c-b0a3-124a9dc24a63`, 28–30 Oct, truck **Testtruck** (active tag kept, so a sticker that already has the link still works). Sanne 10:00–18:00 every day |
| 2 | Tomorrow | Stadsfestival, 29 Oct |
| 2 | 3 days ago | **[iOS test] Afgelopen markt** `cdb2d19b-06fc-426a-add4-7de115bc269f`, 25 Oct 11:00–19:00: no hours sent, no clock events (also C1) |
| 2 | Multi-day, on 2 of its days | **[iOS test] Havenfestival (3 dagen)** `b731a9b5-aa3f-4556-b833-a9a1e4e0c675`, 30 Oct–1 Nov 11:00–19:00. Sanne on **30 Oct and 1 Nov**, not 31 Oct (owner + Linh on 31 Oct) |
| 2 | Opbouw / afbouw on a day of its own | Havenfestival (above) has its **opbouw Thu 29 Oct 19:00–22:00** and its **afbouw Mon 2 Nov 10:00–13:00**, each outside the event's own days (30 Oct–1 Nov). HQ rostered **Sanne on the opbouw**, 19:00–22:00, type **Opbouw** (see `hq-did.md` D4); nobody is on the afbouw. In the app it is a normal shift on 29 Oct under Havenfestival. NFC clocking there works since HQ migration `20261028120000` (applied 28 Oct), the clock button too |
| 2 | "Hide name from workers" | **[iOS test] Besloten bedrijfsfeest** `af5c0973-93f6-4fd9-b034-6f93d95052a0`, Wed 4 Nov 18:00–23:00. Sanne should see **"Festival"** (the worker feed already returns "Festival") |
| 2 | Break, note, shift type, checklist | **[iOS test] Foodtruck Weekend** `267241bc-9b4f-4f19-965b-07335508580e`, Sanne on **Mon 2 Nov** 12:00–22:00: 30 min break, note "Jij doet vandaag de kassa en sluit af.", type **Opbouw**, checklist **Afsluiten** (vestiging Testkeuken Centrum, so the "Centrum" briefing shows too) |
| 2 | Open for availability, not rostered | **[iOS test] Open oproep: Zomerfeest** `fb2301d0-1c8f-4a74-968e-9b63ad8596d8`, 9–10 Nov |
| 3 | Draaiboek on today's event | Stadsfestival: day note on 28 Oct; menu **Pho Bo** (recipe, photo, allergens Gluten / Soy / Celery, may contain pinda's); event comments; **2 locations** with coordinates (crew-ingang + Crewparkeerplaats Museumgarage); sections **"TEST Opmaak"** (`**vet**`, `*schuin*`, a `[link](…)` and a bare URL), **"TEST Foto's"** (2 pictures, landscape + portrait), **"TEST Bijlage (alleen Sanne)"** (PDF, visible to Sanne only), plus Aankomst (photo), Kleding, Huisregels (PDF); 2 links; event file (plattegrond); Sanne's ticket + a ticket without a name; team (Sanne, Linh, owner on 29 Oct); build-up 27 Oct 14:00–18:00 (photo), power plan (32 A, 2 outlets), teardown 30 Oct 20:30–23:00 |
| 4 | Crew-app access | Stadsfestival: briefing, dishes, prep, stock on for everyone (Sanne included) |
| 5 | Tasks on today's shift | Stadsfestival: `count` Tel de havermelk, `check` Mise-en-place Pho Bo, `number` Temperatuur koelkast, `check` Truck schoon opleveren (Sanne, 28 Oct), `text` Wat viel je op vandaag? (28 Oct), `photo` Foto van de opstelling; library list **Opbouw truck** on the event; week goals **Weekdoelen keuken** for this week |
| 6 | Hours | **waiting**: Afgelopen markt 25 Oct · **pending**: [iOS test] Braderie 22 Oct, 11:00–17:00, 30 min, note "Pauze om 14:00 genomen" (`e522ab22-fd5c-4b60-831c-736e3b6c093b`) · **approved**: [iOS test] Kerstmarkt Leiden 23 Oct, 12:00–20:00 (`f99b7ca8-0ac4-4486-a4dd-63d02dd6636e`) · **rejected** with reason "Je eindtijd klopt niet met het rooster (16:00). Pas aan en stuur opnieuw.": [iOS test] Proefdag keuken 26 Oct, 10:00–17:30 (`98d0c2ba-b16d-4d0d-876d-789d9c485797`) |
| 7 | Availability rules | closed day **Sat 7 Nov**; deadline **Thursday** 18:00 (`weekday` 3, 0 = Monday), one week before (for the week of 2 Nov: Thu 29 Oct 18:00; for the week of 9 Nov: Thu 5 Nov 18:00); reason required **on** |
| 8 | Same shift | Sanne + Linh on Stadsfestival 28–30 Oct (owner too on 29 Oct) |
| 8 | Open place | **[iOS test] Avondmarkt (open plek)** `0c0f4415-a608-4d02-b087-7099cbb960b2`, Tue 3 Nov 17:00–22:00, 2 needed, Linh on it; the team was asked (Sanne got "Open dienst: wil jij?"). [iOS test] Proeverij (open plek) Sun 1 Nov also has an open place, but Sanne is already on it |
| 8 | Swap offered to Sanne | by the owner ("Eigenaar Test"): Havenfestival **31 Oct**, note "Kun jij mijn dienst overnemen? Ik moet naar de accountant." (`d8abdadb-1f92-475d-91bb-17e8d2e204ee`). On Sanne's board; **no inbox message** (server bug above). Also from the base seed: Sanne offers her Bedrijfsevent Fri 6 Nov to Linh (`67cca57c-7d9d-4943-8eca-cb70ea14fdd0`) |
| 8 | Leave | Sanne: **pending** 17–18 Nov "Bruiloft van mijn zus" (`bef12e0e-de84-4c20-8a3c-b5ed7f7d6bcf`), **approved** 1–3 Dec "Weekendje weg", note "Veel plezier!" (`c88686eb-bf28-4fe3-99eb-7b514f80136b`) |
| 9 | Join code | Foodrun Testbedrijf has one (the user has it) |
| 9 | Email invite to a fresh address | `ios.invite@test.foodrun.nl` (no account), placeholder employee "Invite Tester" `27823f76-b7f1-41e3-a3b9-b97d2d32c6d8`, valid 7 days. Made through the same server function as HQ's Uitnodigen but without sending the mail (test.foodrun.nl has no mailbox). The user has the link |
| 9 | Second test organisation | **Foodrun Testbedrijf 2** `47acd48c-a61b-4ea1-b686-91532d5f2fe3`, owner `ios.operator2@test.foodrun.nl`. Sanne is not in it, so its join code (the user has it) can be tried with her |
| 10 | Former employer | **Foodrun Oud-werkgever (test)** `8ff16d48-63e0-44bb-acd9-2e5705a7f97e`, owner `ios.former@test.foodrun.nl`: Sanne's row `843d50a3-a80e-4360-800a-f6bab4191c19` is **uit dienst**, with 2 past shifts (8 Oct, 15 Oct) and approved hours. Note: the worker feed still returns those two events |
| 10 | Uit dienst in the company | **Bram Oudgediende** `73443043-f16b-42d7-baff-87b59e96fbfc` (no account): worked Braderie 22 Oct (approved hours) and Afgelopen markt 25 Oct; his Havenfestival 1 Nov shift was cleared by Uit dienst. For HQ history |
| 11 | Started 2 hours ago | **[iOS test] Klok: begon 2 uur geleden** `f3081002-86fa-4f43-819e-a14106423709`, 28 Oct **09:00–17:00**, no truck (clock with the button). Fixed times: when you test after about 17:00 today, re-seed so it moves |
| 11 | Ended yesterday | **[iOS test] Klok: gisteren, niet uitgeklokt** `1db0ac0b-2bf8-4f2e-bf45-02b288864903`, 27 Oct 10:00–18:00, with a **clock-in at 10:04 and no clock-out** (seeded, `source = 'mobile'`) |
| 11 | Tonight 22:00–02:00 | **[iOS test] Klok: nachtdienst** `077a6208-6727-4b27-a2ea-96ff45cb3841`, 28 Oct 22:00–02:00 on **Testtruck** — **moved to Thu 29 Oct** (N1 below). At the Testtruck tag the shift with the nearest start wins, unless Sanne is still clocked in on Stadsfestival (then the scan clocks her out there) |
| 11 | Second truck with its own tag | **Testtruck 2** (truck of the company, own active tag; the user has the link). Sanne has no shift on it. Testtruck is now a truck of the company too, so HQ shows its tag |

Today Sanne has three shifts (Stadsfestival, "begon 2 uur geleden", nachtdienst). That is on purpose for the clock scenarios;
it also tests what the home card does with more than one shift on a day.

## ios-needs N1–N3 — made Thu 29 Oct 10:48

No re-seed: every other date in this file stays as it is.

| # | Need | What HQ made |
|---|---|---|
| N1 | Night shift for Sanne tonight | **[iOS test] Klok: nachtdienst** `077a6208-6727-4b27-a2ea-96ff45cb3841` moved from 28 Oct to **Thu 29 Oct 22:00 – Fri 30 Oct 02:00**, on **Testtruck**, Sanne only (per-day roster 22:00–02:00). It was unused on 28 Oct (no clock events, no hours), so it was moved rather than re-seeded; no message was sent. Checked: Sanne's feed (`get_my_worker_activities`) has it on 29 Oct. Today she also has **Stadsfestival 10:00–18:00 on Testtruck**: clock out there first. At the Testtruck tag the server takes an open shift first, then the shift whose start is nearest, so a scan around 22:00 clocks in on the night shift, and the scan after midnight clocks out on it (the server looks back one day for an open shift). Testtruck's tag is the active one since 17 Oct, unchanged (the user has the link) |
| N2 | Testtruck 2 with its own tag | Unchanged and active (own tag since 26 Oct; the user has the link). Sanne has no shift on Testtruck 2 on 29 or 30 Oct |
| N3 | A day tomorrow with a tag (C4) | **[iOS test] Stadsfestival** `5ec682c2-5419-4c8c-b0a3-124a9dc24a63` **Fri 30 Oct 10:00–18:00 on Testtruck** stays, with Sanne rostered. Nothing new made |

**N1 again — moved to tonight (Fri 30 Oct 12:26).** The night shift of 29 Oct was not used (no clock events), so the same
**[iOS test] Klok: nachtdienst** `077a6208` is now **Fri 30 Oct 22:00 – Sat 31 Oct 02:00 on Testtruck**, Sanne only; no message was
sent. Checked as Sanne: her feed has it today next to Stadsfestival 10:00–18:00 (Testtruck) and Havenfestival (no truck), and the
clock rules answer for it. Sanne's row `909021d9` is still `approved` and linked (M9); the phone has not signed in since the restore,
so sign in again first. For C6: clock out of Stadsfestival before scanning for the night shift, because an open Stadsfestival
clock-in counts as open until 22:00 (planned end + 4 h), and a scan before then clocks her out there. Same Testtruck tag.

## ios-needs N4–N5 — built Thu 29 Oct 13:05 (HQ `ac67de0`, migration `20261029120000_clock_forgot_out`, live)

No app change, no new messages to the worker or the manager.

| # | Need | What HQ changed |
|---|---|---|
| N5 | The next scan must not close the old shift | `clock_with_tag` only clocks out of an open clock-in until its **planned end + 4 h** (no planned times: 18 h after the clock-in, as before). After that the scan clocks **in** on today's shift at that truck (or answers `no_shift_here_today` when there is none) and the old clock-in stays open. Planned end = own roster time that day → the day's times → opbouw / afbouw times → the event's times; a shift whose end is before its start ends the next day, and a clock-in after midnight on a night shift counts on the night shift's day. So 22:00–02:00 clocked out at 03:00 (until 06:00) still closes the night shift. **One exception:** when the open clock-in is on *today's* day of the same shift (e.g. 06:00–08:00, scanned at 13:00), the scan still clocks out: clocking in twice on one shift means nothing. A festival of several days on one truck: forgot to clock out Friday, Saturday's scan clocks in on Saturday. |
| N5 tests | Forgot to clock out → next-day scan clocks in; night shift → clock-out after midnight closes it | `tests/rostering/clock-tags.ts` sections **8** (clocked in 14 h ago, shift ended 6 h ago → the scan clocks in on today's shift; the old shift keeps its one open `in`; HQ lists it), **8b** (same event on two days: yesterday's clock-in stays open, today's scan clocks in) and **9** (yesterday 22:00 until after midnight → the scan clocks out of the night shift). All passed against the VPS on 29 Oct, with all earlier sections; the test removes its data. Before the migration, a rolled-back dry run showed the old function clocking out of the 14-hour-old shift. |
| N4 | A note in HQ on hours without a clock-out | Uren, as soon as the shift is over and has a clock-in but no clock-out: **"Niet uitgeklokt met NFC — eindtijd door medewerker ingevuld"** once hours are sent (under the line in Per activiteit, on the card in Per medewerker, the tooltip of Tabel → Ingeklokt, and in the hours dialog, where it also counts as the Afwijking). While no hours are sent: **"Niet uitgeklokt met NFC — eindtijd nog niet ingevuld"** on the "Nog ingeklokt" row and on the "Gepland" card. Without a tag (the clock button) it says "Niet uitgeklokt — …". The suggested clock-out (Nog ingeklokt → Uitklokken, dialog → Uitklok toevoegen) is the end time the worker sent. `get_open_clock_ins` now also lists a forgotten clock-in that a newer clock-in on the same event follows (it only looked at the last event before). Checked in the browser on test data (removed). |

What the app may want to know: `clock_with_tag`'s answer is unchanged (`kind`, `activity_id`, `activity_name`, `event_at`). After a forgotten clock-out, the old shift has an `in` with no `out` behind it; the app's hours card for that day (end time by the worker) is what HQ now labels.

## ios-needs N6–N8 — built Fri 30 Oct 12:33 (HQ `d13f3df`, migration `20261030120000_rate_limits_clock_swaps_reminder`, live)

The codes are the ones in ios-needs, as `P0001` with the code as `message`. No other app change.

| # | Need | What HQ changed |
|---|---|---|
| N6 | Limit `clock_with_tag` | Per account: at most **30 calls an hour** (every call counts, refused ones too), and after **10 `invalid_tag` in a row** a **15-minute pause**. During the pause every scan waits, also with a known tag. After it, one try per 15 minutes until a scan with a known tag (any answer other than `invalid_tag`) ends the streak. Refused with **`too_many_attempts`** (hint "Too many scans in a short time. Try again in a few minutes."). The calls are logged in `clock_tag_attempts` (no client access; rows older than a day go). So that a refused scan is still logged, `invalid_tag`, `not_linked` and `no_shift_here_today` now come back through PostgREST's `response.status`: **HTTP 400 with the same body as before** (`{ code: "P0001", message, details: null, hint }`), so the app reads them as it does now. A successful scan answers as before |
| N7 | Limit the swap requests | `request_shift_swap`, `request_shift_takeover` and `request_open_shift`: at most **20 new requests per day (Europe/Amsterdam) per account**, counted together from the requests that account made, whatever became of them (withdrawn, declined, approved). The 21st: **`too_many_requests`**, checked before anything else. `respond_shift_swap` and `withdraw_shift_swap` are not limited. HQ's web screens show the same Dutch text as the app |
| N8 | Herinnering sturen | HQ → Aanwezigheid → Tools → **Herinnering sturen (week N)** first asks **"Herinnering sturen naar N medewerkers?"** (N = linked workers who gave nothing for that week; nobody → "Iedereen heeft al iets opgegeven", nothing sent), Annuleren / Sturen. **Once per 7 days per employer**: the tool then reads "Verstuurd do 29 okt. 14:05 · weer vanaf do 5 nov. 14:05" and is greyed out; the server refuses a second one with `reminder_already_sent`. A reminder that reached nobody does not count. Nothing changes for the worker: the same `availability_reminder` inbox message |
| Tests | N6, N7 (and N8) | `tests/rostering/rate-limits.ts` (HQ repo), 28 checks, all passed on the VPS with two throwaway accounts (nobody real got a message; the test company's limits untouched). `tests/rostering/clock-tags.ts` still passes and now removes the scan log it makes as Sanne, so a run never uses up her 30 scans |

For tonight (C6): the night shift uses the new `clock_with_tag`; normal scans behave as before, and Sanne's scan log is empty.

## ios-needs N9 — made Thu 5 Nov 17:19

No app change, no message to the worker.

| # | Need | What HQ made |
|---|---|---|
| N9 | Overnight shift for Sanne on Testtruck, Thu 5 Nov 14:00 → Fri 6 Nov 08:00 | **[iOS test] Klok: overnacht** `2d40cd6b-0dfb-43f2-a00c-dabe15323e46` (new), on **Testtruck**, Sanne only: per-day roster **`2026-11-05` 14:00–08:00** (one day; an end before the start ends the next day). Published: written in the activity's own roster columns as Publiceren does, no concept, `is_draft` false, status `option` like the other `[iOS test]` events. Made as quietly as a publish: no "Je staat op een nieuw evenement" message (Sanne's inbox 0 before and after). The server's planned window for a clock-in today is **Thu 05-11 14:00 → Fri 06-11 08:00**, so a scan **until Fri 12:00** (planned end + 4 h) clocks out on this shift, and the shift's date stays Thu 5 Nov |
| Checks | Nothing else on Testtruck, row, tag, scan count | No other Testtruck event in Testbedrijf from Wed 4 to Fri 6 Nov at all, so nothing from Thu 12:00 to Fri 14:00. Her shifts around it have no truck: Besloten bedrijfsfeest Wed 4 Nov 18:00–23:00, Bedrijfsevent Fri 6 Nov 16:00–21:00. Row `909021d9` `approved`, active, linked. Testtruck's tag is the same active one since 17 Oct (the user has the link). Scan count (N6) empty: one old row (`no_shift_here_today`, 2 Nov) removed. As Sanne: her feed has the shift today, and a scan with the Testtruck tag in a transaction that was rolled back answered `in` on this shift, a second one `out` on it (nothing kept) |

The C6 night shift `077a6208` still has its clock-in of Fri 30 Oct 17:51 without a clock-out. It is past its window
(31 Oct 06:00), so it does not catch these scans; HQ shows it as not clocked out.

## ios-needs N10–N11 — built Fri 6 Nov 12:49 (HQ `cd8decc`, migration `20261106140000_employer_clock_alerts`, live)

No app change. Only the employer side is told, once per shift and case; the worker gets nothing.

| # | Need | What HQ changed |
|---|---|---|
| N10 | Not clocked out with the NFC tag | A clock-in with **no clock-out by its planned end + 4 h** (no planned times: 18 h after the clock-in, the same window as `clock_with_tag`) gives **one** notification: **"Sanne Tester is niet uitgeklokt met NFC"** · "[event], do 5 nov (gepland tot 08:00)" ("… is niet uitgeklokt" when the clock-in was not by tag). A server job looks every 10 minutes; it only announces windows that closed in the last day, so old forgotten clock-ins were not announced at go-live. In HQ it shows in **Uren → Meldingen** (new strip above "Nog ingeklokt"): "Bekijk week" opens Uren at that week, "Gelezen" takes it off. In with the tag and out with the **button** (not an HQ correction): the Uren line says **"Uitgeklokt met de knop"** (Per activiteit, Per medewerker, Tabel → Ingeklokt, and the hours dialog under "Geklokt (app)") |
| N11 | Hours far from the planned shift | When the worker **sends hours** or **clocks out** (tag or button), and the **worked time, or the start, or the end** is N hours or more off the planned shift: **one** notification, e.g. **"Sanne Tester: 18 u 32 min gewerkt, gepland 18 u (do 5 nov, [event])"** · **"3 u 55 min later uitgeklokt"**. The text after the dot names the largest difference: "… later / eerder uitgeklokt", "… later / eerder ingeklokt", "einde / begin … dan gepland" for times the worker typed, or "… langer / korter dan gepland" when only the length is off. **The start and end count too, not only the length**: in the example the length is only 32 min off, but the clock-out is 3 h 55 min late. Worked = the sent hours when there are any, else clock-out − clock-in − breaks; start and end = the clock times when both exist, else the sent times. The Uren line gets **"Wijkt 3+ uur af van het rooster"** (status Afwijking). **Setting per employer:** HQ → Stakeholders → Instellingen → Inklokken → "Melding bij afwijking van het rooster vanaf 1 uur / 2 / 3 / 4 / 6" (`roster_settings.off_roster_alert_hours`, 1–12, default 3). Hours a planner adds in HQ do not alert |
| Who | Employer only | The event's owner, the organisation's owner and members who may edit its employees: in HQ (`operator_notifications`, Uren → Meldingen) and in the app's Berichten (`worker_notifications`, two new types, see SchemaContract "Employer clock alerts"). Once per shift and case (`clock_alerts`) |
| Tests | N10, N11 | `tests/rostering/clock-alerts.ts` (HQ repo): 15 checks, all passed on the VPS with throwaway accounts: the example's exact text, sent hours, once only, a 5-hour setting stays quiet, N10 once, the worker gets nothing and cannot read the alerts, the employer can. `tests/unit/roster-gap.spec.ts` for Uren's flag. Checked in the browser as the test operator on a seeded line (removed afterwards; nothing reached a phone) |

**To see N11 live:** Sanne's overnight shift of Thu 5 Nov ([iOS test] Klok: overnacht) has her tag scans at 17:23 and 11:51 and no hours yet.
When she sends hours for it in the app, ios.operator gets "Sanne Tester: … gewerkt, gepland 18 u (do 5 nov, [iOS test] Klok: overnacht) ·
3 u 51 min later uitgeklokt" in HQ (Uren → Meldingen) and in Berichten. That clock-out happened before go-live, so it gave no alert by itself.

## ios-needs N12–N16 — made Sat 7 Nov 14:44 (data only, no HQ change)

All for **Sanne** (`ios.worker@test.foodrun.nl`, employee `909021d9`) in **Foodrun Testbedrijf**. Seeded directly in the
database as the employer would (no employer clock alerts were made). Her inbox had 0 messages before; now 1 (N14).

| # | Stage | What HQ made |
|---|---|---|
| N12 | Worked, no hours yet | Two new events, published, Sanne only, no truck: **[iOS test] Uren: markt woensdag** `d68eac8a` **Wed 4 Nov 10:00–16:00**, clocked **09:58 → 16:04**; **[iOS test] Uren: ochtend donderdag** `40cea8ed` **Thu 5 Nov 08:00–13:00**, clocked **08:03 → 13:07** (08:00–13:00 instead of 12:00–20:00 so it doesn't overlap her overnight shift from 14:00 that day). No hours rows. Checked as Sanne: both are in her feed, and the app's clock query returns their four clock events |
| N13 | Sent, waiting | **[iOS test] Havenfestival (3 dagen)** **Fri 30 Oct**: hours **pending**, 11:00–19:30, 30 min pauze = **8:00**, note **"Iets later gestopt, kassa telde niet"**, sent 31 Oct 09:12. Clocked 10:57 → 19:34 (so HQ shows planned 11:00–19:00 vs clocked vs sent) |
| N14 | Approved | **October:** 22 Oct Braderie **5:30** (11:00–17:00, 30 min pauze), 23 Oct Kerstmarkt Leiden **7:30** (12:00–20:00, 30 min pauze), 25 Oct Afgelopen markt **8:00** (11:00–19:00) — the two that were still pending from earlier tests (22, 25 Oct) are now approved, dated 2 days after the shift, without a message. **November:** 1 Nov Proeverij (open plek) **5:00** (17:00–22:00), approved 3 Nov, no message; **3 Nov Foodtruck Weekend 9:30** (12:00–22:00, 30 min pauze), sent Fri 6 Nov 21:05 and **approved today 14:44** → her one new message **hours_approved "[iOS test] Foodtruck Weekend — 9.5 hrs"** |
| N15 | Rejected | **[iOS test] Proefdag keuken Mon 26 Oct** (the existing rejected line, 10:00–17:30, her note "Langer gebleven om op te ruimen"): reason now **"Je eindtijd klopt niet met de klok, pas aan"**; clocked 10:01 → 16:02 added so the reason fits. No new message (the rejection itself is from before) |
| N16 | Your own send, live | HQ watches for a new pending line from Sanne and approves it within a few minutes of it arriving; the time goes in `hq-did.md` |

Also under "Wachtend op jou": Sanne's other finished test shifts from 27 Oct – 6 Nov have no hours either (the clock tests,
Stadsfestival, Havenfestival 29 Oct / 1 Nov, nachtdienst, Foodtruck Weekend 2 Nov, Besloten bedrijfsfeest, the overnight
shift of 5 Nov, Bedrijfsevent). The app lists every finished shift without hours, so they show there too; say if HQ should
give them hours to keep the list short.

## Sanne's other finished shifts — approved hours (Sat 7 Nov 15:12, data only, no HQ change)

Asked by the user after N16: give Sanne's other finished test shifts of 27 Oct – 6 Nov approved hours that match their
clock times, so "Wachtend op jou" only keeps what is still being tested; no messages. Written as the planner adds hours
in HQ (approved on insert, approved by ios.operator, dated the morning after the shift): **no worker message** (her inbox
is still at 1, the N14 one), no employer clock alert, `people_log` "added". Rule: **clock-in → clock-out**; no clock-out →
the **planned end**; no clock events → that day's **planned times**.

| Shift | Date | Hours | From |
|---|---|---|---|
| [iOS test] Klok: gisteren, niet uitgeklokt | Tue 27 Oct | **10:04–18:00** (7:56) | clock-in 10:04, no clock-out → planned end |
| [iOS test] Klok: begon 2 uur geleden | Wed 28 Oct | **11:12–17:00** (5:48) | clock-in 11:12, no clock-out → planned end |
| [iOS test] Stadsfestival | Wed 28 Oct | **12:00–22:00** (10:00) | planned (no clock events) |
| [iOS test] Stadsfestival | Thu 29 Oct | **11:14–11:54** (0:40) | the C5 test scans: first in 11:14, last out 11:54 — short on purpose, it is what the clock says |
| [iOS test] Stadsfestival | Fri 30 Oct | **12:00–20:00** (8:00) | planned |
| [iOS test] Havenfestival (3 dagen) | Thu 29 Oct (opbouw) | **19:00–22:00** (3:00) | planned (the opbouw shift of D4) |
| [iOS test] Havenfestival (3 dagen) | Sun 1 Nov | **11:00–19:00** (8:00) | planned |
| [iOS test] Klok: nachtdienst | Fri 30 Oct | **17:51–02:00** (8:09) | tag clock-in 17:51 (C6), no clock-out → planned end 02:00 |
| [iOS test] Foodtruck Weekend | Mon 2 Nov | **12:00–22:00**, 30 min pauze (9:30) | planned, like the approved 3 Nov |
| [iOS test] Besloten bedrijfsfeest | Wed 4 Nov | **18:00–23:00** (5:00) | planned |
| [iOS test] Klok: overnacht | Thu 5 Nov | **17:23–11:51** (18:28) | the tag scans of N9 (17:23 → Fri 11:51) |
| [iOS test] Bedrijfsevent | Fri 6 Nov | **16:00–21:00** (5:00) | planned |

**Still under "Wachtend op jou", on purpose:** N12 **Uren: markt woensdag** (Wed 4 Nov) and **Uren: ochtend donderdag**
(Thu 5 Nov), worked with no hours; N15 **Proefdag keuken** (rejected). N13 **Havenfestival Fri 30 Oct** stays pending
("In behandeling"). Everything else Sanne worked from 22 Oct to 6 Nov is now approved.

**N16:** no new pending line from Sanne has reached the server since Foodtruck Weekend (sent Fri 6 Nov 21:05, approved
Sat 14:44), so nothing was approved from the phone today. The overnight shift of 5 Nov now carries the approved row
above; if the phone still holds an unsent send for it, say so and HQ will sort out the double.
