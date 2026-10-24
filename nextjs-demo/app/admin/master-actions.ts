'use server';
import {requireWorkspace} from '../../lib/auth';
import {createClient} from '../../lib/supabase/server';
import type {MasterData,DbTeacher,DbClass,DbRate,DbAssignment} from '../../lib/master-data';

async function allRows<T>(fetchPage:(start:number,end:number)=>PromiseLike<{data:unknown[]|null;error:unknown}>) {
  const rows:T[]=[];
  for(let start=0;;start+=1000){const page=await fetchPage(start,start+999);if(page.error)throw new Error('Unable to load school records. Please retry.');rows.push(...(page.data||[]) as T[]);if(!page.data||page.data.length<1000)return rows;}
}
export async function readMasterData():Promise<MasterData> {
  const {schoolId}=await requireWorkspace('admin');const client=await createClient();
  const [teachers,classes,rates,assignments,accounts]=await Promise.all([
    allRows<DbTeacher>((a,b)=>client.from('teachers').select('id,code,name,email,active,version,user_id').eq('school_id',schoolId).order('id').range(a,b)),
    allRows<DbClass>((a,b)=>client.from('classes').select('id,code,name,subject,active,version').eq('school_id',schoolId).order('id').range(a,b)),
    allRows<DbRate>((a,b)=>client.from('teacher_rates').select('id,teacher_id,effective_from,hourly_mmk').eq('school_id',schoolId).order('id').range(a,b)),
    allRows<DbAssignment>((a,b)=>client.from('teacher_assignments').select('id,teacher_id,class_id,effective_from').eq('school_id',schoolId).is('effective_to',null).order('id').range(a,b)),
    client.rpc('teacher_account_states',{p_school:schoolId}),
  ]);
  if(accounts.error)throw new Error('Unable to load teacher account access. Please retry.');
  const states=new Map<string,string>((accounts.data||[]).map((row:{teacher_id:string;account_state:string})=>[row.teacher_id,row.account_state]));
  return {teachers:teachers.map(t=>({...t,account_state:states.get(t.id)||'not_linked'})).sort((a,b)=>a.code-b.code),classes:classes.sort((a,b)=>a.code-b.code),rates,assignments};
}
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const commands=['create_teacher','create_class','add_rate','teacher_status','class_status','teacher_assignments','class_assignments'];
export async function linkTeacherAccount(id:string,version:number,requestId:string,reason:string) {
 const {schoolId}=await requireWorkspace('admin');
 if(!uuid.test(id)||!uuid.test(requestId)||!Number.isSafeInteger(version)||version<1||typeof reason!=='string'||!reason.trim()||reason.trim().length>1000)return {error:'Reload this teacher and enter a reason.'};
 const client=await createClient();
 const result=await client.rpc('link_teacher_account',{p_school:schoolId,p_teacher:id,p_version:version,p_request:requestId,p_reason:reason.trim()});
 if(result.error){
  if(result.error.code==='40001')return {error:'Teacher changed. Close this form and refresh before linking.'};
  if(result.error.message==='The project owner must invite this exact email first')return {error:'The project owner must send an invitation to this exact email before linking.'};
  return {error:'Account cannot be linked automatically. Ask the project owner to review the invitation, existing access and profile email.'};
 }
 return {ok:true};
}
export async function saveMasterData(command:string,input:Record<string,unknown>,requestId:string) {
  const {schoolId}=await requireWorkspace('admin');
  if(!commands.includes(command)||!uuid.test(requestId)||!input||typeof input!=='object'||Array.isArray(input))return {error:'Invalid request. Reload and try again.'};
  const payload:Record<string,unknown>={};
  try {
    const text=(key:string,max:number)=>{const value=typeof input[key]==='string'?(input[key] as string).trim():'';if(!value||value.length>max)throw new Error(`Enter a valid ${key}.`);return value;};
    payload.reason=text('reason',1000);
    if(!command.startsWith('create_')){const id=text('id',36);if(!uuid.test(id)||!Number.isSafeInteger(input.version)||Number(input.version)<1)throw new Error('Reload this record before saving.');payload.id=id;payload.version=input.version;}
    if(command==='create_teacher'||command==='create_class')payload.name=text('name',160);
    if(command==='create_class')payload.subject=text('subject',160);
    if(command==='create_teacher'){const email=text('email',254).toLowerCase();if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))throw new Error('Enter a valid email address.');payload.email=email;}
    if(command==='create_teacher'||command==='add_rate'){
      const rate=Number(input.rate);const from=text('from',10);
      if(!Number.isSafeInteger(rate)||rate<=0)throw new Error('Enter a positive whole-MMK rate.');
      if(!/^\d{4}-\d{2}-\d{2}$/.test(from)||!Number.isFinite(Date.parse(from+'T00:00:00Z'))||new Date(from+'T00:00:00Z').toISOString().slice(0,10)!==from)throw new Error('Enter a valid effective date.');
      payload.rate=rate;payload.from=from;
    }
    if(command.endsWith('_status')){if(typeof input.active!=='boolean')throw new Error('Select a valid status.');payload.active=input.active;}
    for(const key of command==='create_teacher'||command==='teacher_assignments'?['classes']:command==='class_assignments'?['teachers']:[]){
      const values=input[key];if(!Array.isArray(values)||values.length>1000||!values.every(x=>typeof x==='string'&&uuid.test(x)))throw new Error('Select valid assignments.');payload[key]=[...new Set(values)];
    }
    const client=await createClient();const result=await client.rpc('manage_master_data',{p_school:schoolId,p_request:requestId,p_command:command,p_payload:payload});
    if(result.error){
      const code=result.error.code;
      if(code==='23505')return {error:'This email or effective rate date already exists.'};
      if(code==='40001')return {error:'Record changed. Close this form, reload the page and try again.'};
      if(code==='42501')return {error:'Administrator access is required.'};
      return {error:'Unable to save. Check the values and assignments, then reload before retrying.'};
    }
    return {ok:true};
  }catch(error){return {error:error instanceof Error?error.message:'Unable to save. Please retry.'};}
}
