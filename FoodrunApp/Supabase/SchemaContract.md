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
| 3b. Say how many shifts you want | Worker | iOS Availability → "Shifts I want this week" | `employee_week_preferences` (upsert on `employee_id,week_start`, one row per linked employee row). HQ shows it on the planning board as planned / wanted. |
| 4. Clock in / out | Worker | iOS NFC tag (`clock_with_tag(p_token)`) or the button (`clock_in` / `clock_out`, when `get_my_clock_rules` allows it), `/me/clock` | → `shift_clock_events` (server `event_at`, `source='mobile'`, `tag_id` for a tag) |
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

The other way round — the worker asks, the employer approves — goes through the
employer's **join code**: RPC `find_organization_by_join_code(p_code)` → edge fn
`worker-self-signup` → the request waits in HQ under Aanmeldingen. RPC
`get_my_organizations()` lists where the account works or waits. There is no list of
organisations any more. See "Join with the employer's code" below.

Account deletion: Profile → Delete account → edge fn `delete-my-account`.

## Table binding

| iOS store | Web hook it mirrors | Table(s) / RPC | Notes |
|---|---|---|---|
| `ScheduleStore` | `useMyHours` / `useMyAvailability` (reads) | `employees` (by `auth_user_id`, approved only), RPC `get_my_worker_activities` + edge fn `employee-identity-link` | Rostered days: `daily_employees`, legacy fallback `employees` (= every day). Window: `daily_employee_times` → `daily_times` → `start_time/end_time`. JSON keys are camelCase (`startTime`). Employee ids in JSON are lower-case. |
| `ScheduleStore` (operator) | `AvailabilityBoard.tsx` (writes) | `organizations.owner_id`, `employees` (by `user_id`), `activities` update | `WorkerAPI.addToRoster` writes `daily_employees`, `employees` (= union of all days), `daily_employee_times`. |
| `AvailabilityStore` | `useMyAvailability().setStatus` | `employee_availability` | Slots are minute ranges (0–1440). `status` nil → delete the day. |
| `AvailabilityStore` (wanted shifts) | `useWeekPreferences` (HQ reads) | `employee_week_preferences` | Columns: `employee_id` uuid, `week_start` date, `wanted_shifts` int, `updated_at` timestamptz. Primary key `(employee_id, week_start)`. `week_start` **must be the Monday** of the week (ISO week, Europe/Amsterdam, `yyyy-MM-dd` — same as `CrewTasksStore.weekStart(of:)`); any other day is refused. `wanted_shifts` 0…7; **no row = not answered**, which is not the same as 0. `updated_at` is stamped by the server on every write — whatever the client sends is ignored. The worker may select / insert / update / delete rows of their own employee ids (`employees.auth_user_id` = the login); the employer and its organisation can only read. There is no column for "standard shifts per week" (`standardShifts`) — that one is still local. |
| `ClockStore` | `useShiftClock` | `shift_clock_events`, RPCs `clock_in(p_activity_id, p_lat, p_lng, p_accuracy_m)` / `clock_out(...)` | RPC validates the worker is linked to the activity's operator. Migration `20260908000000`. `source` CHECK allows `mobile / kiosk / manual / pos` — the RPC writes `mobile`. |
| `HoursStore` | `useMyHours().submit` | `employee_hours` | Columns: `work_date`, `hours`, `break_minutes`, `comment`, `status`, `submitted_at`, `approved_by`, `approved_at`, `rejected_reason`. No start/end columns — payable hours only. |
| `InboxStore` | `useWorkerInbox` | `worker_notifications` | Keyed on `user_id` (auth user). Columns: `type`, `title`, `body`, `url`, `is_read`, `operator_name`, `activity_id`. Unknown `type` values decode to `.other`. |
| `EventStore` | — (HQ: Activity → Crew-app) | RPC `get_my_event(p_activity_id)` | One event as this person may see it: `sections` ⊆ briefing / dishes / prep / stock (operator's choice per person, `crew_section_access`; default briefing only) + assigned `crew_tasks` with refs resolved (dish → recipe + ingredients, product → unit chain) and my answers. Prep is read-only. |
| `EventStore` (writes) | — | RPCs `submit_my_task_response(p_task_id, p_work_date, p_done, p_value_number, p_value_text, p_photo_path)`, `submit_my_stock_count(p_activity_id, p_count_date, p_product_id, p_quantity, p_unit_level, p_note)` | Answers → `crew_task_responses`, counts → `crew_stock_counts`. Never products / dishes / `activities.stock` / `activity_stock_updates`. Null value + not done = clear. |
| `EventStore` (prep) | prep portal (`ActivityPortal`) | RPC `set_my_prep_item(p_activity_id, p_key, p_checked, p_comment)` → `activity_prep_checklist_states.checked_items` / `item_comments` | **Editable** (migration `20261008130000`). Same keys as the portal (`ing-/equip-/addon-/trailer-<id>`); both sides merge per key, so ticks from the app and the portal don't wipe each other. List = planned stock + dish ingredients/equipment + category equipment + trailers (`crew_prep_items`). |
| `EventStore` / `CrewTasksStore` (photo) | — | Storage bucket `crew-task-photos` (private), path `<activity>/<task>/<employee>/<ms>.jpg` (lower-case UUIDs), then `submit_my_task_response(..., p_photo_path)` | Upload allowed only for an assigned photo task of the caller; operators read via signed URL. `NSCameraUsageDescription` in `project.yml`. |
| `InboxStore` (task) | — | `worker_notifications.type = task_assigned` | Trigger `crew_notify_task_assigned` on `crew_tasks` insert. Tap → Tasks tab. |
| `CrewTasksStore` | — | RPC `get_my_crew_tasks(p_from, p_to)` | Tasks tab: one occurrence per task × rostered day. |
| `TasksStore` | — | *(local only, preview)* | Old sample checklist for the design mirror. Real users get `CrewTasksStore` (`AppConfig.Features.crewTasks`). The kanban `tasks` table stays operator-only. |

Migration `20261008120000_crew_app_event_content.sql` (HQ repo), decision
`wiki/decisions/0031-crew-app-event-content.md`. Error codes the functions raise
(`not_on_crew`, `activity_closed`, `not_rostered_that_day`, `value_required`,
`section_not_enabled`, `negative_count`) map to strings in `CrewAPI.message(for:)`.

### Wanted shifts and what a worker may change on `employees` (2026-10-13)

Migrations `20261013100000_employee_week_preferences.sql` and
`20261013110000_employees_worker_update_guard.sql` (HQ repo), decisions
`wiki/decisions/0061` and `0062`.

Write, per linked employee id (fan out like `setAvailability`):

```swift
struct DBWeekPreferenceUpsert: Encodable { let employee_id: UUID; let week_start: String; let wanted_shifts: Int }
try await client.from("employee_week_preferences")
    .upsert(rows, onConflict: "employee_id,week_start").execute()
```

Read: `.select("employee_id, week_start, wanted_shifts, updated_at").in("employee_id", values: ids).eq("week_start", value: monday)`.
Errors: a non-Monday or a value outside 0…7 → Postgres `23514` (check violation);
somebody else's employee id → `42501` (row-level security).

**A direct update of `employees` by the worker is now limited** to: `name`,
`last_name`, `date_of_birth`, `phone`, `city`, `place_of_origin`,
`drivers_license`, `car_capacity`, `privacy_consent_at`, `onboarded_at`, and
`approval_status` → `'disconnected'` only. Any other column in the same update
fails with `42501` and the message `employees_protected_field` (pay, roles,
approval, e-mail, employer). The iOS app does not update `employees` today, so
nothing changes for it; keep it in mind for a profile editor.

### Consent for AI roster suggestions (2026-10-13 — server ready, not in the app yet)

Migration `20261013120000_ai_roster_suggestions.sql`, edge function `suggest-roster`
(HQ repo), decision `wiki/decisions/0063`. HQ can propose who takes a week's open
shifts; a worker is only considered when they agreed in the app. **Not part of the
first App Store submission** — until the app has this switch nobody can be suggested.

- State: `employees.ai_roster_consent_at` (timestamptz, null = not included), one per
  employer link. Read it with the employee rows the app already loads (add the column
  to the select).
- Set it only through the RPC — a direct update of the column is refused:

```swift
struct ConsentParams: Encodable { let p_consent: Bool; let p_employee_id: UUID? }
struct ConsentRow: Decodable { let employee_id: UUID; let ai_roster_consent_at: Date? }
let rows: [ConsentRow] = try await client
    .rpc("set_my_ai_roster_consent", params: ConsentParams(p_consent: true, p_employee_id: nil))
    .execute().value
```

  `p_employee_id` nil = every employer this login is linked to; an id = that one
  only. Yes keeps an earlier timestamp, no clears it. Returns the rows it touched
  (empty when the login has no employee row).
- What to tell the worker before they agree (also in `foodrun.nl/legal/privacy` →
  "Automated roster suggestions (AI)"): availability, wanted shifts, roles, planned
  shifts and approved hours of the last 8 weeks are used; Claude by Anthropic sees
  codes, never names or contact details; a manager always decides and publishes; they
  can switch it off at any time.
- The app does nothing else: a published proposal is an ordinary roster entry
  (`get_my_worker_activities` + the "hired" notification).

### NFC clock tags with a secret (2026-10-13 — server live)

Migrations `20261013140000_clock_tags.sql` + `20261013150000_clock_button_per_employee.sql`
(HQ repo, `4f41fde`), decision `wiki/decisions/0064-nfc-clock-tags-with-a-secret`.

**The tag** holds `https://foodrun.nl/clock/<token>` (one URI record). The token is
32 URL-safe characters (`[A-Za-z0-9_-]`), made in HQ per truck and per vestiging; the
old `/clock/<truck name>` links are gone. The app does not interpret the token: take
the last path component and send it.

**Universal link.** `https://foodrun.nl/.well-known/apple-app-site-association` is
live as `application/json` (also on Apple's CDN):
`applinks.details[0] = { appIDs: ["GWU44KGDJZ.nl.foodrun.app"], components: [{ "/": "/clock/*" }] }`.
App side: Associated Domains `applinks:foodrun.nl`, handle
`.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` (background tag read) next to
the foreground `NFCNDEFReaderSession`. The web page for phones without the app links to
`foodrun://clock/<token>` — handle that in `.onOpenURL` the same way.
`NFCTagAction.parse` should accept `/clock/<token>` on `foodrun.nl` and
`foodrun://clock/<token>`.

**Clock with a tag** — one call, the server decides in or out:

```swift
struct ClockWithTagParams: Encodable { let p_token: String }
struct ClockWithTagResult: Decodable {
    let kind: String          // "in" | "out"
    let activity_id: UUID
    let activity_name: String // "Festival" when the employer hides event names
    let event_at: Date        // server time
}
let result: ClockWithTagResult = try await client
    .rpc("clock_with_tag", params: ClockWithTagParams(p_token: token))
    .execute().value
```

The server finds the caller's shift **today (Europe/Amsterdam) at that truck or
vestiging**: a shift they are still clocked in on (latest event `in` / `break_end`,
younger than 18 hours — covers a night shift) is clocked **out**; otherwise the shift
they are rostered on today is clocked **in**. The app no longer chooses the activity or
the direction for a tag, and `ClockStore.activityId` is not needed for it. The event
is written with `source = 'mobile'` and the tag.

Errors (PostgREST `code` = `P0001`, read `message`):

| `message` | Meaning | Say |
|---|---|---|
| `invalid_tag` | unknown token, or a tag that was replaced | "This tag is no longer in use. Ask your manager." |
| `not_linked` | no approved employee row at that employer | "You are not (yet) approved at this employer." |
| `no_shift_here_today` | not rostered today at that truck / location, and not clocked in there | "You have no shift at this truck or location today." |
| `not_authenticated` (`42501`) | no session | sign in first |

**The button (clock without a tag).** An employer can switch it off for the whole
organisation, and per person either way. `clock_in` / `clock_out` (unchanged
signatures) then fail with `P0001` `tag_required`. Ask before showing the button:

```swift
struct ClockRulesParams: Encodable { let p_activity_ids: [UUID] }
struct ClockRule: Decodable { let activity_id: UUID; let clock_without_tag: Bool }
let rules: [ClockRule] = try await client
    .rpc("get_my_clock_rules", params: ClockRulesParams(p_activity_ids: ids))
    .execute().value
```

One row per activity the caller is approved at (others are left out);
`clock_without_tag == false` → hide the "Clock in" / "Clock out" button on that shift
and show the NFC strip only. The default is `true`, and it stays `true` for the
"[iOS test]" company, so App Review can clock with the button. Still handle
`tag_required`: the setting can change while the app is open.

Also changed: `clock_in` / `clock_out` now require an **approved** employee row
(`clock_in: caller is not linked to this activity` otherwise), and
`shift_clock_events` has a new nullable column `tag_id` (ignore it; a worker cannot
set it).

### Join with the employer's code, my organisations, Password AutoFill, a colour per employee (2026-10-15 — server live)

Migrations `20261013180000_organization_join_codes.sql`,
`20261013190000_employee_colors.sql`, `20261013200000_list_public_organizations_closed.sql`,
`20261015100000_my_organizations_per_employee_row.sql` (HQ repo, `c39759c + 8bbbd92`), decisions
`wiki/decisions/0073-join-an-employer-with-a-code` and `0074-a-colour-per-employee`.

**1. Join code.** Every organisation has one code, shaped `FR-7K2M9Q` ("FR-" + 6
characters from `23456789ABCDEFGHJKMNPQRSTUVWXYZ` — no 0 O 1 I L). The employer finds
it in HQ → Stakeholders → Medewerkers → **Koppelcode** (copy, "Nieuwe code"). A new
code makes the old one unknown at once; people who already joined keep their place.

```swift
let rows: [PublicOrganization] = try await client
    .rpc("find_organization_by_join_code", params: ["p_code": code])
    .execute().value          // [] = unknown code; at most one row: id, name
```

- Signed-in callers only (`42501` without a session).
- Send what the user typed: the server ignores case, spaces and the dash, and accepts
  the six characters without "FR".
- Unknown code → **no rows, no error**. Say "We don't know this code. Check it or ask
  your employer for the join code in Foodrun."
- Rate limit per account: 10 tries at once, then one more every five minutes. Over it:
  PostgREST `code` = `P0001`, `message` = `too_many_attempts` → "Too many tries. Try
  again in a few minutes." Text that cannot be a code is answered with no rows and does
  not count.
- Call it with POST (the default of `.rpc`): it writes the rate-limit counter, so a GET
  (`get: true`) fails with HTTP 405, `25006`.
- Then join as before: `worker-self-signup` with `organization_ids: [row.id]` (same
  body, replies and error codes). A new employer gets a new `pending` row; rows the
  account has at other employers are not touched, and a row it already has at this
  employer that is `approved` or `pending` stays exactly as it is (the reply lists it
  under `approved_organization_names` / `pending_organization_names`).
- The employer sees the request in HQ (Stakeholders → Medewerkers → Aanmeldingen) with
  only what the worker sent that employer; other employers are neither shown nor
  readable.

`list_public_organizations` is **closed**: anon and signed-in callers get `42501`
"permission denied for function". Builds 1 and 2 used it for the employer picker; that
step fails there now, everything else in them works.

**2. My organisations.**

```swift
let mine: [MyOrganization] = try await client.rpc("get_my_organizations").execute().value
// organization_id: UUID, name: String, approval_status: String, employee_id: UUID
```

**One row per `employees` row** of the signed-in account (`auth_user_id`): pending,
declined and disconnected included, sorted by name, never anybody else's.
`employee_id` is that row's id (as `DBEmployee.id` and `get_my_event(...).employee_id`),
so a shift can be labelled with its employer. `approval_status` is `approved` |
`pending` | `declined` | `disconnected` (never null). An `employees` row belongs to an
operator, not to an organisation; the organisation shown is that operator's primary
one (the oldest they own). Use it to show "your employers" and to skip a code whose
organisation is already `approved` or `pending`. Signed-in callers only.
`MyOrganization` needs `employee_id: UUID`; use `employee_id` as its `id`.

**3. Password AutoFill.** `https://foodrun.nl/.well-known/apple-app-site-association`
now also has `"webcredentials": { "apps": ["GWU44KGDJZ.nl.foodrun.app"] }`, next to
`applinks`. The app's `webcredentials:foodrun.nl` entitlement needs nothing else;
iOS re-reads the file on install or update of the app.

**4. A colour per employee.** `employees.color` — `String?`, `"#rrggbb"`. The
database gives every new row one (dashboard, `worker-self-signup`,
`employee-identity-link`, imports): the palette colour the fewest colleagues at that
employer have. All existing rows have one. The employer can pick another in HQ; a worker
cannot change their own (`employees_protected_field`, as for pay and roles).

Palette (the team pastels of the design system; treat any `#rrggbb` as valid, the
palette may grow): `#f0a8c8` pink, `#fbe27a` yellow, `#86efac` green, `#7aa6f5` blue,
`#5fcccc` teal, `#c084fc` purple, `#f17878` red, `#f97316` orange. Ink text on top.

Where the app reads it:

- `WorkerAPI.fetchMyEmployees` and `fetchOperatorContext`: add `color` to the select
  list and `public let color: String?` to `DBEmployee`.
- The briefing (`get_my_event(...).briefing.team`): each day now has `members` next to
  `names`, same people in the same order:

```swift
public struct CrewTeamMember: Decodable, Hashable {
    public let name: String
    public let color: String?     // nil for an old roster entry that is a name, not an employee
}
// CrewTeamDay: date, names: [String], members: [CrewTeamMember]?  (optional: older servers)
```

`team` is still empty when the employer hides the team in the briefing.

### Invites by email: the link signs in and puts the worker on the team (2026-10-15 — server live, app to do)

Migration `20261015110000_worker_invites.sql`, edge fn `worker-invite` (HQ repo, `3beca53`).
This replaces the plan in `FoodrunApp/Invitations/README.md` (`worker_invites` +
`redeem-invite`); the 6-digit code there is covered by the organisation's join code.

**What the employer does.** HQ → Stakeholders → Medewerkers → **Uitnodigen**: type an
address. With a Foodrun account they can **add** the person straight away (approved,
an inbox message `type = hired`, nothing for the app to do). Otherwise, or by choice,
they **send an invite**: an email with `https://foodrun.nl/invite/<token>` (32
URL-safe characters, 7 days, single use, a newer invite to the same address replaces
it). The token is only in that email; HQ never sees it.

**What the app does with the link** (`https://foodrun.nl/invite/<token>` as universal
link, and `foodrun://invite/<token>`; take the last path component):

1. Signed in? Go to 3. Not signed in: the link itself signs in —

```swift
struct InviteAction: Encodable { let action: String; let token: String }
struct InviteSignIn: Decodable { let ok: Bool; let error: String?; let token_hash: String?; let type: String?; let email: String? }
let r: InviteSignIn = try await client.functions.invoke("worker-invite",
    options: FunctionInvokeOptions(body: InviteAction(action: "sign_in", token: token)))
// r.type is "magiclink" (existing account) or "signup" (the account was just made)
try await client.auth.verifyOTP(tokenHash: r.token_hash!, type: r.type == "signup" ? .signup : .magiclink)
```

2. (Optional, before 1) show who invites: `action: "peek"` → `{ ok, state: "open" |
   "used" | "expired" | "invalid", organization_name, email_hint }` (`email_hint` is
   masked, e.g. `sa••••@gmail.com`). No session needed.
3. Accept:

```swift
struct RedeemParams: Encodable { let p_token: String }
struct Redeemed: Decodable { let organization_id: UUID; let organization_name: String; let employee_id: UUID }
let joined: Redeemed = try await client.rpc("redeem_worker_invite", params: RedeemParams(p_token: token)).execute().value
```

   Then reload `ScheduleStore` (the row is approved: shifts and "my organisations"
   show the employer at once) and say "Welcome to <organization_name>". Calling it
   again as the same account returns the same answer.

Errors — `worker-invite` answers HTTP 200 with `{ ok: false, error }`;
`redeem_worker_invite` raises with PostgREST `code` `P0001` and `message`:

| error / message | Meaning | Say |
|---|---|---|
| `invalid_invite` | unknown link, or replaced by a newer invite, or withdrawn | "This invite no longer works. Ask your employer for a new one." |
| `invite_used` | already accepted (by another account) | "This invite has already been used." |
| `invite_expired` | older than 7 days | "This invite has expired. Ask your employer for a new one." |
| `invite_for_other_account` | the invited address has its own account and you are signed in with another | offer "Sign out and continue": sign out, then step 1 |
| `too_many_sign_ins` | the link signed in 5 times in a short while | "Try again in a few minutes." |
| `not_authenticated` (`42501`) | redeem without a session | do step 1 first |

Signed in with a different account than the invited address (e.g. Sign in with Apple
with a hidden address): if that address has no account yet, accepting links the
invite to the signed-in account. That is on purpose.

**Turning it on.** Until the app handles these links, HQ keeps `/invite/*` out of
`apple-app-site-association` and the web page shows only "Accept in the browser"
(`APP_HANDLES_INVITES = false` in `src/pages/InviteLanding.tsx`). When the build that
handles `/invite/<token>` and `foodrun://invite/<token>` is ready, ask HQ to add
`{ "/": "/invite/*" }` to the AASA components and set that flag — before that build
reaches testers, because iOS reads the file on install or update.

### Shift extras, Ruilen, Verlof, availability rules (2026-10-17 — server live, app built here)

HQ migrations `20261017100000` … `160000` (HQ decisions 0087–0090).

**Shift extras.** A `daily_employee_times[day][employee]` entry may carry, next to
`startTime` / `endTime`: `breakMinutes` (int), `note` (string), `checklistIds` (uuid strings)
and `shiftType` (string). `DBDayTimes` decodes them leniently; `WorkerShift` exposes
`breakMinutes`, `note`, `shiftType`, `checklistCount`. **Writers must keep them**:
`WorkerAPI.updateRoster` now reads and writes the entries as `RawJSON` and only replaces
`startTime` / `endTime`. Checklists on a shift (and on a person's role) arrive as ordinary
`crew_tasks` through `get_my_crew_tasks` — no app change needed for those.

**Ruilen** (`PeopleAPI`, `SwapStore`, `SwapsView`, `SwapOfferSheet`; `AppConfig.Features.shiftSwaps = true`):

| Call | Does |
|---|---|
| `get_my_swap_board()` | `{ mine, offered, open_shifts, colleagues, my_shifts }` — see `SwapBoard` |
| `request_shift_swap(p_activity_id, p_day, p_to_employee_id?, p_note?)` | offer my shift to one colleague or everyone (explicit nulls) |
| `respond_shift_swap(p_request_id, p_accept)` | take over (`approved` at once, or `accepted` = planner decides) or turn down a targeted offer (`declined`) |
| `request_open_shift(p_activity_id, p_day, p_note?)` | ask for an open place: `approved` or `accepted` |
| `withdraw_shift_swap(p_request_id)` | take my request back while undecided |
| `request_shift_takeover(p_activity_id, p_day, p_from_employee_id, p_note?)` | ask a colleague for their shift (kind `ask`, take over only); they get `swap_asked` |
| `respond_shift_swap(p_request_id, p_accept)` on an ask | the colleague with the shift gives it (`accepted` / `approved`) or keeps it (`declined`) |
| `get_my_team_roster(p_from, p_to)` | published shifts of my employers, max 31 days: `[{ day, employee_id, name, color, is_me, employer, activity, window, ask }]` — see `TeamShift` |

`get_my_swap_board` also returns `asked`: colleagues asking for one of my shifts (`SwapAsk`); my own
asks are in `mine` with `kind = ask`, `role = taker` (HQ migration `20261022120000`). The app shows
colleagues on the Rooster tab (worker view; tap → `TakeoverSheet`) and the cards that wait for an
answer in the Inbox (`SwapInboxCards`); the Shifts home has no swap banner any more.

Error codes in the message: `already_requested`, `already_on_shift`, `no_open_place`,
`not_open`, `in_the_past`, `not_on_shift`, `unknown_colleague`, `shift_changed`
(`PeopleAPI.message(for:)` maps them to `swap.error.*`).

**Verlof**: `leave_requests` — read own rows; insert `{employee_id, start_date, end_date,
reason, status: 'pending'}`; withdraw = update `status = 'cancelled'` (only while pending).

**Availability rules**: `get_my_availability_rules()` → per employer `{ owner_id, employee_id,
organization_name, reason_required, deadline: { weekday (0 = Mon), time, weeks_before } | null,
closed_days: [date] }`. The guard trigger still decides; the app shows closed days, the
deadline and the reason hint ahead of time, and shows the server's Dutch error text.

**Wanted shifts per week**: the "this week" stepper now reads and upserts
`employee_week_preferences (employee_id, week_start = Monday, wanted_shifts 0–7)` for every
linked employee row.

**Hours**: the submit also sends `start_time` / `end_time` ("HH:mm").

**Inbox types** added: `profile_edited`, `roster_updated`, `leave_approved`, `leave_rejected`,
`availability_reminder`, `swap_offered`, `swap_accepted`, `swap_approved`, `swap_declined`,
`open_shift`, `pickup_approved`, `pickup_declined`. Swap kinds open Ruilen, leave kinds open
Verlof, the reminder opens Availability, `roster_updated` the Shifts tab.

**Employer accounts**: `ScheduleStore.isOperator` = owns staff. (The Profile →
"Werkgever-functies" switch was removed on 2026-10-22: owners always get the full roster and
Add shift.)

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

### Setup pins (requested 2026-10-24; server live 2026-10-26, `setupPins = true` since 2026-10-28)

The shift's Setup tab gets its own "Locatie pinnen". Those pins belong to build-up /
teardown and show only on the Setup tab, never in the Draaiboek.

- `submit_my_location_pin(..., p_section text default 'script')`: `'script'` | `'setup'`.
  The app sends `p_section` only for a Setup pin, so the default keeps older app builds
  and Draaiboek pins working unchanged.
- `get_my_event(...).briefing.locations[]`: each entry carries `section` (`'script'` |
  `'setup'`). Locations an operator adds in the script editor are `'script'`, unless
  added in the editor's Setup part.
- `delete_my_location_pin` is unchanged.
- HQ shows Setup pins in the Setup (opbouw / afbouw) part of the script editor and the
  crew portal, not with the script's locations.
Once this is live, set `setupPins = true`.

### Opbouw / afbouw days on the roster (server live 2026-10-28, HQ migration `20261028120000`)

HQ's Rooster can now roster people on an event's opbouw (`setup_date`) or afbouw (`teardown_date`) day when that
day falls outside the event's own days (`start_date … end_date`). Nothing new in the shape:

- The shift is stored like any other day: a `daily_employees[day]` key and `daily_employee_times[day][id]`, with
  `shiftType` "Opbouw" / "Afbouw". `scheduledDays(for:)` already lists it, so it shows as a normal shift under
  the event. Don't filter a worker's shifts by `start_date … end_date`; `activitiesRunning(on:)` (availability)
  still uses the event's own days, which is right.
- `clock_with_tag`: a per-day roster entry now counts on any day from the opbouw to the afbouw (it answered
  `no_shift_here_today` on such a day before). The legacy flat `employees` list still only covers start … end.
- `get_my_worker_activities(p_from, p_to)`: the window filter now uses the opbouw … afbouw span, so a range that
  only holds the opbouw day still returns the event. Same columns.

### Transport planner removed (HQ migration `20261026130000`, 2026-10-28)

`transport_legs`, `transport_leg_assignments`, the five transport RPCs and `activities.overnight_nights` /
`accommodation_address|coords` (+ the same two on `activity_groups`) are gone. The app never used them.
`employees.car_capacity` stays.
