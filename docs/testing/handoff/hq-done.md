# HQ → iOS: test data created (step 0)

Written by the HQ session on **Mon 26 Oct 2026, 16:10 (Europe/Amsterdam)**. There was no `ios-needs.md` yet, so this
is the standard set from `hq-stakeholders-audit.md`. All times are Europe/Amsterdam.

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
  is on *any* day as on *every* day. Effect: the swap the owner offered Sanne for Havenfestival 29 Oct is on her swap board, but
  she got **no inbox message** for it; and a worker can offer a day of a multi-day event they are not rostered on. Don't log
  these two as app bugs. See `mismatches.md`.
- Setup pins: the server has `submit_my_location_pin(…, p_section text)` live, so D9 can be switched on.

## Items

| # | Item | Created |
|---|---|---|
| 1 | Test worker | **Sanne Tester** `ios.worker@test.foodrun.nl`, employee `909021d9-c2db-4395-8d21-a531da3c33af`, approved, colour `#f0a8c8` |
| 1 | Owner who also works | **ios.operator@test.foodrun.nl** (owner) is also employee **"Eigenaar Test"** `53a72306-6250-441c-8e6b-8ddd20bad52d`: Stadsfestival 27 Oct 10:00–18:00, Havenfestival 29 Oct 11:00–19:00. Linh Tran (`lit.linhtran`, employee `b0c9b6a4-f4f7-4824-9fca-5714915897ef`) is an employee, **not** the owner (see above) |
| 1 | Worker not approved yet | **Piet Wachter** `ios.pending@test.foodrun.nl` asked to join through `worker-self-signup`; employee `d96899fe-7d35-47cf-b58d-b86a3fcf5e17`, status `pending`, under Aanmeldingen. Same password as the other test accounts |
| 2 | Shift today on a truck with an NFC tag | **[iOS test] Stadsfestival** `69456028-9c60-44c9-90b2-aebd467efb89`, 26–28 Oct, truck **Testtruck** (active tag kept, so a sticker that already has the link still works). Sanne 10:00–18:00 every day |
| 2 | Tomorrow | Stadsfestival, 27 Oct |
| 2 | 3 days ago | **[iOS test] Afgelopen markt** `4c209bda-03b3-418b-b400-f9b2ffc09a18`, 23 Oct 11:00–19:00: no hours sent, no clock events (also C1) |
| 2 | Multi-day, on 2 of its days | **[iOS test] Havenfestival (3 dagen)** `ed927183-6ab3-47f4-a4be-f76bead695e5`, 28–30 Oct 11:00–19:00. Sanne on **28 and 30 Oct**, not 29 (owner + Linh on 29) |
| 2 | "Hide name from workers" | **[iOS test] Besloten bedrijfsfeest** `0598c5e7-b954-4938-9c8e-87a17712be0b`, 2 Nov 18:00–23:00. Sanne should see **"Festival"** (the worker feed already returns "Festival") |
| 2 | Break, note, shift type, checklist | **[iOS test] Foodtruck Weekend** `eb4d5986-e05f-486d-9cee-90fc11a438d2`, Sanne on **31 Oct** 12:00–22:00: 30 min break, note "Jij doet vandaag de kassa en sluit af.", type **Opbouw**, checklist **Afsluiten** (vestiging Testkeuken Centrum, so the "Centrum" briefing shows too) |
| 2 | Open for availability, not rostered | **[iOS test] Open oproep: Zomerfeest** `9108adc9-4eda-4025-8d77-1933fb7b8b2c`, 7–8 Nov |
| 3 | Draaiboek on today's event | Stadsfestival: day note on 26 Oct; menu **Pho Bo** (recipe, photo, allergens Gluten / Soy / Celery, may contain pinda's); event comments; **2 locations** with coordinates (crew-ingang + Crewparkeerplaats Museumgarage); sections **"TEST Opmaak"** (`**vet**`, `*schuin*`, a `[link](…)` and a bare URL), **"TEST Foto's"** (2 pictures, landscape + portrait), **"TEST Bijlage (alleen Sanne)"** (PDF, visible to Sanne only), plus Aankomst (photo), Kleding, Huisregels (PDF); 2 links; event file (plattegrond); Sanne's ticket + a ticket without a name; team (Sanne, Linh, owner on 27 Oct); build-up 25 Oct 14:00–18:00 (photo), power plan (32 A, 2 outlets), teardown 28 Oct 20:30–23:00 |
| 4 | Crew-app access | Stadsfestival: briefing, dishes, prep, stock on for everyone (Sanne included) |
| 5 | Tasks on today's shift | Stadsfestival: `count` Tel de havermelk, `check` Mise-en-place Pho Bo, `number` Temperatuur koelkast, `check` Truck schoon opleveren (Sanne, 26 Oct), `text` Wat viel je op vandaag? (26 Oct), `photo` Foto van de opstelling; library list **Opbouw truck** on the event; week goals **Weekdoelen keuken** for this week |
| 6 | Hours | **waiting**: Afgelopen markt 23 Oct · **pending**: [iOS test] Braderie 20 Oct, 11:00–17:00, 30 min, note "Pauze om 14:00 genomen" (`029602de-10d4-474c-b111-637af4d5db79`) · **approved**: [iOS test] Kerstmarkt Leiden 21 Oct, 12:00–20:00 (`c75f1413-9628-42aa-8231-60c8e6a3c0b9`) · **rejected** with reason "Je eindtijd klopt niet met het rooster (16:00). Pas aan en stuur opnieuw.": [iOS test] Proefdag keuken 24 Oct, 10:00–17:30 (`313028d6-f9b7-41e0-b29c-d655ddaab64e`) |
| 7 | Availability rules | closed day **Thu 5 Nov**; deadline Wednesday 18:00, one week before (for the week of 2 Nov: Wed 28 Oct 18:00, still to come); reason required **on** |
| 8 | Same shift | Sanne + Linh on Stadsfestival 26–28 Oct (owner too on 27 Oct) |
| 8 | Open place | **[iOS test] Avondmarkt (open plek)** `06b5b56f-83c0-4312-ad3c-24d5db1e3b21`, Sun 1 Nov 17:00–22:00, 2 needed, Linh on it; the team was asked (Sanne got "Open dienst: wil jij?"). [iOS test] Proeverij (open plek) 30 Oct also has an open place, but Sanne is already on it |
| 8 | Swap offered to Sanne | by the owner ("Eigenaar Test"): Havenfestival **29 Oct**, note "Kun jij mijn dienst overnemen? Ik moet naar de accountant." (`60bac2b6-7a33-4bf3-b75b-2a05107dcc20`). On Sanne's board; **no inbox message** (server bug above). Also from the base seed: Sanne offers her Bedrijfsevent 4 Nov to Linh |
| 8 | Leave | Sanne: **pending** 15–16 Nov "Bruiloft van mijn zus" (`d7cc514f-9e71-42e9-bc62-e098a5c944fd`), **approved** 29 Nov–1 Dec "Weekendje weg", note "Veel plezier!" (`24e6b9ca-9e67-459a-8909-7f0808228f1e`) |
| 9 | Join code | Foodrun Testbedrijf has one (the user has it) |
| 9 | Email invite to a fresh address | `ios.invite@test.foodrun.nl` (no account), placeholder employee "Invite Tester" `27823f76-b7f1-41e3-a3b9-b97d2d32c6d8`, valid 7 days. Made through the same server function as HQ's Uitnodigen but without sending the mail (test.foodrun.nl has no mailbox). The user has the link |
| 9 | Second test organisation | **Foodrun Testbedrijf 2** `47acd48c-a61b-4ea1-b686-91532d5f2fe3`, owner `ios.operator2@test.foodrun.nl`. Sanne is not in it, so its join code (the user has it) can be tried with her |
| 10 | Former employer | **Foodrun Oud-werkgever (test)** `8ff16d48-63e0-44bb-acd9-2e5705a7f97e`, owner `ios.former@test.foodrun.nl`: Sanne's row `843d50a3-a80e-4360-800a-f6bab4191c19` is **uit dienst**, with 2 past shifts (6 Oct, 13 Oct) and approved hours. Note: the worker feed still returns those two events |
| 10 | Uit dienst in the company | **Bram Oudgediende** `73443043-f16b-42d7-baff-87b59e96fbfc` (no account): worked Braderie 20 Oct (approved hours) and Afgelopen markt 23 Oct; his Havenfestival 30 Oct shift was cleared by Uit dienst. For HQ history |
| 11 | Started 2 hours ago | **[iOS test] Klok: begon 2 uur geleden** `5b9d060d-83f1-4b49-93d3-c73f3e112233`, 26 Oct **13:45–21:45**, no truck (clock with the button). Fixed times: when you test later than about 18:00 today, re-seed so it moves |
| 11 | Ended yesterday | **[iOS test] Klok: gisteren, niet uitgeklokt** `e03ae1ba-997b-44fb-9804-98913bfb8284`, 25 Oct 10:00–18:00, with a **clock-in at 10:04 and no clock-out** (seeded, `source = 'mobile'`) |
| 11 | Tonight 22:00–02:00 | **[iOS test] Klok: nachtdienst** `3cbbc5f8-423d-4ea8-8d69-b628421393fe`, 26 Oct 22:00–02:00 on **Testtruck**. At the Testtruck tag the shift with the nearest start wins, unless Sanne is still clocked in on Stadsfestival (then the scan clocks her out there) |
| 11 | Second truck with its own tag | **Testtruck 2** (truck of the company, own active tag; the user has the link). Sanne has no shift on it. Testtruck is now a truck of the company too, so HQ shows its tag |

Today Sanne has three shifts (Stadsfestival, "begon 2 uur geleden", nachtdienst). That is on purpose for the clock scenarios;
it also tests what the home card does with more than one shift on a day.
