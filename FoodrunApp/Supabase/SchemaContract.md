# Schema contract — Foodrun iOS ↔ Foodrun HQ

The iOS worker app, the web worker portal (`/me/*`) and the HQ operator dashboard
all read and write the same tables on the self-hosted Supabase
(`https://supabase.foodrun.nl`). They are three faces of one employment app:
the operator plans and approves in HQ, the worker sees and submits on the phone.

**Last audited:** 2026-09-28 against `src/integrations/supabase/types.ts` and
`supabase/migrations/*` in the HQ repo. Codable shapes: `SharedSchema.swift`.
All calls: `WorkerAPI.swift`.

## The loop

| Step | Who | Where | Table / RPC |
|---|---|---|---|
| 1. Roster a shift | Operator | HQ → Stakeholders → Rooster, or iOS Roster "+" (org owners only) | `activities.daily_employees[day]` + `daily_employee_times[day][employee]` |
| 2. See the shift | Worker | iOS Shifts (hero + Still to work), `/me` | RPC `get_my_worker_activities` — only rostered or "Visible to workers" activities, schedule fields only, "Hide name from workers" honoured |
| 3. Say when you can work | Worker | iOS Availability → Save week | `employee_availability` (upsert on `employee_id,date`, fanned out to every linked employee row) |
| 4. Clock in / out | Worker | iOS NFC tag or tap, `/me/clock` | RPC `clock_in` / `clock_out` → `shift_clock_events` (server `event_at`, `source='mobile'`) |
| 5. Submit hours | Worker | iOS Hours → Waiting for you, `/me/hours` | `employee_hours` upsert on `employee_id,activity_id,work_date`, `status='pending'` |
| 6. Approve / reject | Operator | HQ → Stakeholders → **Uren** | `employee_hours.status / approved_by / approved_at / rejected_reason` |
| 7. Hear back | Worker | iOS Inbox + Hours status, `/me/inbox` | trigger `notify_worker_on_hours_decision()` → `worker_notifications` |

### Account first, employer second

A worker can make an account in the app before any employer has added them.
`ScheduleStore.isUnlinked` (no approved `employees` row, not an operator) → AppShell
shows `NotLinkedView` (their email + Share + "Check again"). The employer adds that
email in HQ → Stakeholders → Add employee; HQ calls RPC `find_worker_account(p_email)`
(migration `20261007120000`, operator-only, exact match) to show "has a Foodrun
account: <name>", and the `employees` INSERT links it via the auto-link trigger.
"Check again" re-runs `employee-identity-link` + load. Rows still
`approval_status = 'pending'` (web self-signup) show the "waiting for approval" copy.

Account deletion: Profile → Delete account → edge fn `delete-my-account`.

## Table binding

| iOS store | Web hook it mirrors | Table(s) / RPC | Notes |
|---|---|---|---|
| `ScheduleStore` | `useMyHours` / `useMyAvailability` (reads) | `employees` (by `auth_user_id`, approved only), RPC `get_my_worker_activities` + edge fn `employee-identity-link` | Rostered days: `daily_employees`, legacy fallback `employees` (= every day). Window: `daily_employee_times` → `daily_times` → `start_time/end_time`. JSON keys are camelCase (`startTime`). Employee ids in JSON are lower-case. |
| `ScheduleStore` (operator) | `AvailabilityBoard.tsx` (writes) | `organizations.owner_id`, `employees` (by `user_id`), `activities` update | `WorkerAPI.addToRoster` writes `daily_employees`, `employees` (= union of all days), `daily_employee_times`. |
| `AvailabilityStore` | `useMyAvailability().setStatus` | `employee_availability` | Slots are minute ranges (0–1440). `status` nil → delete the day. |
| `ClockStore` | `useShiftClock` | `shift_clock_events`, RPCs `clock_in(p_activity_id, p_lat, p_lng, p_accuracy_m)` / `clock_out(...)` | RPC validates the worker is linked to the activity's operator. Migration `20260908000000`. `source` CHECK allows `mobile / kiosk / manual / pos` — the RPC writes `mobile`. |
| `HoursStore` | `useMyHours().submit` | `employee_hours` | Columns: `work_date`, `hours`, `break_minutes`, `comment`, `status`, `submitted_at`, `approved_by`, `approved_at`, `rejected_reason`. No start/end columns — payable hours only. |
| `InboxStore` | `useWorkerInbox` | `worker_notifications` | Keyed on `user_id` (auth user). Columns: `type`, `title`, `body`, `url`, `is_read`, `operator_name`, `activity_id`. Unknown `type` values decode to `.other`. |
| `EventStore` | — (HQ: Activity → Crew-app) | RPC `get_my_event(p_activity_id)` | One event as this person may see it: `sections` ⊆ briefing / dishes / prep / stock (operator's choice per person, `crew_section_access`; default briefing only) + assigned `crew_tasks` with refs resolved (dish → recipe + ingredients, product → unit chain) and my answers. Prep is read-only. |
| `EventStore` (writes) | — | RPCs `submit_my_task_response(p_task_id, p_work_date, p_done, p_value_number, p_value_text)`, `submit_my_stock_count(p_activity_id, p_count_date, p_product_id, p_quantity, p_unit_level, p_note)` | Answers → `crew_task_responses`, counts → `crew_stock_counts`. Never products / dishes / `activities.stock` / `activity_stock_updates`. Null value + not done = clear. |
| `CrewTasksStore` | — | RPC `get_my_crew_tasks(p_from, p_to)` | Tasks tab: one occurrence per task × rostered day. |
| `TasksStore` | — | *(local only, preview)* | Old sample checklist for the design mirror. Real users get `CrewTasksStore` (`AppConfig.Features.crewTasks`). The kanban `tasks` table stays operator-only. |

Migration `20261008120000_crew_app_event_content.sql` (HQ repo), decision
`wiki/decisions/0031-crew-app-event-content.md`. Error codes the functions raise
(`not_on_crew`, `activity_closed`, `not_rostered_that_day`, `value_required`,
`section_not_enabled`, `negative_count`) map to strings in `CrewAPI.message(for:)`.

## Open items

- **Uren result tiles** — HQ's Uren screen still reads the kanban `tasks`; it
  could show `crew_task_responses` per shift instead.
- **Take a count over into Stock Usage** — an operator action in HQ that turns
  a `crew_stock_counts` row into a stock update (merging into that day's
  snapshot). Deliberately not automatic.
- **Colleagues by name** — `employees` RLS only lets a worker read their own
  row, so iOS shows colleagues as a headcount. A `get_shift_crew(activity, day)`
  RPC returning first names would unlock the named crew list.
- **Clock events tagged by method** — if NFC vs tap needs to be visible in HQ,
  add `'nfc'` to the `source` CHECK and a `p_source` parameter to the RPCs.

## Drift rule

When any app changes a shape: update `SharedSchema.swift`, this file, and the
HQ vault (`wiki/architecture/worker-portal.md`) in the same change.
