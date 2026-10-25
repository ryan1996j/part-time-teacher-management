'use server';
import {requireSchoolAccess} from '../lib/auth';
import {createClient} from '../lib/supabase/server';
import {yangonInputToISO,assignedAt,type TeachingData,type TeachingRecord,type TeachingAssignment,type TeachingClass,type TeachingTeacher} from '../lib/teaching-types';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
async function readAll<T>(fetchPage:(start:number,end:number)=>PromiseLike<{data:unknown[]|null;error:unknown}>) {
 const rows:T[]=[];for(let start=0;;start+=1000){const page=await fetchPage(start,start+999);if(page.error)throw new Error('Unable to load teaching records. Please retry.');rows.push(...(page.data||[]) as T[]);if(!page.data||page.data.length<1000)return rows;}
}
export async function readTeachingWorkspace(input:{page?:number;filter?:string;query?:string}={}):Promise<TeachingData> {
 const access=await requireSchoolAccess();const client=await createClient();
 const page=Number.isSafeInteger(input.page)&&Number(input.page)>0&&Number(input.page)<100000?Number(input.page):1;
 const filter=['Pending','Verified','Rejected','In progress','Missing checkout'].includes(input.filter||'')?input.filter!:'';
 const search=typeof input.query==='string'?input.query.trim().slice(0,120):'';
 const clock=await client.rpc('teaching_server_time');if(clock.error||!clock.data)throw new Error('Server time is unavailable. Please refresh.');
 const serverNow=String(clock.data);
 let recordsQuery=client.from('session_records').select('*',{count:'exact'}).eq('school_id',access.schoolId);
 if(filter)recordsQuery=recordsQuery.eq('record_status',filter);
 if(search)recordsQuery=recordsQuery.ilike('search_text','%'+search.replace(/[%_\\]/g,'\\$&')+'%');
 const [records,open,classes,teachers,assignments]=await Promise.all([
  recordsQuery.order('start_at',{ascending:false}).order('id').range((page-1)*25,page*25-1),
  access.teacher?client.from('session_records').select('*').eq('school_id',access.schoolId).eq('teacher_id',access.teacher.id).is('end_at',null).maybeSingle():Promise.resolve({data:null,error:null}),
  readAll<TeachingClass>((a,b)=>client.from('classes').select('id,code,name,subject,active').eq('school_id',access.schoolId).eq('active',true).order('id').range(a,b)),
  access.role==='admin'?readAll<TeachingTeacher>((a,b)=>client.from('teachers').select('id,code,name,active').eq('school_id',access.schoolId).eq('active',true).order('id').range(a,b)):Promise.resolve([] as TeachingTeacher[]),
  readAll<TeachingAssignment>((a,b)=>client.from('teacher_assignments').select('id,teacher_id,class_id,effective_from,effective_to').eq('school_id',access.schoolId).order('id').range(a,b)),
 ]);
 if(records.error||open.error)throw new Error('Unable to load teaching records. Please retry.');
 const visibleClasses=access.teacher?classes.filter(c=>assignments.some(a=>assignedAt(a,access.teacher!.id,c.id,serverNow))):classes;
 return {role:access.role,teacher:access.teacher,serverNow,records:(records.data||[]) as TeachingRecord[],open:open.data as TeachingRecord|null,
  total:records.count||0,page,pageSize:25,filter,query:search,classes:visibleClasses,teachers,assignments};
}
export async function captureTeaching(command:string,input:Record<string,unknown>,requestId:string) {
 const access=await requireSchoolAccess();
 if(!uuid.test(requestId)||!input||typeof input!=='object'||Array.isArray(input))return {error:'Invalid capture request.'};
 if(!['check_in','check_out','admin_entry'].includes(command)||(command==='admin_entry'?access.role!=='admin':access.role!=='teacher'))return {error:'This action is not available for your account.'};
 const payload:Record<string,unknown>={};
 try{
  if(command==='check_in'||command==='admin_entry'){if(typeof input.class_id!=='string'||!uuid.test(input.class_id))return {error:'Choose an assigned class.'};payload.class_id=input.class_id;}
  if(command==='check_out'){
   if(typeof input.id!=='string'||!uuid.test(input.id)||!Number.isSafeInteger(input.version)||Number(input.version)<1)return {error:'Refresh your open class record before checking out.'};payload.id=input.id;payload.version=input.version;
  }
  if(command==='admin_entry'){
   if(typeof input.teacher_id!=='string'||!uuid.test(input.teacher_id))return {error:'Choose a teacher.'};
   const reason=typeof input.reason==='string'?input.reason.trim():'';if(!reason||reason.length>1000)return {error:'Enter an admin entry reason (up to 1000 characters).'};
   payload.teacher_id=input.teacher_id;payload.start_at=yangonInputToISO(String(input.start||''));payload.end_at=yangonInputToISO(String(input.end||''));payload.reason=reason;
  }
  const client=await createClient();const result=await client.rpc('capture_teaching_session',{p_school:access.schoolId,p_request:requestId,p_command:command,p_payload:payload});
  if(result.error){
   const allowed=['You already have an open teaching record','Select an active class assigned to your account','Teacher must have an active assignment at the teaching start time','Enter completed teaching times (at least one minute) and a reason','Teaching record changed. Refresh before checking out.'];
   if(allowed.includes(result.error.message))return {error:result.error.message};
   if(result.error.code==='23505')return {error:'This record already exists, or you already have an open class. Refresh your records.'};
   return {error:'Unable to save this teaching record. Refresh and check your access and values.'};
  }
  return {ok:true};
 }catch(error){return {error:error instanceof Error?error.message:'Unable to confirm the save. Retry unchanged values or refresh.'};}
}
