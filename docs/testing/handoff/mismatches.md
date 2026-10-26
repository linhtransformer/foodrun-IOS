# Mismatches between the app and HQ / the server

One row per disagreement. "Fix on" = the side that should change.

| # | Found by | What | Fix on | Status |
|---|---|---|---|---|
| M1 | HQ, 26 Oct | `crew_member_days` (used by `request_shift_swap`, its inbox message and the swap board) counts a worker on **every** day of a multi-day event as soon as they are on **one** day, because HQ also keeps the flat `activities.employees` list as the union of all days. Seen: the owner offered Sanne Havenfestival 29 Oct (she is on 28 and 30), the swap is on her board, but no `swap_offered` message reached her. A worker can also offer a day of a multi-day event they are not on. | HQ (migration: use the flat list only when the event has no per-day roster, the rule `clock_with_tag` and HQ's `rosterState` already follow). Dry run: Sanne's accept of the 29 Oct swap fails with `already_on_shift` today and is accepted after the fix | open — migration waits for the owner's go-ahead |
| M2 | HQ, 26 Oct | Publishing a new person from the Rooster sends **two** messages: `hired` ("You're on a new festival", English, from the trigger on `activities.employees`) and `roster_updated` ("Je rooster is bijgewerkt · Week 45: 1 nieuw"). Seen with D1. | HQ (one message per publish, G5 in the results) | open |
| M3 | HQ, 26 Oct | Open shifts made on HQ's Planning board are stored in `activities.open_shifts`; the app (and HQ's Rooster) only read `daily_required_headcount`, so workers never see those. Not in use right now (0 events in the last 60 days). | HQ (G6) | open |
| M4 | HQ, 26 Oct | A hidden event's name reads "A festival" in `hired` / `removed` messages but "Festival" everywhere else. | HQ | open |
