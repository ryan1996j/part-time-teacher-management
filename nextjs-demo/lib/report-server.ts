import 'server-only';
import {requireWorkspace} from './auth';
import {createClient} from './supabase/server';
import type {PaymentSummary} from './payment-types';
// Reuse the approved, school-scoped read API. Never sum stale Draft snapshots.
export async function approvedReportRows(){
 const access=await requireWorkspace('admin'),client=await createClient(),rows:PaymentSummary[]=[],seen=new Set<string>();let total:number|undefined;
 for(let page=1;page<=400;page++){
  const result=await client.rpc('read_teacher_payments',{p_school:access.schoolId,p_page:page,p_status:'',p_teacher:null});
  if(result.error)throw new Error('Unable to load approved financial records.');
  const count=Number(result.data.total),batch=result.data.records as PaymentSummary[];
  if(!Number.isSafeInteger(count)||count<0||count>10000)throw new Error('Report exceeds the current 10,000-row limit.');
  if(total!==undefined&&total!==count)throw new Error('Financial records changed while loading. Refresh and retry.');total=count;
  for(const row of batch){const key=row.run_id+':'+row.teacher_id;if(seen.has(key))throw new Error('Financial records changed while loading. Refresh and retry.');seen.add(key);rows.push(row);}
  if(rows.length===total)return rows;
  if(!batch.length||rows.length>total)throw new Error('Incomplete financial report. Refresh and retry.');
 }
 throw new Error('Report exceeds the current row limit.');
}
