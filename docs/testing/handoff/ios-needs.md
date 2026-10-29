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

