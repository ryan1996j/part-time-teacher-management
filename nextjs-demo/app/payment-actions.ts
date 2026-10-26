'use server';
import {requireSchoolAccess,requireWorkspace} from '../lib/auth';
import {createClient} from '../lib/supabase/server';
import {paymentMethods,type PaymentData,type PaymentSummary,type PaymentDetail} from '../lib/payment-types';
import {validPeriodDate} from '../lib/payroll-types';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function readPayments(input:{page?:number;status?:string;teacher?:string}={}):Promise<PaymentData>{
 const access=await requireSchoolAccess(),client=await createClient();
 const page=Number.isSafeInteger(input.page)&&Number(input.page)>0&&Number(input.page)<100000?Number(input.page):1;
 const status=['Paid','Not paid'].includes(input.status||'')?input.status!:'';
 const teacherFilter=input.teacher||'';if(teacherFilter&&!uuid.test(teacherFilter))throw new Error('Invalid teacher filter.');
 const [result,clock]=await Promise.all([
  client.rpc('read_teacher_payments',{p_school:access.schoolId,p_page:page,p_status:status,p_teacher:teacherFilter||null}),
  client.rpc('teaching_server_time'),
 ]);
 if(result.error||clock.error||!clock.data)throw new Error('Unable to load approved payments. Please retry.');
 const teachers:{id:string;name:string;code:number}[]=[];
 if(access.role==='admin')for(let start=0;;start+=1000){const rows=await client.from('teachers').select('id,name,code').eq('school_id',access.schoolId).order('id').range(start,start+999);if(rows.error)throw new Error('Unable to load teacher filters.');teachers.push(...(rows.data||[]));if(!rows.data||rows.data.length<1000)break;}
 return {role:access.role,teacher:access.teacher,teachers,records:result.data.records as PaymentSummary[],total:Number(result.data.total),page,status,teacherFilter,serverNow:String(clock.data)};
}
export async function readPaymentDetail(runId:string,teacherId:string):Promise<PaymentDetail>{
 const access=await requireSchoolAccess();if(!uuid.test(runId)||!uuid.test(teacherId))throw new Error('Invalid approved payroll.');
 const result=await (await createClient()).rpc('teacher_payment_detail',{p_school:access.schoolId,p_run:runId,p_teacher:teacherId});
 if(result.error)throw new Error('Unable to load this approved teacher payroll. Refresh and check your access.');
 return result.data as PaymentDetail;
}
export async function recordTeacherPayment(input:Record<string,unknown>,requestId:string){
 const access=await requireWorkspace('admin');
 if(!input||typeof input!=='object'||!uuid.test(requestId)||typeof input.run_id!=='string'||!uuid.test(input.run_id)||typeof input.teacher_id!=='string'||!uuid.test(input.teacher_id)||!Number.isSafeInteger(input.version)||Number(input.version)<1)return {error:'Refresh the approved payroll before recording payment.'};
 const reference=typeof input.reference==='string'?input.reference.trim():'';
 if(!validPeriodDate(input.paid_date)||typeof input.method!=='string'||!paymentMethods.includes(input.method)||!reference||reference.length>1000)return {error:'Enter a paid date, method and reference or receipt note (up to 1000 characters).'};
 const payload={run_id:input.run_id,teacher_id:input.teacher_id,version:input.version,paid_date:input.paid_date,method:input.method,reference};
 try{
  const result=await (await createClient()).rpc('record_teacher_payment',{p_school:access.schoolId,p_request:requestId,p_payload:payload});
  if(result.error){const allowed=['An approved payroll is required','Payroll changed. Refresh before recording payment.','Teacher has no included sessions or adjustments in this approved payroll','Payment is already recorded. Refresh the payment list.','Enter a valid paid date, method and reference or receipt note','Paid date cannot be in the future'];return {error:allowed.includes(result.error.message)?result.error.message:result.error.code==='23505'?'Payment is already recorded. Refresh the payment list.':'Unable to record payment. Refresh and check access and values.'};}
  return {ok:true};
 }catch{return {error:'Unable to confirm the save. Retry unchanged values safely, or refresh to check payment status.'};}
}
