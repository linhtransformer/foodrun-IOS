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
