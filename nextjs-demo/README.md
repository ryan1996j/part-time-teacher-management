# SayaSync development backend checkpoint

This branch backs up local backend development. It is not merged into main and must not be deployed automatically. The public site at https://sayasync.netlify.app/login remains the earlier UI demo.

## Implemented

- Supabase password login/logout, verified identity, active memberships, protected role routes and session refresh.
- Database-backed Teachers, Classes, effective rate history and dated Assignments, with RLS, audit, optimistic versions and retry protection.
- Owner-approved pilot administrator setup.
- Teacher account linking controls and a native own-record Teacher portal. Real teacher invitation/linking is still awaiting approval of the recipient.

Overview, teaching sessions, corrections, payroll, payments and the old Activity log still use separate prototype data or are explicitly unavailable. This is not a completed production backend.

## Resume

Read RESUME_CHECKPOINT.md and docs/supabase-development-setup.md first. The checkpoint names the local workspace and approved development project. Inspect current remote/database state before continuing. Do not replay migrations blindly: they were manually applied to the development database and CLI migration history is not yet reconciled.

## Run locally

```powershell
npm ci
```

Copy .env.example to .env.local and set the approved project's URL and publishable key locally. Never commit .env.local or a secret/service-role key.

```powershell
npm run build
node node_modules/next/dist/bin/next start --hostname 127.0.0.1 --port 3002
```

Open http://127.0.0.1:3002/login. Supabase invitations currently return to this computer at /auth/accept-invite; a local server must be running. Users set their passwords themselves.

## Validation

```powershell
npm run typecheck
npm run verify:baseline
node --test scripts/auth-access.test.mjs scripts/protected-routes.test.mjs
npm run build
```

The protected-route tests require the localhost server on port 3002. Additional linked-identity tests are in scripts/verified-access.test.cjs and need a TypeScript-capable runner. SQL integration tests are in supabase/tests; use only an approved disposable development database/context. They roll back fixture rows; generated identifier sequences may have gaps.

## Backup boundaries

This Git branch backs up source code and versioned migrations, not Supabase database records, Auth accounts, passwords or runtime environment configuration. Live data requires a separate database backup. The original prototype assets remain frozen under public/legacy.
