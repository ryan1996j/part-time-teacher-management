-- Run only in development project tdrwggtpmzgazyceqeym SQL Editor.
-- Read-only metadata/counts. Do not run migrations until the result is reviewed.
begin transaction read only;
select n.nspname as schema_name,c.relname as relation,c.relkind,c.relrowsecurity as rls_enabled
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','sayasync_private','supabase_migrations')
and c.relkind in ('r','p','v','m','S') order by 1,2;
select count(*) as auth_user_count from auth.users;
select to_regclass('supabase_migrations.schema_migrations') as migration_history;
commit;
