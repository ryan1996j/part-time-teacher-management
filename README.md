# Ai14 EduControl UI prototype

Approved PRD v0.3 implemented as a browser-only interactive prototype using **HTML, Tailwind CSS and jQuery**. No backend, API, database, real authentication, account invitation or payment processing is included.

## Open

Open `dist/index.html` directly in your browser. Tailwind and jQuery are included locally, so no installation or internet connection is needed. Alternatively, serve `dist` with any static web server. The source is buildless.

## Explore

- Admin: Overview → Verification → review corrections → Class records → verify completed sessions → Payroll → calculate 12–18 October 2026 → inspect/adjust → approve → Payment history → record a fictional payment.
- Teacher: use **View as → Teacher**. The teacher selector lets you explore each fictional account. Check in/out of assigned classes, view personal class records, submit corrections and see approved payments.
- Teachers: add demo profiles, add hourly rate versions and activate/deactivate profiles.
- Classes: add subjects and edit teacher assignments.
- Activity log: inspect the history of demo changes.
- Reset demo data: restore all fictional records.

Changes persist only in this browser's localStorage. Demo role switching does not provide security. Live check-in/out uses the browser clock, whereas production would need server timestamps. Profile contact details and all payment references are fictional. No funds are transferred.

## Files

- `dist/index.html`: application shell and dialog container.
- `dist/assets/styles.css`: responsive visual design.
- `dist/assets/tailwind-browser.js`: vendored Tailwind browser runtime v4.1.18.
- `dist/assets/jquery.min.js`: vendored jQuery v3.7.1, retaining its license header.
- `dist/assets/core.js`: in-memory/browser demo interactions and sample data; no database.
- `dist/assets/app.js`: jQuery views, modal forms, navigation and events.
- `tests.cjs`: deterministic checks of meaningful prototype interactions. Run `node tests.cjs`.

Teacher self-service, Admin-only approval, actual minutes × hourly MMK rate, manual payment records and no CSV/import/export match the approved scope. The UI does not include password reset, production permission enforcement, real backups or production monitoring.

The initial sample has two class records awaiting verification and two pending corrections. After verifying S0001/S0002, the base fixture is 785 minutes / 147,000 MMK. After approving both pending corrections and verifying the affected sessions, it is 980 minutes / 182,500 MMK.

Prototype policy controls are intentionally simpler than production: class assignments use current selections rather than dated intervals, and long-duration exceptions are acknowledged with an Admin review reason. The prototype is intended for product and interaction review.
