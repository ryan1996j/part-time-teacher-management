# SayaSync — Resume checkpoint

Saved: 2026-10-25 (Asia/Bangkok).

## Owner constraints

Preserve approved UI and business flow. Current backend development is LOCAL ONLY. Do not commit, push, deploy, send invitation email or grant a real teacher access without the owner's explicit authorization. Do not request passwords or secret keys in chat.

## Working directories

- Active local Next.js/backend work: D:/Ai14/sayasync-next-foundation (not a Git checkout).
- Connected publication checkout: D:/Ai14/part-time-teacher-management-publish.
- GitHub: https://github.com/ryan1996j/part-time-teacher-management
- Last known deployed main commit: 561d5a1b55bed6c17c72dd22d85e8158b0f71746. Recheck remote before any future publication.
- Live UI demo: https://sayasync.netlify.app/login (does NOT include the subsequent local backend changes).

## Local app

http://127.0.0.1:3002/login

If the server has stopped, from the active directory run:

```powershell
npm ci
npm run build
node node_modules/next/dist/bin/next start --hostname 127.0.0.1 --port 3002
```

Skip npm ci when existing dependencies are intact. The server needs outbound access to the approved Supabase project. Do not share .env.local. It holds only the project URL/publishable key and is ignored; no service-role/secret key was configured. Do not start a duplicate process if port 3002 is already serving the app.

## Approved Supabase development target

Project ereyjhtkypeowifrmyqv, organization SayaSync, Sydney/ap-southeast-2. Use this existing project; do not invent/create another one.

Pilot school: Ryan's school, ID [pilot school ID stored in the approved database].
Admin: [configured administrator email], Auth ID [administrator Auth ID stored in the approved database]. Owner accepted invitation, set password personally and successfully logged in. Never read their password/cookies/tokens.

Supabase public signup is disabled; email confirmation remains enabled. Development Site URL: http://127.0.0.1:3002/auth/accept-invite. Invitation links work on this computer with the local server running. Do not redirect real invitations to the public demo.

## Completed locally and in development DB

- Supabase browser/server clients and private .env.local.
- Real password login via Server Action, verified Auth identity and active database membership.
- Protected role layouts/proxy, no-store responses, cookie refresh, logout.
- Owner login, page-refresh persistence, logout and blocked post-logout direct entry were manually verified.
- Database-backed native Teachers/Classes pages, rate history, timestamped assignments, activate/deactivate, audit, optimistic versions and retry deduplication.
- Owner added teacher Ayyy ([saved teacher email; inspect the approved database], code T005), class RC101 (Computer Engineering, code C005), and assigned the teacher. Re-read current state before modifying; these owner-created records must be preserved.
- Teacher account linking RPC/UI prepared. Exact saved email only; cannot promote Admin, hijack cross-school identity, silently reactivate disabled membership or link without invitation/verified account. Actual teacher remains UNLINKED.
- Teacher access now also requires an active linked teacher profile. Native teacher portal shows own identity/assigned classes; check-in and other business screens are explicitly pending. Never substitute fictional T001 for a real teacher account.
- Admin Overview, class records, reviews, payroll, payments and old Activity log still use separate fictional prototype data. They are not database-backed yet.

## Manually applied SQL migrations

supabase/migrations/202610250001_identity_foundation.sql
supabase/migrations/202610250002_master_data.sql
supabase/migrations/202610250003_assignment_visibility.sql
supabase/migrations/202610250004_teacher_accounts.sql

Applied through the Supabase dashboard SQL editor. CLI migration history is NOT reconciled: do not blindly replay these migrations. Inspect schema/history before adopting CLI deployment.

## Validation

- npm run build, npm run typecheck, npm run verify:baseline passed. All 30 frozen legacy assets unchanged.
- SQL tests identity_rls.sql, master_data.sql and teacher_accounts.sql passed with disposable fixtures rolled back. Identity sequence gaps after tests are expected.
- 5 auth/access/protected-route tests passed (scripts/auth-access.test.mjs and scripts/protected-routes.test.mjs).
- 4 mocked linked-identity tests passed using the existing global tsx runner: scripts/verified-access.test.cjs.
- Last cleanup check: schools=1, auth_users=1, teacher_links=0, test_accounts_remaining=0, anonymous_link_allowed=false.
- Real teacher invitation/password/login end-to-end test remains PENDING.

## Exact next action — pending approval

The agent asked: May I send an invitation to Ayyy / [saved teacher email; inspect the approved database] and link Teacher access to Ryan's school?

The owner has NOT approved that specific recipient/action yet; the next message was about saving progress because usage is low. Do not treat a resume request as invitation approval.

Once specifically approved:
1. Inspect existing Auth users and teacher account state to avoid duplicate invitations.
2. Use the Supabase dashboard Authentication > Users > Add user > Send invitation for the approved exact email. No automated invitation service key is configured.
3. Have the recipient open the invitation locally and set their password personally; never enter a new password for them.
4. Use the local Admin Teachers > Account access dialog to link the matching invited account with a reason and the explicit Teacher-access checkbox. Verify role and own-record isolation. Do not change Admin account/role.
5. Verify Teacher login, assigned class visibility, Admin route denial, logout and inactive access.
6. Later slices: server-timestamp check-in/out, class records, corrections/verification, payroll and payment integrity. No live deployment unless separately authorized.

## More detail / artifacts

- docs/supabase-development-setup.md (chronological development record; latest sections supersede earlier status).
- D:/Ai14/SayaSync_Backend_PRD_v2_MM.md
- D:/Ai14/SayaSync_Nextjs_Supabase_Netlify_Migration_Plan_EN.md
- D:/Ai14/sayasync-teacher-account-access.png

## Suggested resume prompt

Read D:/Ai14/sayasync-next-foundation/RESUME_CHECKPOINT.md and docs/supabase-development-setup.md. Inspect current local app and approved Supabase project read-only, then tell me the next pending step. Preserve UI/business flow. Do not push/deploy/send invitations/grant access until I explicitly approve the specific action.


## Git backup update

Owner approved backing up this source on backend/auth-master-data. No merge or deployment is authorized. This published checkpoint omits owner email/account identifiers; re-read the approved development database when resuming. The original local checkpoint remains at D:/Ai14/sayasync-next-foundation/RESUME_CHECKPOINT.md. Recipient-specific teacher invitation approval is STILL pending.
