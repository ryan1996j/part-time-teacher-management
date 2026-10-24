# Native React migration — entry slice

Completed locally:
- /login is native React JSX with no iframe and no jQuery scripts.
- Existing stylesheet assets, logo, visible text, 44px buttons and demo identity remain unchanged.
- Admin entry -> /admin/overview; Teacher entry -> /teacher/home.
- Compatibility workspace sign-out returns to native /login.
- Compared entry heading and both button geometry against legacy page at the same viewport: exact match.
- Production build and TypeScript compile pass.
- Baseline assets remain byte-for-byte unchanged.

Still pending: native React workspace shell, overview, records, review, teacher/class management, payroll/payment/audit screens; compiled Tailwind replacement; native workspace route/filter migration; Supabase authentication/data/permissions. The iframe remains on workspace routes only. This is not a completed migration or production authentication.

No original repo files, database, GitHub branch, remote commits or hosting settings changed. No push or deployment.
