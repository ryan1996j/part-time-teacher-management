'use client';
import {useEffect,useRef,useState,type FormEvent} from 'react';
import Link from 'next/link';
import {readCorrections,reviewTeaching} from '../../app/review-actions';
import {type CorrectionData,type CorrectionRecord,correctionCode,teachingTime as time} from '../../lib/review-types';
import {recordCode} from '../../lib/teaching-types';
import AppShell from './AppShell';
import Dialog from './Dialog';
import SelectField from './SelectField';
import {Button,Badge,Icon} from './Ui';

export default function CorrectionsWorkspace({initial}:{initial:CorrectionData}){
 const [data,setData]=useState(initial),[selected,setSelected]=useState<CorrectionRecord|null>(null),[loading,setLoading]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(''),[notice,setNotice]=useState(''),[dirty,setDirty]=useState(false);
 const reads=useRef(0),pending=useRef<{key:string;fingerprint:string}|null>(null);
 useEffect(()=>{if(!notice)return;const id=setTimeout(()=>setNotice(''),5000);return()=>clearTimeout(id)},[notice]);
 useEffect(()=>{const warn=(e:BeforeUnloadEvent)=>{if(dirty){e.preventDefault();e.returnValue='';}};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn)},[dirty]);
 async function load(page=data.page,filter=data.filter){const id=++reads.current;setLoading(true);try{const next=await readCorrections({page,filter});if(id===reads.current){setData(next);setError('')}}catch{setError('Unable to refresh correction requests. Please retry.')}finally{if(id===reads.current)setLoading(false)}}
 function close(){if(busy)return;if(dirty&&!window.confirm('Discard unsaved review?'))return;setSelected(null);setDirty(false);setError('')}
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(!selected||busy)return;const form=event.currentTarget;if(!form.reportValidity())return;
  const decision=(event.nativeEvent as SubmitEvent).submitter?.getAttribute('value')||'Withdrawn';
  const command=decision==='Withdrawn'?'withdraw_correction':'review_correction';
  const payload={id:selected.id,version:selected.version,session_version:selected.session_version,decision,reason:String(new FormData(form).get('reason')||'')};
  if(decision==='Rejected'&&!payload.reason.trim()){setError('Enter a rejection reason.');return;}
  if(decision==='Withdrawn'&&!window.confirm('Withdraw this pending correction? Effective times will stay unchanged.'))return;
  const fingerprint=JSON.stringify({command,payload});if(pending.current?.fingerprint!==fingerprint)pending.current={key:crypto.randomUUID(),fingerprint};
  setBusy(true);setError('');try{const result=await reviewTeaching(command,payload,pending.current!.key);if(result.error){setError(result.error);return;}pending.current=null;setDirty(false);setSelected(null);setNotice(decision==='Approved'?'Correction approved. Class record needs separate verification.':'Correction '+decision.toLowerCase()+'. Effective times unchanged.');await load();}catch{setError('Unable to confirm the save. Retry unchanged values safely.')}finally{setBusy(false)}
 }
 return <><AppShell role={data.role} profile={data.teacher||undefined} activePage={data.role==='admin'?'reviews':'corrections'} reviewCount={0}>
  <section className="page-head"><div><div className="eyebrow">{data.role==='admin'?'REVIEW & VERIFY':'TEACHER WORKSPACE'}</div><h1>{data.role==='admin'?'Review inbox':'My corrections'}</h1><p className="subtext">Review requested time changes while preserving original records.</p></div></section>
  {data.role==='admin'&&<div className="toolbar"><Link className="btn primary" href="/admin/reviews">Corrections</Link><Link className="btn" href="/admin/reviews?view=sessions">Class verification</Link></div>}
  <p className="record-note">Real development records. Correction approval and class verification are separate decisions. Payroll approval and payments are not connected yet.</p>
  {error&&!selected&&<p className="form-error" role="alert">{error}</p>}
  <section className="card"><div className="card-head"><h2>Correction requests</h2><Button kind="small" disabled={loading||busy} onClick={()=>void load()}>{loading?'Refreshing…':'Refresh requests'}</Button></div>
   <div className="toolbar"><SelectField label="Status" name="status" value={data.filter} options={[{id:'',name:'All statuses'},...['Pending','Approved','Rejected','Withdrawn'].map(id=>({id,name:id}))]} onChange={value=>void load(1,value)}/></div>
   <div className="table-scroll" role="region" aria-label="Correction requests" tabIndex={0}><table><thead><tr>{['Teacher / record','Class','Requested time · Myanmar','Reason','Status','Actions'].map(x=><th key={x}>{x}</th>)}</tr></thead><tbody>{data.records.map(c=><tr key={c.id}><td><strong>{c.teacher_name}</strong><div className="subtext">{recordCode(c.session_code)} · {correctionCode(c.code)}</div></td><td>{c.class_name}<div className="subtext">{c.subject}</div></td><td>{time(c.proposed_start)}<br/>→ {time(c.proposed_end)}</td><td>{c.reason}</td><td><Badge status={c.status}/>{c.status==='Pending'&&c.base_version!==c.session_version&&<p className="record-note">Stale · resubmit required</p>}</td><td><Button kind="small" onClick={()=>{setSelected(c);setError('');setDirty(false);pending.current=null}}>Details</Button></td></tr>)}</tbody></table></div>
   {!data.records.length&&<div className="empty"><Icon name="leaf"/><h3>No correction requests</h3><p>{data.role==='teacher'?'Open a class record and choose Request correction.':'Requests will appear here when submitted.'}</p><Link className="btn" href={'/'+data.role+'/sessions'}>View class records</Link></div>}
   <div className="table-foot"><span>{data.total} requests · page {data.page} of {Math.max(1,Math.ceil(data.total/25))}</span><div className="flex gap-2"><Button disabled={loading||busy||data.page<=1} onClick={()=>void load(data.page-1)}>Previous</Button><Button disabled={loading||busy||data.page*25>=data.total} onClick={()=>void load(data.page+1)}>Next</Button></div></div>
  </section>
 </AppShell>
 {notice&&<div role="status" style={{position:'fixed',right:24,bottom:24,maxWidth:380,padding:'12px 18px',background:'#007acb',color:'#fff',borderRadius:10,zIndex:200}}>{notice}</div>}
 {selected&&<Dialog hideClose title="Correction request" eyebrow={correctionCode(selected.code)+' · '+recordCode(selected.session_code)} onClose={close}>
  <div className="flex items-center justify-between"><strong>{selected.teacher_name} · {selected.class_name}</strong><Badge status={selected.status}/></div>
  <div className="info-grid">{[['Original capture',time(selected.original_start_at)+' → '+time(selected.original_end_at)],['Effective time now',time(selected.start_at)+' → '+time(selected.end_at)],['At request submission',time(selected.prior_snapshot.start_at)+' → '+time(selected.prior_snapshot.end_at)],['Proposed time',time(selected.proposed_start)+' → '+time(selected.proposed_end)],['Version',String(selected.base_version)+' requested / '+selected.session_version+' current'],['Submitted',time(selected.created_at)]].map(([label,value])=><div key={label}><small>{label}</small><strong>{value}</strong></div>)}</div>
  <p className="request-reason">{selected.reason}</p>{selected.reviewed_at&&<p className="record-note">{time(selected.reviewed_at)} · {selected.review_comment||selected.status}</p>}
  {selected.status==='Pending'?<form onSubmit={submit} onChange={()=>setDirty(true)}>
   {data.role==='admin'&&<><label className="field"><span>Reviewer comment (required to reject)</span><textarea name="reason" maxLength={1000}/></label><p className="admin-note">Approve changes effective times only. Original captures remain unchanged; verification returns to Pending.</p>{selected.base_version!==selected.session_version&&<p className="form-error">Stale request. Reject or withdraw, then submit a new request against the current record.</p>}</>}
   {error&&<p className="form-error" role="alert">{error}</p>}<div className="form-actions"><Button disabled={busy} onClick={close}>Cancel</Button>{selected.requested_by===data.actor&&<button className="btn" type="submit" value="Withdrawn" disabled={busy}>Withdraw request</button>}{data.role==='admin'&&<><button className="btn danger" type="submit" value="Rejected" disabled={busy}>Reject</button><button className="btn primary" type="submit" value="Approved" disabled={busy||selected.base_version!==selected.session_version}>{busy?'Saving…':'Approve correction'}</button></>}</div>
  </form>:<div className="form-actions"><Button onClick={close}>Close</Button></div>}
 </Dialog>}
 </>;
}
