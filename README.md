# SayaSync · Part-Time Teacher Management

## Live application

- [Sign in](https://sayasync.netlify.app/login)
- [Admin overview](https://sayasync.netlify.app/admin/overview) — requires an authorized Admin account.
- [Teacher workspace](https://sayasync.netlify.app/teacher/home) — requires an authorized linked Teacher account.

The Netlify deployment uses Next.js and Supabase Auth. Public self-registration is disabled; the school administrator manages access. The earlier `/login.html` URL redirects to `/login`.

## Current functionality

Database-backed features: role-protected login/logout, Teachers, Classes and dated assignments, rate history, teacher check-in/out, completed Admin entries, correction requests, Admin correction review, separate session verification, immutable original timestamps and audit history, and real Admin Overview counts/activity/recent records.

Payroll drafts, reasoned adjustments, approval and locked allocations, manual full-payment records, Teacher payment views, financial Overview totals and Admin Reports/CSV export are database-backed. Draft amounts are excluded from financial reporting. The legacy Activity log remains a prototype. Recorded teaching activity includes unverified/rejected completed records and must not be treated as payable time.

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

## Financial reports release

- [Financial reports and CSV](https://sayasync.netlify.app/admin/reports) — authorized Admin only.
- [Teacher payments](https://sayasync.netlify.app/teacher/payments) — authorized linked Teacher only.

Production application: https://sayasync.netlify.app/login. Reports show approved payroll only, with Teacher/payment status and whole-payroll-period overlap filters (no date proration). Overview totals span all approved periods. CSV is UTF-8 with formula-injection protection and exact whole-MMK amounts. Current reporting limit:10,000 teacher-payroll rows, with explicit failure rather than truncation. Multi-page reports are not a transactional point-in-time snapshot during concurrent payment updates; refresh after concurrent work.

Recording a payment does not transfer money. Partial payments, reversal and Void workflows are not implemented. Migrations008–010 were manually applied to the development database; reconcile migration history before automated deployment and never replay blindly. No further schema migration is required for Reports.

Validation: production build/TypeScript,30 frozen assets and15 auth/report tests passed. Payroll/payment rollback integration tests passed previously. Admin/Teacher payment flow was owner-confirmed. New Reports/Overview authenticated UI and actual CSV download still need owner acceptance; browser automation was unavailable.
