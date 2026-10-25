'use client';
import {useRef,useState,type FormEvent} from 'react';
import Link from 'next/link';
import {readMasterData,saveMasterData,linkTeacherAccount} from '../../app/admin/master-actions';
import type {MasterData,DbTeacher,DbClass} from '../../lib/master-data';
import {teacherCode,classCode,schoolDate} from '../../lib/master-data';
import AppShell from './AppShell';
import Dialog from './Dialog';
import {Button,Icon} from './Ui';
type Mode='account'|'create_teacher'|'create_class'|'add_rate'|'teacher_assignments'|'class_assignments'|'teacher_status'|'class_status';
type Editor={mode:Mode;teacher?:DbTeacher;classRecord?:DbClass};
const money=(value:number)=>value.toLocaleString('en-US');
const accountLabels:Record<string,string>={not_linked:'Invitation needed',ready_to_link:'Ready to link',review_required:'Owner review required',linked_pending:'Linked · invitation pending',active:'Teacher login enabled',disabled:'Account access disabled'};
export default function MasterDataPage({initial,page}:{initial:MasterData;page:'teachers'|'classes'}) {
 const [data,setData]=useState(initial),[editor,setEditor]=useState<Editor|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState(''),[notice,setNotice]=useState(''),[dirty,setDirty]=useState(false);
 const request=useRef<{id:string;fingerprint:string}|null>(null);const timer=useRef<ReturnType<typeof setTimeout>|null>(null);
 function open(next:Editor){setEditor(next);setError('');setDirty(false);request.current=null;}
 function close(){if(busy)return;if(dirty&&!window.confirm('Discard unsaved changes?'))return;setEditor(null);setError('');}
 async function reload(){try{setData(await readMasterData());setNotice('Records refreshed.');}catch{setNotice('Unable to refresh. Please retry.');}}
 const assignmentsFor=(id:string,kind:'teacher'|'class')=>data.assignments.filter(a=>kind==='teacher'?a.teacher_id===id:a.class_id===id);
 const activeClasses=data.classes.filter(c=>c.active);
 const currentRate=(id:string)=>data.rates.filter(r=>r.teacher_id===id&&r.effective_from<=schoolDate()).sort((a,b)=>b.effective_from.localeCompare(a.effective_from))[0]?.hourly_mmk||0;
 const title=!editor?'':editor.mode==='account'?'Teacher account access':editor.mode==='create_teacher'?'Welcome a teacher':editor.mode==='create_class'?'Add a class':editor.mode==='add_rate'?'Teacher profile & rates':editor.mode==='teacher_assignments'?'Assign classes to '+editor.teacher?.name:editor.mode==='class_assignments'?'Assign teachers':(editor.teacher?.active??editor.classRecord?.active)?'Deactivate '+(editor.teacher?.name||editor.classRecord?.name)+'?':'Activate '+(editor.teacher?.name||editor.classRecord?.name)+'?';
 async function save(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(!editor||busy)return;const form=event.currentTarget;if(!form.reportValidity())return;
  const values=new FormData(form);const record=editor.teacher||editor.classRecord;
  const payload:Record<string,unknown>={reason:String(values.get('reason')||(editor.mode==='create_teacher'?'Teacher added':editor.mode==='create_class'?'Class added':(record?.active?'Deactivate':'Activate')+' record'))};
  if(record){payload.id=record.id;payload.version=record.version;}
  if(editor.mode==='create_teacher'||editor.mode==='create_class')payload.name=String(values.get('name')||'');
  if(editor.mode==='create_class')payload.subject=String(values.get('subject')||'');
  if(editor.mode==='create_teacher')payload.email=String(values.get('email')||'');
  if(editor.mode==='create_teacher'||editor.mode==='add_rate'){payload.rate=Number(values.get('rate'));payload.from=String(values.get('from')||'');}
  if(editor.mode==='create_teacher'||editor.mode==='teacher_assignments')payload.classes=values.getAll('classes');
  if(editor.mode==='class_assignments')payload.teachers=values.getAll('teachers');
  if(editor.mode.endsWith('_status'))payload.active=!record?.active;
  const fingerprint=JSON.stringify({command:editor.mode,payload});
  if(!request.current||request.current.fingerprint!==fingerprint)request.current={id:crypto.randomUUID(),fingerprint};
  setBusy(true);setError('');
  try{
   const result=editor.mode==='account'&&editor.teacher?await linkTeacherAccount(editor.teacher.id,editor.teacher.version,request.current.id,String(payload.reason)):await saveMasterData(editor.mode,payload,request.current.id);
   if(result.error){setError(result.error);return;}
   setEditor(null);setDirty(false);request.current=null;
   // A failed reload must never turn a successful mutation into a second create.
   try{setData(await readMasterData());setNotice('Saved. Your school records are up to date.');}
   catch{setNotice('Saved successfully. Refresh to load the latest records.');}
   if(timer.current)clearTimeout(timer.current);timer.current=setTimeout(()=>setNotice(''),5000);
  }catch{setError('Unable to confirm the save. Retry unchanged values safely, or refresh to check the result.');}
  finally{setBusy(false);}
 }
 const field=(label:string,name:string,type='text',value='')=><label className="field"><span>{label}</span><input name={name} type={type} defaultValue={value} required maxLength={type==='email'?254:type==='text'?160:undefined} min={type==='number'?1:undefined} step={type==='number'?1:undefined}/></label>;
 const reason=<label className="field"><span>{editor?.mode==='add_rate'?'Rate change reason':'Assignment or coverage reason'}</span><textarea name="reason" required maxLength={1000}/></label>;
 const classChoices=(teacher?:DbTeacher)=><fieldset className="assignment-picker"><legend>Assigned classes (optional)</legend>{activeClasses.map(c=><label key={c.id}><input type="checkbox" name="classes" value={c.id} defaultChecked={!!teacher&&assignmentsFor(teacher.id,'teacher').some(a=>a.class_id===c.id)}/><span>{c.name}</span></label>)}{!activeClasses.length&&<p>No active classes yet. You can assign classes later.</p>}</fieldset>;
 return <><AppShell activePage={page} reviewCount={0}>
  <div className="page-head"><div><div className="eyebrow">{page==='teachers'?'PEOPLE & PROFILES':'CLASSES & ASSIGNMENTS'}</div><h1>{page==='teachers'?'Teachers':'Classes & assignments'}</h1><p className="page-description">{page==='teachers'?'ဆရာအချက်အလက်၊ အတန်းသတ်မှတ်မှုနဲ့ hourly rate များကို စီမံပါ။':'ဆရာနဲ့ အတန်းချိတ်ဆက်မှုကို စီမံပါ။'}</p></div><Button kind="primary" onClick={()=>open({mode:page==='teachers'?'create_teacher':'create_class'})}><Icon name="plus"/> Add {page==='teachers'?'teacher':'class'}</Button></div>
  <p className="record-note">These school records and class records are saved in the development database. Overview, reviews and payroll still use separate prototype data.</p>
  <div className="card-actions" style={{marginBottom:16}}><Button kind="small" onClick={()=>{void reload()}}>Refresh records</Button></div>
  {notice&&<div className="toast" role="status" style={{position:'fixed',bottom:24,right:24,maxWidth:360,padding:'12px 18px',background:'#007acb',color:'#fff',borderRadius:10,zIndex:200}}>{notice}</div>}
  <section className="teacher-grid">
   {page==='teachers'?data.teachers.map(t=><article className="card teacher-card" key={t.id}><header><span className={'avatar tone-'+t.code%5}>{t.name.split(' ').map(x=>x[0]).slice(0,2).join('')}</span><span className={'badge '+(t.active?'verified':'rejected')}>{t.active?'Active':'Inactive'}</span></header><h2>{t.name}</h2><p>{t.email}<br/>{teacherCode(t.code)} · {assignmentsFor(t.id,'teacher').map(a=>data.classes.find(c=>c.id===a.class_id)?.subject).filter(Boolean).join(' / ')||'No classes assigned'}</p><div className="rate"><span>Current hourly rate</span><strong>{money(currentRate(t.id))} <small style={{fontSize:'.8125rem',fontWeight:400}}>MMK/hr</small></strong></div><div className="card-actions"><Button kind="primary small" onClick={()=>open({mode:'add_rate',teacher:t})}>Profile & rates</Button><Button kind="small" onClick={()=>open({mode:'teacher_status',teacher:t})}>{t.active?'Deactivate':'Activate'}</Button><Button kind="small" onClick={()=>open({mode:'account',teacher:t})}>Account access</Button></div><p className="record-note">{accountLabels[t.account_state||'not_linked']}</p></article>):data.classes.map(c=><article className="card teacher-card" key={c.id}><header><span className="class-glyph"><Icon name="classes"/></span><span className={'badge '+(c.active?'verified':'rejected')}>{c.active?'Active':'Inactive'}</span></header><h2>{c.name}</h2><p>{classCode(c.code)} · {c.subject}</p><hr className="divider"/><div className="eyebrow">ASSIGNED TEACHERS</div>{assignmentsFor(c.id,'class').map(a=>data.teachers.find(t=>t.id===a.teacher_id)).filter((t):t is DbTeacher=>!!t).map(t=><div className="person" key={t.id} style={{margin:'11px 0'}}><span className={'avatar tone-'+t.code%5}>{t.name.split(' ').map(x=>x[0]).slice(0,2).join('')}</span><strong style={{fontSize:'.8125rem'}}>{t.name}</strong></div>)}{!assignmentsFor(c.id,'class').length&&<p>No teachers assigned yet.</p>}<div className="card-actions"><Button kind="small" aria-label={'Edit assignments for '+c.name} disabled={!c.active} onClick={()=>open({mode:'class_assignments',classRecord:c})}><Icon name="edit"/></Button><Button kind="small" onClick={()=>open({mode:'class_status',classRecord:c})}>{c.active?'Deactivate':'Activate'}</Button></div></article>)}
  </section>
  {!(page==='teachers'?data.teachers.length:data.classes.length)&&<section className="card" style={{padding:24}}><h2>No {page} yet</h2><p>Add your first {page==='teachers'?'teacher':'class'} to get started. Fictional sample records have not been imported.</p></section>}
 </AppShell>
 {editor&&<Dialog title={title} hideClose onClose={close}><form onSubmit={save} onChange={()=>setDirty(true)}>
  {editor.mode==='account'&&editor.teacher&&<><p className="request-reason"><strong>{editor.teacher.name}</strong><br/>{editor.teacher.email}</p><p>{accountLabels[editor.teacher.account_state||'not_linked']}</p><p>An invitation must be sent by the project owner before linking. Linking grants Teacher access to this school only; it does not send an email or grant Admin access.</p>{editor.teacher.account_state==='ready_to_link'?<><label className="field"><span>Access approval reason</span><textarea name="reason" required maxLength={1000}/></label><label className="flex items-center gap-3"><input type="checkbox" required/>I approve Teacher access for this email.</label></>:<p className="record-note">{editor.teacher.user_id?'The existing link is preserved. Disabled access requires a separate owner review.':'Contact the project owner to send or review the invitation, then refresh this page.'}</p>}</>}
  {editor.mode==='create_teacher'&&<>{field('Full name','name')}{field('Email','email','email')}<div className="form-grid">{field('Hourly rate · MMK','rate','number','10000')}{field('Effective from','from','date',schoolDate())}</div>{classChoices()}</>}
  {editor.mode==='create_class'&&<>{field('Class name','name')}{field('Subject','subject')}</>}
  {editor.mode==='add_rate'&&editor.teacher&&<><div className="person"><strong>{editor.teacher.name}</strong></div><p className="request-reason">{editor.teacher.email}<br/>{assignmentsFor(editor.teacher.id,'teacher').map(a=>data.classes.find(c=>c.id===a.class_id)?.subject).join(' · ')||'No classes assigned'}</p><div className="next-step"><Button kind="small" onClick={()=>{if(dirty&&!window.confirm('Discard unsaved changes?'))return;open({mode:'teacher_assignments',teacher:editor.teacher})}}>Assign classes</Button><Link className="btn small" href="/admin/sessions">View class records</Link></div><div className="eyebrow">HOURLY RATE HISTORY</div>{data.rates.filter(r=>r.teacher_id===editor.teacher?.id).sort((a,b)=>b.effective_from.localeCompare(a.effective_from)).map(r=><div className="detail-row" key={r.id}><span>Effective {r.effective_from}{r.effective_from>schoolDate()?' · Scheduled':''}</span><strong>{money(r.hourly_mmk)} MMK/hour</strong></div>)}<hr className="divider"/><div className="form-grid">{field('New hourly rate · MMK','rate','number')}{field('Effective from','from','date',schoolDate())}</div>{reason}</>}
  {editor.mode==='teacher_assignments'&&<>{classChoices(editor.teacher)}{reason}</>}
  {editor.mode==='class_assignments'&&<><p className="request-reason">{editor.classRecord?.name} · {editor.classRecord&&classCode(editor.classRecord.code)}</p>{data.teachers.map(t=><label key={t.id} className="flex items-center gap-3" style={{margin:'15px 0',fontSize:'.8125rem',color:'#475569'}}><input type="checkbox" name="teachers" value={t.id} defaultChecked={!!editor.classRecord&&assignmentsFor(editor.classRecord.id,'class').some(a=>a.teacher_id===t.id)}/>{t.name}{!t.active?' · Inactive':''}</label>)}{!data.teachers.length&&<p>No teachers yet. Add a teacher first.</p>}{reason}</>}
  {editor.mode.endsWith('_status')&&<p>{(editor.teacher?.active??editor.classRecord?.active)?'New check-ins will be disabled. Teaching and payment history will remain available.':'This record will be available for new teaching activity. Linked account access requires separate administrator review.'}</p>}
  {error&&<p className="form-error" role="alert">{error}</p>}<div className="form-actions"><Button disabled={busy} onClick={close}>Cancel</Button><button type="submit" className="btn primary" disabled={busy||(editor.mode==='account'&&editor.teacher?.account_state!=='ready_to_link')}>{busy?'Saving…':editor.mode==='account'?'Link Teacher account':editor.mode==='create_teacher'?'Add teacher':editor.mode==='create_class'?'Add class':editor.mode==='add_rate'?'Add rate version':editor.mode.endsWith('_status')?(editor.teacher?.active??editor.classRecord?.active)?'Deactivate':'Activate':'Save assignments'}</button></div>
 </form></Dialog>}
 </>;
}
