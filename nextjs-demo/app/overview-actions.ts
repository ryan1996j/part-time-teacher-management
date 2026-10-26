'use server';
import {approvedReportRows} from '../lib/report-server';
import {financeTotals} from '../lib/report-data';
import {requireWorkspace} from '../lib/auth';
import {createClient} from '../lib/supabase/server';
import {activityWindow,addActivity,type OverviewData} from '../lib/overview-data';
import type {TeachingRecord} from '../lib/teaching-types';
export async function readAdminOverview():Promise<OverviewData>{
 const access=await requireWorkspace('admin'),client=await createClient();
 const clock=await client.rpc('teaching_server_time');
 if(clock.error||!clock.data)throw new Error('Server time is unavailable. Please retry.');
 const serverNow=String(clock.data),window=activityWindow(serverNow);
 const [teachers,classes,pending,corrections,missing,recent]=await Promise.all([
  client.from('teachers').select('id',{count:'exact',head:true}).eq('school_id',access.schoolId).eq('active',true),
  client.from('classes').select('id',{count:'exact',head:true}).eq('school_id',access.schoolId).eq('active',true),
  client.from('session_records').select('id',{count:'exact',head:true}).eq('school_id',access.schoolId).eq('record_status','Pending'),
  client.from('correction_requests').select('id',{count:'exact',head:true}).eq('school_id',access.schoolId).eq('status','Pending'),
  client.from('session_records').select('id',{count:'exact',head:true}).eq('school_id',access.schoolId).eq('record_status','Missing checkout'),
  client.from('session_records').select('*',{count:'exact'}).eq('school_id',access.schoolId).order('start_at',{ascending:false}).order('id').limit(5),
 ]);
 if([teachers,classes,pending,corrections,missing,recent].some(r=>r.error))throw new Error('Unable to load the school overview. Please retry.');
 const minutes=Array<number>(7).fill(0);
 // Page the bounded date range to avoid silently truncating at Supabase's row cap.
 for(let start=0;;start+=1000){
  const result=await client.from('teaching_sessions').select('start_at,end_at,minutes,id').eq('school_id',access.schoolId)
   .gte('start_at',window.start).lt('start_at',window.end).not('end_at','is',null).order('start_at').order('id').range(start,start+999);
  if(result.error)throw new Error('Unable to load teaching activity. Please retry.');
  addActivity(minutes,window.dates,result.data||[]);
  if(!result.data||result.data.length<1000)break;
 }
 const finance=financeTotals(await approvedReportRows());
 return {finance,serverNow,teachers:teachers.count||0,classes:classes.count||0,pending:pending.count||0,corrections:corrections.count||0,
  missing:missing.count||0,total:recent.count||0,recent:(recent.data||[]) as TeachingRecord[],activity:{...window,minutes}};
}
