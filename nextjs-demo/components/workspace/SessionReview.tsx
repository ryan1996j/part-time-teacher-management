'use client';
import {useEffect,useRef,useState,type FormEvent} from 'react';
import {readSessionHistory,reviewTeaching} from '../../app/review-actions';
import {recordCode,yangonInput,type TeachingRecord} from '../../lib/teaching-types';
import {correctionCode,teachingTime as time} from '../../lib/review-types';
import {Button,Badge} from './Ui';
import Dialog from './Dialog';

export default function SessionReview({record,role,onClose,onSaved}:{record:TeachingRecord;role:'admin'|'teacher';onClose:()=>void;onSaved:()=>Promise<void>}){
 const [mode,setMode]=useState<'detail'|'request'|'verify'>('detail'),[busy,setBusy]=useState(false),[dirty,setDirty]=useState(false),[error,setError]=useState('');
 const [history,setHistory]=useState<Awaited<ReturnType<typeof readSessionHistory>>|null>(null),[historyError,setHistoryError]=useState(false);
 const pending=useRef<{key:string;fingerprint:string}|null>(null);
 useEffect(()=>{let active=true;readSessionHistory(record.id).then(value=>{if(active)setHistory(value)}).catch(()=>{if(active)setHistoryError(true)});return()=>{active=false};},[record.id]);
 useEffect(()=>{const warn=(e:BeforeUnloadEvent)=>{if(dirty){e.preventDefault();e.returnValue='';}};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn)},[dirty]);
 function close(){if(!busy&&(!dirty||window.confirm('Discard unsaved review?')))onClose()}
 async function save(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(busy)return;const form=event.currentTarget;if(!form.reportValidity())return;
  const values=new FormData(form),command=mode==='request'?'request_correction':'verify_session';
  const payload:Record<string,unknown>={id:record.id,version:record.version,reason:String(values.get('reason')||'')};
  if(mode==='request'){payload.start=String(values.get('start'));payload.end=String(values.get('end'));}
  else payload.decision=(event.nativeEvent as SubmitEvent).submitter?.getAttribute('value')||'Verified';
  if(payload.decision==='Rejected'&&!String(payload.reason).trim()){setError('Enter a rejection reason.');return;}
  const fingerprint=JSON.stringify({command,payload});if(pending.current?.fingerprint!==fingerprint)pending.current={key:crypto.randomUUID(),fingerprint};
  setBusy(true);setError('');
  try{const result=await reviewTeaching(command,payload,pending.current!.key);if(result.error){setError(result.error);return;}pending.current=null;setDirty(false);await onSaved();onClose();}
  catch{setError('Unable to confirm the save. Retry unchanged values or refresh to check the result.');}finally{setBusy(false)}
 }
 return <Dialog hideClose title={mode==='request'?'Request correction':mode==='verify'?'Verify class record':'Class record details'} eyebrow={recordCode(record.code)} onClose={close}>
  <div className="flex items-center justify-between"><strong>{record.teacher_name}</strong><Badge status={record.record_status}/></div>
  <div className="info-grid">{[['Class',record.class_name+' · '+record.subject],['Effective teaching time',time(record.start_at)+' → '+time(record.end_at)],['Original time',time(record.original_start_at)+' → '+time(record.original_end_at)],['Duration',record.minutes===null?'Missing checkout':record.minutes+' min'],['Record source',record.source],['Record version',String(record.version)]].map(([label,value])=><div key={label}><small>{label}</small><strong>{value}</strong></div>)}</div>
  {record.reason&&<p className="request-reason">{record.reason}</p>}
  {record.overlap_flag&&<p className="record-note">{record.overlap_resolution?'Overlap reviewed: '+record.overlap_resolution:'Overlapping teaching time requires administrator review.'}</p>}
  {record.pending_correction&&<p className="record-note">Pending correction · verification and payroll eligibility are on hold.</p>}
  {record.reviewed_at&&<p className="request-reason">{record.verification} · {time(record.reviewed_at)} · {record.review_comment||'No reviewer comment'}</p>}
  {mode==='detail'?<>
   <details className="workflow-help"><summary>Correction & review history</summary>{historyError?<p role="alert">History unavailable. Close and reopen to retry.</p>:!history?<p>Loading history…</p>:<>{history.corrections.map(c=><div className="request-reason" key={c.id}><strong>{correctionCode(c.code)} · {c.status}</strong><p>{time(c.proposed_start)} → {time(c.proposed_end)}</p><p>{c.reason}</p>{c.reviewed_at&&<p>{time(c.reviewed_at)} · {c.review_comment||c.status}</p>}</div>)}{history.events.map(e=><p className="record-note" key={e.id}>{time(e.created_at)} · {e.action.replaceAll('_',' ')} · {e.reason}</p>)}<p className="record-note">Latest 50 requests and 50 audit events shown. Original captures are preserved.</p></>}</details>
   <div className="form-actions"><Button onClick={close}>Close</Button><Button disabled={record.pending_correction} onClick={()=>setMode('request')}>Request correction</Button>{role==='admin'&&<Button kind="primary" disabled={record.pending_correction} onClick={()=>setMode('verify')}>Review record</Button>}</div>
  </>:<form onSubmit={save} onChange={()=>setDirty(true)}>
   {mode==='request'?<><div className="form-grid"><label className="field"><span>Proposed start · Myanmar</span><input name="start" type="datetime-local" required defaultValue={yangonInput(record.start_at)}/></label><label className="field"><span>Proposed end · Myanmar</span><input name="end" type="datetime-local" required defaultValue={record.end_at?yangonInput(record.end_at):''}/></label></div><p className="admin-note">Effective times stay unchanged until Admin approves. Approval returns verification to Pending.</p></>:<p className="admin-note">Verify only after reviewing the record. Overlap requires an explanation. Rejection always requires a reason. Payroll is not calculated here.</p>}
   <label className="field"><span>{mode==='request'?'Correction reason':'Reviewer comment / exception resolution'}</span><textarea name="reason" required={mode==='request'||record.overlap_flag} maxLength={1000}/></label>
   {error&&<p className="form-error" role="alert">{error}</p>}
   <div className="form-actions"><Button disabled={busy} onClick={close}>Cancel</Button>{mode==='request'?<button className="btn primary" disabled={busy} type="submit">{busy?'Saving…':'Submit correction'}</button>:<><button className="btn danger" disabled={busy} type="submit" value="Rejected">Reject</button><button className="btn primary" disabled={busy||!record.end_at||!record.minutes} type="submit" value="Verified">{busy?'Saving…':'Verify record'}</button></>}</div>
  </form>}
 </Dialog>
}
