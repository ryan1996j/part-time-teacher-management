'use server';
import {requireSchoolAccess} from '../lib/auth';
import {createClient} from '../lib/supabase/server';
import {yangonInputToISO} from '../lib/teaching-types';
import type {CorrectionData,CorrectionRecord} from '../lib/review-types';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function readCorrections(input:{page?:number;filter?:string}={}):Promise<CorrectionData>{
 const access=await requireSchoolAccess(),client=await createClient();
 const page=Number.isSafeInteger(input.page)&&Number(input.page)>0&&Number(input.page)<100000?Number(input.page):1;
 const filter=['Pending','Approved','Rejected','Withdrawn'].includes(input.filter||'')?input.filter!:'';
 let query=client.from('correction_records').select('*',{count:'exact'}).eq('school_id',access.schoolId);
 if(filter)query=query.eq('status',filter);
 const result=await query.order('created_at',{ascending:false}).order('id').range((page-1)*25,page*25-1);
 if(result.error)throw new Error('Unable to load correction requests. Please retry.');
 const {data:{user}}=await client.auth.getUser();
 return {role:access.role,teacher:access.teacher,actor:user!.id,records:(result.data||[]) as CorrectionRecord[],total:result.count||0,page,filter};
}
export async function readSessionHistory(id:string){
 const access=await requireSchoolAccess();if(!uuid.test(id))throw new Error('Invalid class record');
 const client=await createClient();
 const [requests,events]=await Promise.all([
  client.from('correction_records').select('*').eq('school_id',access.schoolId).eq('session_id',id).order('created_at',{ascending:false}).limit(50),
  client.from('session_events').select('id,action,reason,actor_id,created_at').eq('school_id',access.schoolId).eq('session_id',id).order('created_at',{ascending:false}).limit(50)
 ]);
 if(requests.error||events.error)throw new Error('Unable to load record history.');
 return {corrections:(requests.data||[]) as CorrectionRecord[],events:events.data||[]};
}
export async function reviewTeaching(command:string,input:Record<string,unknown>,requestId:string){
 const access=await requireSchoolAccess();
 if(!uuid.test(requestId)||!input||typeof input!=='object'||Array.isArray(input)||!['request_correction','withdraw_correction','review_correction','verify_session'].includes(command))return {error:'Invalid review request.'};
 if(['review_correction','verify_session'].includes(command)&&access.role!=='admin')return {error:'Administrator access required.'};
 if(typeof input.id!=='string'||!uuid.test(input.id)||!Number.isSafeInteger(input.version)||Number(input.version)<1)return {error:'Refresh the record before continuing.'};
 const reason=typeof input.reason==='string'?input.reason.trim():'';
 if(reason.length>1000)return {error:'Reason must be at most 1000 characters.'};
 const payload:Record<string,unknown>={id:input.id,version:input.version,reason};
 try{
  if(command==='request_correction'){
   if(!reason)return {error:'Enter a correction reason.'};
   payload.start_at=yangonInputToISO(String(input.start||''));payload.end_at=yangonInputToISO(String(input.end||''));
  }
  if(command==='review_correction'||command==='verify_session'){
   const allowed=command==='review_correction'?['Approved','Rejected']:['Verified','Rejected'];
   if(typeof input.decision!=='string'||!allowed.includes(input.decision))return {error:'Choose a valid review decision.'};
   payload.decision=input.decision;
   if(command==='review_correction'){if(!Number.isSafeInteger(input.session_version))return {error:'Refresh the class record.'};payload.session_version=input.session_version;}
  }
  const result=await (await createClient()).rpc('review_teaching_session',{p_school:access.schoolId,p_request:requestId,p_command:command,p_payload:payload});
  if(result.error){
   const messages=['This class record is locked by approved payroll','Record changed. Refresh before continuing.','Request changed. Refresh before continuing.','Record changed. Reject or withdraw the stale request and submit a new correction.','A correction is already pending for this class record','Enter completed times (at least one minute) and a reason','Proposed times must differ from the current record','Enter a rejection reason','An assignment must cover the corrected start time','Resolve the pending correction before reviewing this class record','Only completed records with at least one minute can be verified','Resolve the class assignment before verification','Explain how the overlapping time was reviewed before verifying','Only the requester can withdraw this correction'];
   return {error:messages.includes(result.error.message)?result.error.message:result.error.code==='23505'?'A matching record or pending correction already exists. Refresh before retrying.':'Unable to save the review. Refresh and check your access and values.'};
  }
  return {ok:true};
 }catch(error){return {error:error instanceof Error?error.message:'Unable to confirm the save. Retry unchanged values safely.'};}
}
