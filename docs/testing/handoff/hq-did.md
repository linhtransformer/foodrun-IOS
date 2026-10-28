# HQ → iOS: changes made in HQ that the app should follow

Written by the HQ session. Times are Europe/Amsterdam, test company **Foodrun Testbedrijf**. Check each line in the app and
mark it `seen ok` / `seen wrong: …` / `not seen` in the last column.

| # | When | What HQ did | Where in HQ | What the app should show | iOS check |
|---|---|---|---|---|---|
| D1 | Mon 26 Oct 16:22 | Added **Sanne** to **[iOS test] Markt Haarlem**, **Tue 3 Nov 08:00–15:00**, "Meteen publiceren" | Stakeholders → Rooster → week 45 → + Dienst | The shift under Diensten / Bezetting (with Linh). Inbox: **two** messages arrived for this one action: `hired` "You're on a new festival" and `roster_updated` "Je rooster is bijgewerkt · Week 45: 1 nieuw" (double message, see `mismatches.md` M2) | |
| D2 | Mon 26 Oct 16:23 | Moved **Sanne's Tue 27 Oct** shift on **[iOS test] Stadsfestival** from 10:00–18:00 to **09:00–17:00**, "Opslaan en publiceren" | Rooster → shift card → times | Tomorrow's shift reads 09:00–17:00. One inbox message `roster_updated` "Week 44: 1 gewijzigd" | |
| D3 | Mon 26 Oct 16:23 | Closed **Sat 7 Nov** for availability (5 Nov was already closed) | Stakeholders → Aanwezigheid → week 45 → lock on the day | Beschikbaarheid: 7 Nov can't be changed. That is also the first day of "Open oproep: Zomerfeest" (7–8 Nov), so check what the open call shows on a closed day | |
| D4 | Wed 28 Oct 11:17 | Rostered **Sanne** on **[iOS test] Havenfestival (3 dagen)**'s **opbouw day, Thu 29 Oct 19:00–22:00**, type **Opbouw**, "Meteen publiceren". The opbouw is a day of its own, before the event's days (30 Oct–1 Nov); HQ can plan people on it since today | Rooster → week 44 → Havenfestival row → Thu 29 ("OPBOUW 19:00–22:00") → + Dienst | A shift on Thu 29 Oct 19:00–22:00 under Havenfestival with the type **Opbouw**. One inbox message `roster_updated` "Week 44: 1 nieuw". (NFC clock-in on that day only works after HQ migration `20261028120000`; until then expect `no_shift_here_today` at a tag) | |
