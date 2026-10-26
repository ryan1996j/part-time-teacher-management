 'use server';
import {requireWorkspace} from '../lib/auth';
import {createClient} from '../lib/supabase/server';
import {approvedReportRows} from '../lib/report-server';
import {filterReport,financeTotals,reportCsv,type ReportFilters,type ReportData} from '../lib/report-data';
import {validPeriodDate} from '../lib/payroll-types';
function filters(input:Partial<ReportFilters>):ReportFilters {
 const f={start:input.start||'',end:input.end||'',teacher:input.teacher||'',status:input.status||''};
 if((f.start&&!validPeriodDate(f.start))||(f.end&&!validPeriodDate(f.end))||(f.start&&f.end&&f.start>f.end)||(f.teacher&&!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(f.teacher))||!['','Paid','Not paid'].includes(f.status))throw new Error('Invalid report filters.');return f;
}
export async function readReports(input:Partial<ReportFilters>&{page?:number}={}):Promise<ReportData>{
 const access=await requireWorkspace('admin'),f=filters(input),rows=filterReport(await approvedReportRows(),f),client=await createClient();
 const teachers:{id:string;name:string;code:number}[]=[];
 for(let start=0;;start+=1000){const result=await client.from('teachers').select('id,name,code').eq('school_id',access.schoolId).order('id').range(start,start+999);if(result.error)throw new Error('Unable to load report filters.');teachers.push(...(result.data||[]));if((result.data||[]).length<1000)break;}
 const page=Number.isSafeInteger(input.page)&&Number(input.page)>0?Math.min(Number(input.page),Math.max(1,Math.ceil(rows.length/25))):1;
 return {records:rows.slice((page-1)*25,page*25),totals:financeTotals(rows),filters:f,teachers,generatedAt:new Date().toISOString(),page,total:rows.length};
}
export async function exportReports(input:Partial<ReportFilters>){await requireWorkspace('admin');const f=filters(input);return reportCsv(filterReport(await approvedReportRows(),f));}
