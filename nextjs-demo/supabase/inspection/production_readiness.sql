-- READ ONLY. Run against the confirmed project, save output privately.
-- No credentials, Auth rows, teaching details or financial contents are selected.
begin transaction read only;
select current_database() as database_name, current_setting('server_version') as postgres_version;
select n.nspname as schema_name,c.relname as relation,c.relkind,c.relrowsecurity,c.relforcerowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','sayasync_private') and c.relkind in ('r','p','v','m','S') order by 1,2;
select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
from pg_policies where schemaname in ('public','sayasync_private') order by 1,2,3;
select n.nspname as schema_name,p.proname,pg_get_function_identity_arguments(p.oid) as arguments,
p.prosecdef as security_definer,p.proconfig,md5(pg_get_functiondef(p.oid)) as definition_md5,p.proacl
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','sayasync_private') order by 1,2,3;
select n.nspname as schema_name,c.relname as relation,t.tgname,pg_get_triggerdef(t.oid) as definition
from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
where not t.tgisinternal and n.nspname in ('public','sayasync_private','auth') order by 1,2,3;
select table_schema,table_name,grantee,privilege_type from information_schema.role_table_grants
where table_schema in ('public','sayasync_private') order by 1,2,3,4;
select n.nspname as schema_name,c.relname as relation,co.conname,pg_get_constraintdef(co.oid) as definition
from pg_constraint co join pg_class c on c.oid=co.conrelid join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','sayasync_private') order by 1,2,3;
select schemaname,tablename,indexname,indexdef from pg_indexes where schemaname in ('public','sayasync_private') order by 1,2,3;
select to_regclass('supabase_migrations.schema_migrations') as migration_history_relation;
-- Inspect versions in that table only if it exists. Do not mark anything applied yet.
commit;
