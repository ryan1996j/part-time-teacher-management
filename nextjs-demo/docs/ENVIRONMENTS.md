# SayaSync environments

Updated2026-10-27. Branch: development. This branch does not change production main.

| Environment | Supabase project | App |
|---|---|---|
| Production | ereyjhtkypeowifrmyqv | https://sayasync.netlify.app/login |
| Development | tdrwggtpmzgazyceqeym | http://127.0.0.1:3002/login |

Configure your local ignored .env.local using the Development project URL and its publishable key. No key/password is included here. Existing production accounts are not copied; use separately authorized development accounts. Rebuild after changing NEXT_PUBLIC values, since they enter browser bundles at build time. Never put secret/service-role keys in browser configuration.

Development migrations001-010 were applied atomically to an empty target through the Supabase Dashboard. All eight rollback database suites passed. Public tables have RLS enabled, public signup is disabled, email confirmation is enabled, and the default invitation Site URL is http://127.0.0.1:3002/auth/accept-invite. Owner completed development Admin invitation/password/login; empty native Overview/Teachers verified. No production records copied.

The setup bundle under supabase/inspection is a one-time reviewed DEVELOPMENT-only artifact, not a new incremental migration. It has an empty-target guard. Do not replay it on the configured development database or production. Supabase CLI history is not reconciled in either project; inspect before db push or history repair. No automatic migration deploy was added. Original migration hashes are recorded in docs/migration-inventory-2026-10-26.json.

Netlify Production settings remain unchanged. Deploy-preview/branch environment separation is still pending: do not rely on a branch name alone to isolate database access. Confirm preview context uses Development values before using previews for writes. This push requests no production deployment.

Production backup/restore drill and migration history reconciliation are still pending. The readiness plan is the preparation runbook; newer execution status in this file supersedes its pre-setup inventory. No production backup has been taken by these scripts.
