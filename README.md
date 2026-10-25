# SayaSync · Part-Time Teacher Management

## Live application

- [Sign in](https://sayasync.netlify.app/login)
- [Admin overview](https://sayasync.netlify.app/admin/overview) — requires an authorized Admin account.
- [Teacher workspace](https://sayasync.netlify.app/teacher/home) — requires an authorized linked Teacher account.

The Netlify deployment uses Next.js and Supabase Auth. Public self-registration is disabled; the school administrator manages access. The earlier `/login.html` URL redirects to `/login`.

## Current functionality

Database-backed features: role-protected login/logout, Teachers, Classes and dated assignments, rate history, teacher check-in/out, completed Admin entries, correction requests, Admin correction review, separate session verification, immutable original timestamps and audit history, and real Admin Overview counts/activity/recent records.

Payroll, payment processing and the legacy Activity log are not connected to real financial workflows yet. Overview payroll figures show unavailable placeholders. Recorded teaching activity includes unverified/rejected completed records and must not be treated as payable time.

This release connects the existing development backend. It is a development pilot, not a completed payroll product. No payment transfers occur.

## Local development

```powershell
cd nextjs-demo
npm ci
# Configure public Supabase URL and publishable key locally (never commit .env.local).
npm run dev
```

Default development URL: http://127.0.0.1:3001/login. The existing local acceptance server may use port 3002.

## Validation

```powershell
npm run build
npm run typecheck
npm run verify:baseline
```

Database integration tests in `nextjs-demo/supabase/tests` use disposable rollback fixtures. Never replay migrations blindly: development schema was applied manually and CLI migration history needs reconciliation.

## Netlify deployment

Production URL: https://sayasync.netlify.app/login. Repository: ryan1996j/part-time-teacher-management. Base: `nextjs-demo`; build: `npm run build`; publish: `.next`; Node 24; Next.js adapter configured in `netlify.toml`.

Configure `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in Netlify's build/runtime environment. Never add a Supabase service-role key to frontend configuration or source control. Existing RLS and server-side role/membership checks protect school data. Deploying application code does not apply SQL migrations or modify Supabase Auth redirect settings.

## Original prototype

`dist` and `nextjs-demo/public/legacy` retain the earlier prototype. Unmigrated finance screens still contain fictional data. The real Admin Overview no longer reads fictional browser-storage totals.
