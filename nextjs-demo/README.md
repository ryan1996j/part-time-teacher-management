# SayaSync Next.js demo

Local migration preview with approved Sign in and Sign up screens and native React Admin Overview. Other workspace pages retain the original prototype through an isolated legacy preview.

## Run locally

From this directory:

```powershell
npm ci
npm run dev
```

Open http://127.0.0.1:3001/login or http://127.0.0.1:3001/signup.

This is a UI demo: sign-in uses fictional Admin/Teacher sessions. Sign-up validates its fields and shows completion without creating an account, sending a request/email, or granting access. Do not enter real credentials. Supabase and production authorization are not configured.

## Verify

```powershell
npm run typecheck
npm run verify:baseline
node --test scripts/demo-session.test.mjs
npm run build
```

Live demo: [Sign in](https://sayasync.netlify.app/login) · [Sign up](https://sayasync.netlify.app/signup). Netlify builds this directory using the Next.js runtime. The original static prototype remains in the repository for reference.
