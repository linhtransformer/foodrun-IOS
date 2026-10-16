# Invitations

Email invites are built (2026-10-16): `InviteLink.swift` (link parser + `PendingInvite`)
and `InviteView.swift` (peek → accept → sign in through the link when needed →
`redeem_worker_invite` → welcome). Server side: edge fn `worker-invite` and RPC
`redeem_worker_invite` (HQ `3beca53`); contract in
`FoodrunApp/Supabase/SchemaContract.md` → "Invites by email".

The other way round — the worker asks, the employer approves — is the join code
(`JoinRequestView.swift`).
