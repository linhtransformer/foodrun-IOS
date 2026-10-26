# Mismatches between the app and HQ / the server

One row per disagreement. "Fix on" = the side that should change.

| # | Found by | What | Fix on | Status |
|---|---|---|---|---|
| M1 | HQ, 26 Oct | `crew_member_days` (used by `request_shift_swap`, its inbox message and the swap board) counts a worker on **every** day of a multi-day event as soon as they are on **one** day, because HQ also keeps the flat `activities.employees` list as the union of all days. Seen: the owner offered Sanne Havenfestival 29 Oct (she is on 28 and 30), the swap is on her board, but no `swap_offered` message reached her. A worker can also offer a day of a multi-day event they are not on. | HQ (migration: use the flat list only when the event has no per-day roster, the rule `clock_with_tag` and HQ's `rosterState` already follow) | open — migration waits for the owner's go-ahead |
