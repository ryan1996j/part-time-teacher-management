# SayaSync · Part-Time Teacher Management

## Live demo

- [Sign in](https://sayasync.netlify.app/login)
- [Sign up](https://sayasync.netlify.app/signup)

The Next.js UI demo is deployed on Netlify. The old /login.html URL redirects to /login.

This is a browser-only prototype, not production authentication. Use fictional details only. Sign-in opens the selected Admin/Teacher demo workspace; sign-up validates fields and shows a completion message without creating an account, sending email, or granting access. Supabase is not connected.

## Current application

The Next.js project is in nextjs-demo. Sign in, Sign up and Admin Overview use native React. Other workspace pages preserve the approved prototype through an isolated legacy preview. Business workflows remain teacher records, verification, corrections, payroll calculation and fictional payment history.

```powershell
cd nextjs-demo
npm ci
npm run dev
```

Open http://127.0.0.1:3001/login.

## Validation

```powershell
npm run typecheck
npm run verify:baseline
node --test scripts/demo-session.test.mjs
npm run build
```

## Netlify deployment

Production branch: main. Base directory: nextjs-demo. Build command: npm run build. Publish directory: .next. Node.js: 24. Enable the Next.js runtime; publishing raw .next output without its adapter causes missing routes. netlify.toml records the build configuration and Next.js plugin.

## Original prototype

The dist folder retains the earlier HTML, Tailwind CSS and jQuery prototype. Its unchanged assets are also retained in nextjs-demo/public/legacy. It is not the current Netlify publish directory.

Fictional workspace records persist in browser storage. Demo roles are client-side simulation and do not enforce production access permissions. No real payroll transfers occur.