# SayaSync · Part-Time Teacher Management

Approved PRD v0.3 implemented as a browser-only interactive prototype using **HTML, Tailwind CSS and jQuery**. No backend, API, database, real authentication, account invitation or payment processing is included.

## Open

Serve `dist` with a static web server so sign-in and the workspace share the same browser origin. On this Windows machine, double-click `start-preview.cmd`, then open `http://127.0.0.1:4173/`. Alternatively run `python -m http.server 4173 --bind 127.0.0.1 --directory dist` from the project folder. This server serves static files only; it contains no application backend or database. Tailwind and jQuery are included locally; no external services or build step are needed.

The entry page clearly identifies this as a fictional product demo. Choose **Enter Admin Demo** or **Enter Teacher Demo** to open the respective workspace. No login form, password, CAPTCHA or OTP is requested. Old preview URLs redirect to `login.html`.

## Explore

- Admin: Overview → Verification → review corrections → Class records → verify completed sessions → Payroll → calculate 12–18 October 2026 → inspect/adjust → approve → Payment history → record a fictional payment.
- Teacher: select Choose demo role, then Enter Teacher Demo. Check in/out of assigned classes, view personal class records, submit corrections and see approved payments.
- Teachers: add demo profiles, add hourly rate versions and activate/deactivate profiles.
- Classes: add subjects and edit teacher assignments.
- Activity log: inspect the history of demo changes.
- Reset demo data: restore all fictional records.

Workspace changes persist only in this browser's localStorage. Demo role state uses sessionStorage and is cleared with Choose demo role. No credentials or verification codes are collected. This is client-side simulation, not secure authentication or real access enforcement. Live check-in/out uses the browser clock, whereas production would need server timestamps. Profile contact details and all payment references are fictional. No funds are transferred.

## Files

- `dist/index.html`: application shell and dialog container.
- `dist/login.html`: fictional demo workspace selector.
- `dist/assets/login.js`: browser-only demo role selection.
- `dist/assets/auth-guard.js`: browser-only demo session routing; not production access control.
- `dist/assets/styles.css`: responsive visual design.
- `dist/assets/tailwind-browser.js`: vendored Tailwind browser runtime v4.1.18.
- `dist/assets/jquery.min.js`: vendored jQuery v3.7.1, retaining its license header.
- `dist/assets/core.js`: in-memory/browser demo interactions and sample data; no database.
- `dist/assets/app.js`: jQuery views, modal forms, navigation and events.
- `dist/assets/jquery-ui.min.js` and `jquery-ui.min.css`: vendored jQuery UI 1.14.2 from the official jQuery CDN.
- `dist/assets/controls.js` and `controls.css`: Selectmenu enhancement, consistent inputs and keyboard-only focus outlines. Dropdowns preserve the original select value for form submission and change events. Hover adds no outline; keyboard focus and validation feedback remain visible. Dialogs use the single footer dismiss action instead of a duplicate top-corner close button.
- `tests.cjs`: deterministic checks of meaningful prototype interactions. Run `node tests.cjs`.

Teacher self-service, Admin-only approval, actual minutes × hourly MMK rate, manual payment records and no CSV/import/export match the approved scope. The UI does not include password reset, production permission enforcement, real backups or production monitoring.

The initial sample has two class records awaiting verification and two pending corrections. After verifying S0001/S0002, the base fixture is 785 minutes / 147,000 MMK. After approving both pending corrections and verifying the affected sessions, it is 980 minutes / 182,500 MMK.

Prototype policy controls are intentionally simpler than production: class assignments use current selections rather than dated intervals, and long-duration exceptions are acknowledged with an Admin review reason. The prototype is intended for product and interaction review.

## Live website

[SayaSync live demo](https://sayasync.netlify.app/login.html)

The final demo opens without email, password, CAPTCHA or OTP. The updated prototype is hosted on Netlify at the same stable URL. Choose Enter Admin Demo or Enter Teacher Demo.

## Security configuration

`vercel.json` configures CSP, anti-framing, MIME sniffing protection, referrer and permissions policies for Vercel. The static Python preview does not apply these HTTP headers. The CSP allows inline styles for the existing Tailwind browser runtime and jQuery UI, but restricts scripts to this origin and blocks outbound connections, form submissions, embedding and plugins. The same header policy was checked in a local static preview before publishing. These headers do not remove a Google Safe Browsing classification; investigate Search Console Security Issues and request review after addressing the reported cause.

## Updated prototype

Includes revised navigation, review inbox, payroll flows, date picker and accessibility refinements. All data remains fictional and browser-local; no Supabase backend is connected. Legacy preview URLs redirect without inline scripts. Netlify production entry: [SayaSync demo](https://sayasync.netlify.app/login.html).
