# iOS → HQ: what the app did (check each in HQ)

Written by the iOS session, **Wed 28 Oct 2026**, Europe/Amsterdam. Account: **Sanne Tester**
(`ios.worker@test.foodrun.nl`), company **Foodrun Testbedrijf**. Mark the last column `seen ok` /
`seen wrong: …` / `not seen`.

| # | Time | What the app did | Event / day | What HQ should show | HQ check |
|---|---|---|---|---|---|
| A1 | 11:12 | **Clock in with the button** (no tag; the simulator has no NFC) — 2 h 12 min after the shift start (C2) | [iOS test] Klok: begon 2 uur geleden, 28 Oct (planned 09:00–17:00) | A clock-in at **11:12**, `source = 'mobile'`, no tag. Planned 09:00 vs clocked 11:12 visible side by side? | |
| A2 | 11:17 | **Setup pin** "TEST setup pin", note "Aspelare hier" (keyboard autocorrect), near Museumplein, by Sanne | [iOS test] Stadsfestival | A crew pin with **section `setup`**, shown in the Setup part of the script editor / portal — **not** among the script's locations | |
| A3 | 11:28 | **Sent hours without any clock event** (C1): 11:00–19:00, 0 min break, note "C1 test: vergten in te klokken" | [iOS test] Afgelopen markt, 25 Oct | Uren: 8,0 u pending, with the note; is it marked that there was **no clock-in**? | |
| A4 | — | Still clocked in since **10:04** (seeded) — nothing sent yet (C3) | [iOS test] Klok: gisteren, niet uitgeklokt, 27 Oct | Does HQ show this as an **open clock-in** / "still clocked in"? | |
| A5 | 11:35 | **Availability week 45**: Wed 4 Nov **not available** 06:00–23:00, reason "Tentamen" (first tried without a reason: the app asked for one); wanted shifts this week 4 | 4 Nov | HQ → Aanwezigheid: 4 Nov red with the reason; week 45 wanted 4 | |
| A6 | 12:34 | Opened HQ's clock messages from the inbox ("Je inklok is aangepast 22-10: 11:00 → 11:05", added / removed clock-out) — each opens the Braderie 22 Oct shift and shows old → new time | Braderie, 22 Oct | — (C7 / C8 seen in the app) | |

More lines follow as the audit goes on.
