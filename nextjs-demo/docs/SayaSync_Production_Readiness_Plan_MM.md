# SayaSync Production Readiness — 2026-10-26

> Update2026-10-27: Development isolation/setup and owner Admin login completed. See ENVIRONMENTS.md for current status. The preparation notes below remain historical; backup/restore and CLI history reconciliation remain pending.

## လက်ရှိအခြေအနေ

- Production UI: https://sayasync.netlify.app/login; main commit d2f45d14649de46898118e601eddfa3664d9921d, Netlify deploy6adeb8ddb2c42d4ddeeb2373။ Owner acceptance ပြီးထားသည်။
- Live နှင့် local သည် ereyjhtkypeowifrmyqv project ကို မျှဝေသုံးနေသည်။ Development ဟု ခေါ်ခဲ့သော်လည်း live financial records ရှိနေသဖြင့် လက်ရှိတွင် production-impacting database အဖြစ် သတ်မှတ်ထိန်းသိမ်းရန်။
- Local migrations001–010 manual application ကို notes တွင် မှတ်တမ်းတင်ထားသည်။ Remote migration history/catalog ကို အသစ်ပြန်မစစ်ရသေး။ Files ရှိခြင်းသည် remote schema တူကြောင်း အထောက်အထားမဟုတ်။
- Browser automation မရသေး။ CLI/pg_dump/psql ကို လက်ရှိ PATH တွင်မတွေ့။ Supabase plan၊ backup retention/PITR၊ quotas ကို မအတည်ပြုရသေး။
- Production Auth site/redirect URLs ကို ပြန်စစ်ရမည်။ နောက်ဆုံး notes တွင် local invitation callback သတ်မှတ်ထားသည်။ Existing callback သည် invite token ကိုသာ လက်ခံသည်။ Password recovery flow implemented ဟု မသတ်မှတ်ရ။

## အကြံပြု environment ခွဲခြားပုံ

Owner ရွေးချယ်မှု pending: လက်ရှိ database ကို production အဖြစ် ထိန်းပြီး schema-only development project အသစ် ဖန်တီးရန် အကြံပြုသည်။ Live users/IDs/payment history ကို ပြောင်းရွှေ့စရာမလို။ Production အသစ်ရွေးပါက သီးခြား migration/cutover plan လိုပြီး ယခုအစီအစဉ်ဖြင့် အလိုအလျောက် data မရွှေ့ရ။

| Environment | App | Database | Data |
|---|---|---|---|
| Production | sayasync.netlify.app | existing project (owner decision pending) | လက်ရှိ school/identity/payroll/payment history |
| Development | localhost | project အသစ်၊ ID မသတ်မှတ်ရသေး | schema နှင့် သီးခြား synthetic fixtures only |
| Deploy preview | Netlify preview | development project only | production credentials/data မသုံးရ |

Project အသစ်၏ region/plan/quota/cost ကို မဖန်တီးမီ စစ်ရန်။ Production users၊ password hashes၊ sessions နှင့် payment rows ကို dev သို့ မကူးရန်။ Test Admin/Teacher accounts ကို သီးခြားဖန်တီးပြီး recipient ကိုယ်တိုင် password သတ်မှတ်ရန်။

## ဆောင်ရွက်မည့်အဆင့်များနှင့် exit criteria

### 1. Inventory နှင့် backup အရင်

`supabase/inspection/production_readiness.sql` ကို အတည်ပြုပြီး target project တွင် read-only run လုပ်ရန်။ Output ကို private location တွင်ထားရန်။ Tables/views/RLS/grants/functions/search_path/triggers/constraints/indexes နှင့် migration history ရှိမရှိ စစ်မည်။ User/payment rows မရွေးထား။ Function catalog hash တစ်ခုတည်းနှင့် expected migrations တူကြောင်း မဆုံးဖြတ်ရ။ Fresh temporary schema replay နှင့် structural comparison ထပ်လိုသည်။

`docs/migration-inventory-2026-10-26.json` တွင် local SQL files နှင့် SHA256 ရှိသည်။ မူရင်း applied files ကို ပြန်မရေးရ။ CLI version ကို official source မှ pin ပြီး install၊ target identity ကို အမြဲစစ်ရန်။ DB password/token ကို chat/log/source ထဲမထည့်ရ။ Owner secure credential entry လိုအပ်သည်။

**Exit:** private backup artifacts၊ checksums၊ backup scope နှင့် encryption/access owner အတည်ပြုထားခြင်း။ Inventory query execution နှင့် actual backup သည် ယခု pending ဖြစ်သည်။

### 2. Backup/restore runbook

- Owner proposal: daily backup၊ deployment/migration မတိုင်မီ backup၊ encrypted off-site copy၊ daily14 copies နှင့် monthly3 copies ထိန်းရန်။ Storage budget/data-retention policy အတည်ပြုချက်လို။ Provider backup retention သည် subscription အပေါ်မူတည်ပြီး မအတည်ပြုရသေး။
- Proposed RPO24h/RTO4h ဖြစ်သော်လည်း restore drill အချိန်တိုင်းပြီး owner လက်ခံမှ commitment ဖြစ်မည်။ School payroll requirements က ပိုတင်းကျပ်ပါက PITR eligibility/cost ကို စစ်ပြီး ဆုံးဖြတ်ရန်။
- Schema-only dump မလုံလောက်။ Application schema/data၊ private schema/ledgers၊ sequences/roles/grants၊ required Auth records/custom Auth trigger၊ migration history နှင့် project-specific platform settings scope ကို official restore workflow နှင့်စစ်ရန်။ Auth backup တွင် sensitive password hashes/tokens ပါနိုင်သဖြင့် credential ကဲ့သို့ ကာကွယ်ရန်။
- DB backup တွင် Storage object bytes မပါနိုင်သဖြင့် Storage အသုံးပြုလျှင် သီးခြား object backup/inventory လို။ Auth provider/SMTP/redirect configuration၊ project/API secrets နှင့် Netlify configuration ကို DB dump မှ အလိုအလျောက်ရမည်ဟု မယူဆရ။
- Raw backups ကို repo၊ app/public၊ Netlify artifacts သို့မထည့်ရ။ Owner အတည်ပြုသော encrypted private destination မရှိမီ export မစတင်ရ။
- Restore drill ကို isolated recovery target တွင်လုပ်မည်၊ normal development project နှင့်မရောရ။ Outbound invitation/SMTP/integrations ကို isolate လုပ်ပြီး production clients မချိတ်ရ။
- Restore ပြီး table counts၊ school/teacher/auth links၊ approved frozen snapshots/allocations၊ adjustment/payment receipts၊ audit/idempotency၊ sequences/constraints/RLS နှင့် role isolation ကို စစ်မည်။ လက်ရှိ approved total/paid total ကို reconciliation လုပ်မည်။ Fresh local test fixtures ဖြင့် test suite စမ်းမည်။
- Actual production restore သည် writes freeze၊ post-backup delta reconciliation၊ owner authorization နှင့် maintenance communication လိုသည်။ Restoring old backup သည် နောက်ပိုင်း real payments ကို ပျောက်စေနိုင်သည်။ Netlify rollback သည် database rollback မဟုတ်။

**Exit:** isolated restore အောင်မြင်သော evidence၊ elapsed time၊ recovery owner နှင့် rollback/cutover criteria ရှိခြင်း။

### 3. Migration history reconciliation

Production backup အရင်ယူပြီး disposable clean environment တွင်001–010 ကို replay/test လုပ်မည်။ Applied catalog နှင့် compare လုပ်ပြီး drift ရှိလျှင် additive corrective migration သီးခြားရေးရန်။ Dashboard changes ကို ဖုံးကွယ်ရန် history mark မလုပ်ရ။

Existing remote history table/version list ကိုဖတ်ပြီး၊ migration တစ်ခုချင်းစီ effects အတိအကျရှိကြောင်း အတည်ပြုပြီးမှ supported `migration repair --status applied` ကို owner-reviewed scope ဖြင့်သုံးမည်။ Repair သည် history bookkeeping ဖြစ်ပြီး SQL execute/repair မလုပ်ပေး။ Command ကို ယခု run မထား။ Remote `db reset`၊ blind `db push` သို့မဟုတ် already-applied migration replay မလုပ်ရ။

**Exit:** actual remote history နှင့် tested migrations တူပြီး clean environment မှ schema reproducible ဖြစ်ခြင်း။

### 4. Development project setup

Owner ရွေးချယ်မှုနှင့် cost/quota အတည်ပြုပြီး project အသစ်ဖန်တီးရန်။ Confirmed schema-only migrations apply လုပ်ပြီး separate test identities/seed သုံးရန်။ No real finance data copied. Local `.env.local` ကို development URL/publishable key သို့ပြောင်း၍ fresh sign-in နှင့် local school/Teacher isolation စစ်ရန်။ Existing local cookie/session က production identity ဖြစ်နိုင်သဖြင့် local logout/re-auth ကို စစ်ရန်။ Production secret/service-role key ကို browser env ထဲမထည့်ရ။

**Exit:** local feature writes သည် development DB ထဲသာဝင်ပြီး production counts/records မပြောင်းကြောင်း owner-confirmed read checks။

### 5. Netlify/Auth environment mapping

Netlify Production context ကို existing production public URL/key နှင့်သာ map၊ deploy-preview/branch context ကို development project သို့ scope လုပ်ရန်။ Preview setting မရှိလျှင် production value inherit မဖြစ်ကြောင်း စစ်ရန်။ Public Supabase values သည် build-time client bundles ထဲပါသဖြင့် environment ပြောင်းပြီး rebuild လိုသည်။

Production Site URL/allowed redirects ကို exact live callback နှင့် align လုပ်ရန်။ Existing invite callback ကို invitation end-to-end test စစ်ပြီးမှ email ပို့ရန်။ Recovery callback မရှိသေးသဖြင့် redirect setting ပြောင်းရုံဖြင့် password recovery implemented မဖြစ်။ Environment အချင်းချင်း redirect/token မရောစေရ။ Public signup disabled နှင့် verified active membership/Teacher-link guards ကို ထိန်းရန်။

**Exit:** owner-controlled invitation acceptance၊ role isolation၊ logout/cache၊ no credential leakage၊ preview/prod separation ပြီးခြင်း။ Actual settings change သည် concrete reviewed approval အဆင့်လိုသည်။

### 6. Release gate နှင့် operations

Backup evidence → tested additive migration → application build/tests → explicit release approval → main merge/deploy → public/role smoke checks → owner financial reconciliation။ CI automatic DB push ကို history reconciliation မပြီးမီမထည့်ရ။ DB changes/backups require trusted separate deployment credentials; browser keys က permissions မလုံလောက်။

Owner proposal: service availability/errors/backup failures/slow report monitoring။ Sensitive teacher/email/receipt values ကို logs ထဲမထည့်ရ။ ယခု monitoring automation/paid service မဖန်တီးထား။ Alerts recipient နှင့် policy သီးခြားဆုံးဖြတ်ရန်။

## ယခုလုပ်ပြီးသောအရာ

Source/config inspection၊ local migration hash inventory နှင့် read-only SQL file၊ ဒီ runbook ကိုသာ ပြင်ဆင်ထားသည်။ UI/code behavior မပြောင်း။ Database/project/Auth/Netlify settings မပြောင်း။ Backup/restore/history repair မလုပ်။ Commit/push/deploy မလုပ်။

## ဆက်ရန်လိုအပ်ချက်

1. Existing project ကို production ထားပြီး development project အသစ်လုပ်မလားဆိုသော owner decision။
2. Supabase dashboard မှ current plan/quota နှင့် available backups စစ်ရန် owner access၊ private encrypted backup destination ဆုံးဖြတ်ရန်။
3. Browser tool မရသေးသဖြင့် dashboard ကို owner လုပ်ဆောင်ရခြင်း သို့မဟုတ် tool ပြန်ရမှ authenticated inventory ဆက်လုပ်ရခြင်း။ Password/token ကို chat မပို့ရန်။

## Official references (checked 2026-10-26)

- https://supabase.com/docs/guides/deployment/managing-environments
- https://supabase.com/docs/guides/deployment/database-migrations
- https://supabase.com/docs/guides/platform/backups
- https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
