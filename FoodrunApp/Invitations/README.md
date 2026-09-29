# Invitations — blocked on design

Bundle §"Invitations — recommended model" describes the intended flow but the four
screens are **still to design**:

1. **Manager invite composer** — dashboard-side (lives in the HQ React repo, not iOS).
2. **Worker join-from-link** — deep-link `foodrun://invite/<token>` opens the app with
   the org pre-attached; worker sets a password or uses Apple/Google sign-in.
3. **Enter-code** — 6-digit fallback for a dead link or shared phone.
4. **Orphan-account** — "you signed up without an invite" state; only screen is
   "enter your invite code."

## What's already scaffolded

- URL scheme `foodrun://` is already registered for magic-link callbacks — the
  invite handler can piggy-back off that.
- `AuthViewModel` covers sign-in / sign-up mechanics.
- `employees.auth_user_id` linking runs through the `employee-identity-link` edge fn
  on Supabase — same fn a valid invite would call.

## What lands here when design lands

- `InvitationView.swift` — join-from-link screen; reads the token from the deep-link
  and calls a new `redeem-invite` edge fn (spec below).
- `EnterCodeView.swift` — 6-digit code entry.
- `OrphanAccountView.swift` — the "you have no org yet" screen.

## Backend needed (out of iOS repo)

- New edge fn `redeem-invite`: input `{ token }` → validates + attaches
  `employees.auth_user_id`. Returns matched org.
- New table `worker_invites`: `token`, `code`, `employee_id`, `created_by`,
  `created_at`, `expires_at`, `redeemed_at`. Single-use.
- Manager UI in HQ dashboard to mint + send invites (WhatsApp + email).

Track this in the HQ wiki (`wiki/architecture/worker-portal.md` §Open questions) so
the two apps stay aligned.
