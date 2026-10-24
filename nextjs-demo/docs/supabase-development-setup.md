# Supabase development setup — identity foundation

Target explicitly approved by owner: ereyjhtkypeowifrmyqv, SayaSync organization, Sydney/ap-southeast-2.

## Completed

- Official Supabase browser/server client helpers installed locally; ignored .env.local uses only project URL and publishable key.
- Before migration, read-only inventory confirmed no public application tables, no public policies, zero Auth users, and an existing public.rls_auto_enable function.
- Applied supabase/migrations/202610250001_identity_foundation.sql through the dashboard SQL editor. This creates schools, profiles and memberships with RLS, read-only authenticated grants and restricted private helper functions. The existing function is preserved.
- Signup creates only a profile via a trigger; no school, role or membership is taken from user metadata. No initial administrator was created.
- Database-backed active membership and school checks govern school data visibility. Teachers see their own membership/profile; administrators see profiles/memberships only within their active school. Direct client writes are denied even for administrators until trusted audited operations are implemented.
- Public signup disabled in Supabase Auth; email provider and confirmation remain enabled. Read-only API check confirmed publicSignupDisabled=true and emailAutoConfirm=false.
- Transactional SQL tests passed: admin/teacher visibility, cross-school isolation, inactive membership, disabled school, anonymous denial and attempted privilege escalation. All disposable fixtures rolled back.

## Validation artifacts

- Migration: supabase/migrations/202610250001_identity_foundation.sql
- RLS integration tests: supabase/tests/identity_rls.sql
- Auth diagnostic: node scripts/check-supabase-connection.mjs
- Screenshot: D:/Ai14/sayasync-rls-tests-pass.png
- Local TypeScript, production build and 30-file baseline checks passed in the connection setup slice.

The migration has been applied manually; Supabase CLI migration history has not been synchronized. Do not blindly replay it. Before adopting CLI deployment, compare the schema and record the already-applied migration using the supported history-repair workflow.

## Still pending

- Select the pilot school name and the owner's administrator email. Bootstrap the first administrator through an explicitly approved trusted procedure; never let signup create admin membership.
- Teacher business profiles/teacher-to-account links and all class/payroll tables belong to later migrations. They are not implemented by this identity slice.
- Real login/logout, invitation/recovery callbacks, development redirect URLs, session-refresh proxy and server-side verified identity/membership checks are not wired yet.
- The live website and local forms remain the existing fictional UI demo. The prepared server helper must be used in writable Server Actions/Route Handlers until the full session-refresh layer exists.
- Do not treat this tested foundation as a completed authentication system or security audit.

No GitHub commit/push or live deployment occurred in this setup slice. No database password or service-role/secret key was retrieved.

## Owner-approved pilot bootstrap

- Created Ryan's school (school ID [pilot school ID stored in the approved database]).
- Owner explicitly approved the recipient and Admin access before invitation/membership creation.
- Supabase accepted the email invitation and created its Auth user; an active admin membership was verified. Inbox delivery and the recipient's acceptance are not yet verified.
- Development Site URL is http://127.0.0.1:3002/auth/accept-invite. Added a local-only invitation/password setup page with token removal from the address bar, server-verified user lookup, password confirmation and sign-out after password setup.
- Local invitation server runs on port 3002. Recipient must open the invitation on this computer while the server is running. No invitation token or password was read or stored by the agent.
- Password setup must be completed by the recipient, not the agent. Real workspace sign-in remains pending. Existing demo forms/business screens were not changed.
- Build, TypeScript and original-asset baseline checks passed after adding the callback. No push/deploy occurred.

## Local real authentication slice

Local app http://127.0.0.1:3002/login now uses a Supabase password sign-in Server Action, verified getUser identity and a database-backed active membership lookup. Role selection buttons were removed from the real login form; role comes from membership, not browser storage or metadata. Ambiguous multi-school access fails closed for the single-school pilot.

Next.js proxy refreshes cookies, verifies identity and rechecks membership for workspace requests; both role layouts independently recheck authorization. Protected responses use private/no-store. Anonymous and forged UI markers cannot open /admin, /teacher or /legacy/index.html. Logout calls Supabase signOut and discards the client router cache. Legacy sign-out uses the same server action.

Original workspace data remains fictional and browser-local. The legacy sessionStorage marker exists only to preserve prototype rendering after server authentication. It grants no database authority. Legacy iframe business behavior is still a prototype, not production teacher-record authorization or real payroll processing. Signup and Forgot password remain explicit demos; real invitation setup is a separate route. No production password-reset email flow was added.

Validation: production build and TypeScript passed; 5 auth/access/route tests passed; all 30 legacy assets unchanged; fictional invalid credentials receive generic rejection. Real owner login, refresh persistence and interactive logout still require the owner's manual test. No real password was handled by the agent.

Files: app/auth/actions.ts, proxy.ts, lib/auth.ts, lib/auth-access.ts, lib/logout-workspace.ts, components/WorkspaceSession.tsx and role layouts. No push/deploy occurred.

## Owner login verification completed

Owner entered their password themselves and successfully reached /admin/overview. A full page refresh preserved authenticated access. Sign out returned to /login; navigating directly to /admin/overview afterwards redirected to /login. No password, token or cookies were read by the agent. This verifies login persistence across a page refresh, not token-expiry refresh or a full production penetration test. Logout screenshot: D:/Ai14/sayasync-auth-logout-verified.png. No push/deploy occurred.

## Database-backed master data slice

Applied additive development migrations 202610250002_master_data.sql and 202610250003_assignment_visibility.sql after inventory confirmed only the existing identity tables. No sample teacher/class records were imported.

Implemented:
- Teachers and classes with school-scoped identifiers, email uniqueness, active status and optimistic versions.
- Immutable effective-date hourly rate versions (a version ends implicitly at the next effective date).
- Timestamped assignment history with a database exclusion constraint preventing overlapping intervals for the same teacher/class.
- Composite tenant foreign keys, school/own-record RLS and authenticated read-only grants.
- Authenticated administrator-only manage_master_data RPC for atomic creation, rate changes, status and assignment changes, with school serialization, retry IDs, audit records and stale-write protection. Direct client writes are denied.
- Native React Teachers and Classes pages matching original cards/forms, with reusable modal/shell styles, a single Cancel action, validation, busy/error feedback and refresh. Legacy sidebar navigation forwards to the new native pages.

Backend integration tests in supabase/tests/master_data.sql passed for creation, retry deduplication, duplicate email/rate dates, stale update rejection, assignment history, audit counts, teacher access, cross-school isolation, mutation denial and linked-teacher deactivation. Fixtures were rolled back. PostgreSQL identity sequences may have normal gaps after rollback; codes are not counts.

A transaction-time visibility edge case was found in tests and corrected by migration 003. Production build, TypeScript, 5 auth/route tests and all 30 unchanged baseline assets passed. The owner logged in manually; Teachers/Classes empty states, modal fields and required-field validation were inspected. No real class/teacher was created through the UI, so the owner's first real submission remains a manual acceptance step.

Boundaries:
- Teachers/Classes/Assignments now use development PostgreSQL. Overview, class records, review, payroll, payments and the old Activity log still use separate fictional prototype state. Real master records do not yet feed those pages.
- A teacher profile does not send an invitation or automatically create/link an Auth account. Trusted teacher invitation/linking is a later slice. No student or real teaching records are stored by this phase.
- Deactivating a linked teacher disables their teacher membership; reactivating the profile does not silently restore account access. A separate reviewed account operation is required.
- Real open-session checks must be added when teaching_sessions is implemented; there are currently no real session records to check. Production rollout remains blocked until those transactional rules, teacher account linking and subsequent business slices are complete.
- master_data_events is the master-data audit stream; the existing prototype Activity log is not its viewer yet.
- CLI migration history is still not synchronized; do not blindly replay manually applied migrations.
- No GitHub push or live deployment occurred.

Owner acceptance update: during review the owner added a teacher profile and an initial rate through the local UI. A fresh Teachers page request displayed the saved profile and rate. Final inventory showed one teacher, one rate, zero classes/assignments, one master audit event, one school and one Auth user; RLS enabled and anonymous RPC execute denied. Owner-entered records were preserved. This supersedes the earlier note that the first real submission was still pending. Screenshot: D:/Ai14/sayasync-database-teachers.png.

## Teacher account linking slice (awaiting recipient approval)

Applied additive development migration 202610250004_teacher_accounts.sql. It creates administrator-only link_teacher_account and teacher_account_states RPCs. No real invitation was sent and no real teacher account was granted access by this slice.

The link operation uses the saved teacher email, never a client-supplied Auth user ID or role. It requires an active unlinked profile, exact matching invited/confirmed Auth account, expected profile version and a reason/request ID. It cannot replace an Admin role, attach a cross-school account, reuse an already linked identity, reactivate a disabled membership or run as a Teacher/anonymous caller. The transaction creates only a Teacher membership and appends audit/idempotency records.

Teachers cards now show Account access. The dialog names the recipient and requires an explicit Teacher-access approval checkbox when an invited account is ready. Without an invitation the link action is disabled. Email invitation remains an owner-operated Supabase dashboard step: no service-role/secret key is stored or requested and no automated invitation endpoint is enabled.

Login, proxy and role layouts now require an active teacher profile linked to the authenticated user in addition to active membership. Unlinked teacher memberships fail closed. Real teachers no longer enter the legacy T001 fictional identity. Teacher navigation/style is retained; own profile and assigned classes are read under RLS in a native portal. Check-in, class records, corrections and payments are explicitly unavailable until their backend slices are implemented; other teachers' fictional records are not substituted. Raw legacy workspace entry redirects Teacher accounts to their native portal.

Validation: production build, TypeScript and unchanged 30-asset baseline passed; 4 mocked linked-identity authorization tests and 5 existing auth/route tests passed. SQL integration tests passed exact-email matching, role restrictions, retry deduplication, stale versions, no invitation, Admin account protection, disabled account protection, tenant isolation and teacher grant denial. Disposable fixtures rolled back; teacher code sequence gaps are expected. A real teacher invitation/password/login end-to-end test remains pending recipient approval and manual password setup.

Local owner Admin UI was checked: the existing Ayyy profile shows Invitation needed and a disabled Link Teacher account button. Existing school/teacher/class/assignment records are preserved. Screenshot: D:/Ai14/sayasync-teacher-account-access.png. No push/deploy occurred. Manually applied migration history still needs later CLI reconciliation.
