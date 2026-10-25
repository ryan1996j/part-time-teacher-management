'use client';
import {useEffect,useRef,useState,type FormEvent} from 'react';
import Link from 'next/link';
import {captureTeaching,readTeachingWorkspace} from '../../app/session-actions';
import {assignedAt,recordCode,yangonInput,yangonInputToISO,type TeachingData,type TeachingRecord} from '../../lib/teaching-types';
import {teacherCode,classCode} from '../../lib/master-data';
import AppShell from './AppShell';
import Dialog from './Dialog';
import SessionReview from './SessionReview';
import SelectField from './SelectField';
import {Button,Icon,Badge} from './Ui';

const time=(value:string|null)=>value?new Date(value).toLocaleString('en-GB',{timeZone:'Asia/Yangon',day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit'}):'—';
const statuses=['Pending','Verified','Rejected','In progress','Missing checkout'];
export default function TeachingWorkspace({initial,page}:{initial:TeachingData;page:'home'|'sessions'|'reviews'}) {
 const [data,setData]=useState(initial),[now,setNow]=useState(Date.parse(initial.serverNow)),[filter,setFilter]=useState(initial.filter),[query,setQuery]=useState(initial.query);
 const [busy,setBusy]=useState(false),[loading,setLoading]=useState(false),[error,setError]=useState(''),[notice,setNotice]=useState(''),[adding,setAdding]=useState(false),[selected,setSelected]=useState<TeachingRecord|null>(null),[dirty,setDirty]=useState(false);
 const [teacherId,setTeacherId]=useState(initial.teachers[0]?.id||''),[classId,setClassId]=useState(''),[start,setStart]=useState(yangonInput(new Date(Date.parse(initial.serverNow)-3600000).toISOString()));
 const [end,setEnd]=useState(yangonInput(initial.serverNow));
 const pending=useRef<{id:string;fingerprint:string}|null>(null),reads=useRef(0),timer=useRef<ReturnType<typeof setTimeout>|null>(null);
 useEffect(()=>{const anchor=performance.now(),base=Date.parse(data.serverNow);setNow(base);const interval=setInterval(()=>setNow(base+performance.now()-anchor),1000);return()=>clearInterval(interval);},[data.serverNow]);
 useEffect(()=>()=>{if(timer.current)clearTimeout(timer.current);},[]);
 useEffect(()=>{if(data.role==='admin'&&new URLSearchParams(window.location.search).get('action')==='add-session')setAdding(true);},[]);
 useEffect(()=>{const warn=(event:BeforeUnloadEvent)=>{if(dirty){event.preventDefault();event.returnValue='';}};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn);},[dirty]);
 let startISO='';try{startISO=yangonInputToISO(start);}catch{}
 const classOptions=data.classes.filter(c=>data.assignments.some(a=>assignedAt(a,teacherId,c.id,startISO)));
 useEffect(()=>{if(!classOptions.some(c=>c.id===classId))setClassId(classOptions[0]?.id||'');},[teacherId,start,data.assignments,data.classes,classId]);
 function notify(message:string){setNotice(message);if(timer.current)clearTimeout(timer.current);timer.current=setTimeout(()=>setNotice(''),5000);}
 async function load(nextPage=data.page,nextFilter=filter,nextQuery=query){
  const request=++reads.current;setLoading(true);
  try{const next=await readTeachingWorkspace({page:nextPage,filter:nextFilter,query:nextQuery});if(request===reads.current){setData(next);setFilter(next.filter);setQuery(next.query);setError('');}}
  catch{if(request===reads.current)setError('Unable to refresh your class records. Please retry.');}
  finally{if(request===reads.current)setLoading(false);}
 }
 function close(){if(busy)return;if(dirty&&!window.confirm('Discard unsaved class record?'))return;setAdding(false);setSelected(null);setDirty(false);setError('');}
 function openAdd(){setTeacherId(data.teachers[0]?.id||'');setStart(yangonInput(new Date(now-3600000).toISOString()));setEnd(yangonInput(new Date(now).toISOString()));setDirty(false);setError('');pending.current=null;setAdding(true);}
 async function mutate(command:string,payload:Record<string,unknown>){
  if(busy||loading)return;setBusy(true);setError('');const fingerprint=JSON.stringify({command,payload});
  if(!pending.current||pending.current.fingerprint!==fingerprint)pending.current={id:crypto.randomUUID(),fingerprint};
  try{
   const result=await captureTeaching(command,payload,pending.current.id);
   if(result.error){setError(result.error);return;}
   pending.current=null;setAdding(false);setDirty(false);
   notify(command==='check_in'?'Checked in. Your teaching record is saved.':command==='check_out'?'Checked out. Awaiting administrator verification.':'Class record saved as Pending verification.');
   await load(command==='admin_entry'?1:data.page);
  }catch{setError('Unable to confirm the save. Retry unchanged values safely, or refresh to check the result.');}
  finally{setBusy(false);}
 }
 function submitAdmin(event:FormEvent<HTMLFormElement>){event.preventDefault();const form=event.currentTarget;if(!form.reportValidity())return;const values=new FormData(form);void mutate('admin_entry',{teacher_id:teacherId,class_id:classId,start,end,reason:String(values.get('reason')||'')});}
 const open=data.open;
 const elapsed=open?Math.max(0,Math.floor((now-Date.parse(open.start_at))/1000)):0;
 const duration=[Math.floor(elapsed/3600),Math.floor(elapsed/60)%60,elapsed%60].map(n=>String(n).padStart(2,'0')).join(':');
 const setupAvailable=data.teachers.length>0&&data.classes.length>0&&data.assignments.length>0;
 return <><AppShell role={data.role} profile={data.teacher||undefined} activePage={page==='home'?'home':page==='reviews'?'reviews':'sessions'} reviewCount={0}>
  <section className="page-head"><div><div className="eyebrow">{page==='home'?'TEACHER WORKSPACE':'TEACHING RECORDS'}</div><h1>{page==='home'?'မင်္ဂလာပါ '+data.teacher?.name:page==='reviews'?'Review inbox':data.role==='admin'?'Class records':'My class records'}</h1><p className="subtext">{page==='home'?'Your teaching time, records and payment status.':'သင်ကြားချိန် မှတ်တမ်းများကို ကြည့်ရှုပါ။'}</p></div><div className="flex items-center gap-2">{data.role==='admin'?<Button kind="primary" onClick={openAdd}><Icon name="plus"/> Add class record</Button>:<span className="mini-badge">{data.teacher?.name} · {teacherCode(data.teacher?.code||0)}</span>}</div></section>
  <p className="record-note">Teaching records, corrections and verification use the development database. Payroll remains a separate prototype.</p>
  {page==='reviews'&&<div className="toolbar"><Link className="btn" href="/admin/reviews">Corrections</Link><Link className="btn primary" href="/admin/reviews?view=sessions">Class verification</Link></div>}
  {error&&!adding&&<p className="form-error" role="alert">{error}</p>}
  {page==='home'&&<><section className="teaching-layout"><section className={'clock-card '+(open?'is-running':'')} aria-label="Class timer"><div className="timer-status"><span className="timer-dot"/><span>{open?open.record_status==='Missing checkout'?'Missing checkout':'Teaching in progress':'Ready to teach'}</span></div><h2>{open?open.class_name:'Your next class'}</h2><p className="idle-clock-label">{open?'Time elapsed':'Current time · Myanmar'}</p><div className="live-clock" role="timer" aria-live="off">{open?duration:new Date(now).toLocaleTimeString('en-GB',{timeZone:'Asia/Yangon'})}</div>{open?<><p className="record-note">Checked in {time(open.start_at)}</p>{open.record_status==='Missing checkout'&&<p className="timer-guidance">No checkout time has been assumed. If you are still teaching, check out now. If the class ended earlier, open its Details below and choose Request correction.</p>}<div className="timer-actions"><Button kind="primary" disabled={busy||loading} onClick={()=>{void mutate('check_out',{id:open.id,version:open.version})}}><Icon name="check"/>{busy?'Saving…':open.record_status==='Missing checkout'?'Check out now':'Check out'}</Button></div></>:<p className="record-note">Choose a class to check in.</p>}</section>
   <section className="card assigned-classes"><div className="card-head"><div><h2>Your assigned classes</h2><p className="subtext">{open?'Check out of your active class before starting another.':'Select the class you are teaching.'}</p></div><Icon name="classes"/></div>{data.classes.map(c=><div className="class-option" key={c.id}><span className="class-glyph"><Icon name="classes"/></span><div><h3>{c.subject}</h3><p>{c.name} · {classCode(c.code)}</p></div><Button kind={open?'':'primary'} disabled={!!open||busy||loading} aria-label={'Check in to '+c.subject} onClick={()=>{void mutate('check_in',{class_id:c.id})}}><Icon name="plus"/> Check in</Button></div>)}{!data.classes.length&&<div className="empty"><Icon name="leaf"/><h3>No assigned classes</h3><p>Contact your administrator to assign a class before checking in.</p></div>}</section></section><details className="workflow-help"><summary>How your teaching time becomes pay</summary><p>Check out after class. Your administrator verifies the record, includes eligible minutes in payroll, and records your payment.</p></details></>}
  <section className="card" style={{marginTop:24}}><div className="card-head"><div><h2>{page==='home'?'My recent class records':'Class records'}</h2><p className="subtext">Teaching dates and times use Asia/Yangon.</p></div><Button kind="small" disabled={busy||loading} onClick={()=>{void load()}}>{loading?'Refreshing…':'Refresh records'}</Button></div>
   <form className="toolbar" onSubmit={event=>{event.preventDefault();void load(1);}}><SelectField label="Status" name="status" value={filter} options={[{id:'',name:'All statuses'},...statuses.map(id=>({id,name:id}))]} onChange={value=>{setFilter(value);void load(1,value);}}/><label className="field"><span>Search records</span><input type="search" value={query} maxLength={120} onChange={event=>setQuery(event.target.value)} placeholder="Teacher, class or record code"/></label><button className="btn small" type="submit" disabled={busy||loading}>Search</button></form>
   <div className="table-scroll" role="region" aria-label="Scrollable records table" tabIndex={0}><table><thead><tr>{['Teacher','Class / subject','Date / teaching time','Duration','Status','Actions'].map(label=><th scope="col" key={label}>{label}</th>)}</tr></thead><tbody>{data.records.map(s=><tr key={s.id}><td><strong>{s.teacher_name}</strong><div className="subtext">{teacherCode(s.teacher_code)}</div></td><td><strong>{s.subject}</strong><div className="subtext">{s.class_name} · {recordCode(s.code)}</div></td><td>{time(s.start_at)}<br/>→ {time(s.end_at)}</td><td>{s.minutes===null?'—':s.minutes+' min'}</td><td><Badge status={s.record_status}/>{s.pending_correction&&<p className="record-note">Correction pending · on hold</p>}{s.overlap_flag&&<p className="record-note">{s.overlap_resolution?'Overlap · reviewed':'Overlap · review required'}</p>}</td><td><Button kind="small" onClick={()=>{setSelected(s);setError('');}}>Details</Button></td></tr>)}</tbody></table></div>
   {!data.records.length&&<div className="empty"><Icon name="leaf"/><h3>No matching class records</h3><p>{data.role==='admin'?'Try another filter or add a completed class record.':'Try another filter, or check in from Today & check-in.'}</p></div>}
   <div className="table-foot"><span>{data.total} records · page {data.page} of {Math.max(1,Math.ceil(data.total/data.pageSize))}</span><div className="flex gap-2"><Button kind="small" disabled={data.page<=1||loading||busy} onClick={()=>{void load(data.page-1);}}>Previous</Button><Button kind="small" disabled={data.page*data.pageSize>=data.total||loading||busy} onClick={()=>{void load(data.page+1);}}>Next</Button></div></div>
  </section>
 </AppShell>
 {notice&&<div role="status" style={{position:'fixed',bottom:24,right:24,maxWidth:380,padding:'12px 18px',background:'#007acb',color:'#fff',borderRadius:10,zIndex:200}}>{notice}</div>}
 {adding&&<Dialog hideClose title={setupAvailable?'Add a completed class':'Set up a teacher and class first'} onClose={close}>{setupAvailable?<form onSubmit={submitAdmin} onChange={()=>setDirty(true)}><div className="form-grid"><SelectField label="Teacher" name="teacher" value={teacherId} options={data.teachers} onChange={value=>{setTeacherId(value);setDirty(true);}}/><SelectField label="Class" name="class" value={classId} options={classOptions} onChange={value=>{setClassId(value);setDirty(true);}}/><label className="field"><span>Start time · Myanmar</span><input type="datetime-local" required value={start} onChange={event=>setStart(event.target.value)}/></label><label className="field"><span>End time · Myanmar</span><input type="datetime-local" required value={end} onChange={event=>setEnd(event.target.value)}/></label></div><label className="field"><span>Reason for entering on behalf of the teacher</span><textarea name="reason" required maxLength={1000}/></label><p className="admin-note">Saved as Pending verification. Teacher can see this entry. Enter completed times only.</p>{!classOptions.length&&<p className="record-note">No active class assignment exists at this start time. Select another teacher/time or review assignments.</p>}{error&&<p className="form-error" role="alert">{error}</p>}<div className="form-actions"><Button disabled={busy} onClick={close}>Cancel</Button><button className="btn primary" type="submit" disabled={busy||loading||!classId}>{busy?'Saving…':'Save class record'}</button></div></form>:<><p>Add an active teacher, an active class and an assignment before entering a teaching record.</p><div className="form-actions"><Button onClick={close}>Close</Button><Link className="btn primary" href="/admin/teachers">Manage teachers</Link><Link className="btn small" href="/admin/classes">Manage classes</Link></div></>}</Dialog>}
 {selected&&<SessionReview record={selected} role={data.role} onClose={()=>setSelected(null)} onSaved={async()=>{notify('Review saved. Records refreshed.');await load();}}/>}
 </>;
}
