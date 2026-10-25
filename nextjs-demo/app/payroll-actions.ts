'use server';
import {requireWorkspace} from '../lib/auth';
import {createClient} from '../lib/supabase/server';
import {validPeriodDate,validAdjustmentAmount,type PayrollData,type PayrollDraft,type DraftOption} from '../lib/payroll-types';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function readPayrollDrafts(input:{id?:string|null;page?:number}={}):Promise<PayrollData>{
 const access=await requireWorkspace('admin'),client=await createClient();
 const page=Number.isSafeInteger(input.page)&&Number(input.page)>0&&Number(input.page)<100000?Number(input.page):1;
 if(input.id!==undefined&&input.id!==null&&!uuid.test(input.id))throw new Error('Invalid payroll draft.');
 const [list,clock]=await Promise.all([
  client.from('payroll_drafts').select('id,code,period_start,period_end,status,version,calculated_at',{count:'exact'}).eq('school_id',access.schoolId).order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25-1),
  client.rpc('teaching_server_time'),
 ]);
 if(list.error||clock.error||!clock.data)throw new Error('Unable to load payroll drafts. Please retry.');
 const drafts=(list.data||[]) as DraftOption[],id=input.id===undefined?drafts[0]?.id:input.id;
 let selected:PayrollDraft|null=null,stale=false;
 if(id){const result=await client.rpc('payroll_draft_state',{p_school:access.schoolId,p_id:id});if(result.error)throw new Error('Unable to check payroll draft freshness. Please retry.');selected=result.data.draft as PayrollDraft;stale=!!result.data.stale;}
 const teachers:{id:string;name:string;code:number}[]=[];
 for(let offset=0;;offset+=1000){const rows=await client.from('teachers').select('id,name,code').eq('school_id',access.schoolId).order('id').range(offset,offset+999);if(rows.error)throw new Error('Unable to load teachers.');teachers.push(...(rows.data||[]));if(!rows.data||rows.data.length<1000)break;}
 return {drafts,selected,stale,page,total:list.count||0,serverNow:String(clock.data),teachers};
}
export async function calculatePayrollDraft(input:{id?:string;version?:number;start:string;end:string},requestId:string){
 const access=await requireWorkspace('admin');
 if(!input||typeof input!=='object'||!uuid.test(requestId)||!validPeriodDate(input.start)||!validPeriodDate(input.end)||input.start>input.end)return {error:'Choose a valid start and end date.'};
 if(input.id&&(!uuid.test(input.id)||!Number.isSafeInteger(input.version)||Number(input.version)<1))return {error:'Refresh the draft before recalculating.'};
 const payload:Record<string,unknown>={period_start:input.start,period_end:input.end};if(input.id){payload.id=input.id;payload.version=input.version;}
 try{
  const result=await (await createClient()).rpc('calculate_payroll_draft',{p_school:access.schoolId,p_request:requestId,p_payload:payload});
  if(result.error){const allowed=['Choose a valid payroll period','Draft changed. Refresh before recalculating.','Choose New draft to calculate another period','Approved payroll is immutable'];return {error:allowed.includes(result.error.message)?result.error.message:'Unable to calculate the draft. Refresh and check your account and period.'};}
  return {ok:true,id:String(result.data.id)};
 }catch{return {error:'Unable to confirm calculation. Retry unchanged values safely or refresh to check saved drafts.'};}
}
export async function managePayrollApproval(command:string,input:Record<string,unknown>,requestId:string){
 const access=await requireWorkspace('admin');
 if(!input||typeof input!=='object'||!['add_adjustment','withdraw_adjustment','approve'].includes(command)||!uuid.test(requestId)||typeof input.id!=='string'||!uuid.test(input.id)||!Number.isSafeInteger(input.version)||Number(input.version)<1)return {error:'Refresh the payroll before continuing.'};
 const reason=typeof input.reason==='string'?input.reason.trim():'';
 if(reason.length>1000||command!=='approve'&&!reason)return {error:'Enter a reason (up to 1000 characters).'};
 const payload:Record<string,unknown>={id:input.id,version:input.version,reason};
 if(command==='add_adjustment'){
  if(typeof input.teacher_id!=='string'||!uuid.test(input.teacher_id)||!validAdjustmentAmount(input.amount))return {error:'Select a teacher and enter a non-zero whole MMK amount within the supported integer range.'};
  payload.teacher_id=input.teacher_id;payload.amount=BigInt(input.amount).toString();payload.reference=typeof input.reference==='string'?input.reference.trim():'';
  if(String(payload.reference).length>200)return {error:'Reference must be at most 200 characters.'};
 }
 if(command==='withdraw_adjustment'){if(typeof input.adjustment_id!=='string'||!uuid.test(input.adjustment_id))return {error:'Refresh the adjustment.'};payload.adjustment_id=input.adjustment_id;}
 try{
  const result=await (await createClient()).rpc('manage_payroll_approval',{p_school:access.schoolId,p_request:requestId,p_command:command,p_payload:payload});
  if(result.error){const messages=['Approved payroll is immutable','Payroll changed. Refresh before continuing.','Draft is stale. Recalculate before approval.','There are no eligible sessions or adjustments to approve','A teacher net amount is negative. Review adjustments before approval','Active adjustment not found','Select a teacher in this school','Enter a non-zero whole MMK adjustment and reason','Enter a withdrawal reason'];return {error:messages.includes(result.error.message)?result.error.message:result.error.code==='23505'?'A session is already allocated. Refresh and recalculate the draft.':'Unable to save the payroll action. Refresh and check access and values.'};}
  return {ok:true,id:String(result.data.id)};
 }catch{return {error:'Unable to confirm the save. Retry unchanged values safely or refresh before another action.'};}
}
