'use client';
import {useEffect,useRef,useState,type FormEvent} from 'react';
import {managePayrollApproval} from '../../app/payroll-actions';
import {moneyText,draftCode,type PayrollDraft,type PayrollAdjustment} from '../../lib/payroll-types';
import Dialog from './Dialog';
import SelectField from './SelectField';
import {Button} from './Ui';
export default function PayrollDecision({mode,draft,teachers,adjustment,onClose,onSaved}:{mode:'adjust'|'approve'|'withdraw';draft:PayrollDraft;teachers:{id:string;name:string}[];adjustment?:PayrollAdjustment;onClose:()=>void;onSaved:()=>Promise<void>}){
 const [teacher,setTeacher]=useState(teachers[0]?.id||''),[busy,setBusy]=useState(false),[dirty,setDirty]=useState(false),[error,setError]=useState('');
 const pending=useRef<{key:string;fingerprint:string}|null>(null);
 useEffect(()=>{const warn=(e:BeforeUnloadEvent)=>{if(dirty){e.preventDefault();e.returnValue=''}};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn)},[dirty]);
 function close(){if(!busy&&(!dirty||window.confirm('Discard unsaved payroll action?')))onClose()}
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(busy)return;const form=event.currentTarget;if(!form.reportValidity())return;
  const values=new FormData(form),command=mode==='adjust'?'add_adjustment':mode==='withdraw'?'withdraw_adjustment':'approve';
  const input:Record<string,unknown>={id:draft.id,version:draft.version,reason:String(values.get('reason')||'')};
  if(mode==='adjust'){input.teacher_id=teacher;input.amount=String(values.get('amount')||'');input.reference=String(values.get('reference')||'');}
  if(mode==='withdraw')input.adjustment_id=adjustment?.id;
  const fingerprint=JSON.stringify({command,input});if(pending.current?.fingerprint!==fingerprint)pending.current={key:crypto.randomUUID(),fingerprint};
  setBusy(true);setError('');
  try{const result=await managePayrollApproval(command,input,pending.current!.key);if(result.error){setError(result.error);return;}pending.current=null;setDirty(false);await onSaved();onClose();}
  catch{setError('Unable to confirm the save. Retry unchanged values safely, or refresh to check the result.');}finally{setBusy(false)}
 }
 return <Dialog hideClose eyebrow={draftCode(draft.code)+' · version '+draft.version} title={mode==='adjust'?'Add payroll adjustment':mode==='withdraw'?'Withdraw adjustment':'Approve payroll'} onClose={close}>
  <form onSubmit={submit} onChange={()=>setDirty(true)}>
   {mode==='adjust'?<><SelectField label="Teacher" name="teacher" value={teacher} options={teachers} onChange={id=>{setTeacher(id);setDirty(true)}}/><label className="field"><span>Signed adjustment · MMK</span><input name="amount" type="text" inputMode="numeric" required pattern="([+]|-)?[0-9]+" maxLength={20} placeholder="e.g. 5000 or -2000"/></label><label className="field"><span>Reference (optional)</span><input name="reference" maxLength={200} placeholder="Prior payroll or adjustment reference"/></label><p className="admin-note">Use a separate adjustment instead of changing teaching times or rates. Negative teacher net cannot be approved.</p></>:mode==='withdraw'?<><p className="request-reason">{adjustment?.teacher_name} · {moneyText(adjustment?.amount_mmk||'0')} MMK<br/>{adjustment?.reason}</p><p className="admin-note">This removes the adjustment from the draft totals and preserves its audit history.</p></>:<><div className="info-grid">{[['Period',draft.period_start+' → '+draft.period_end],['Gross',moneyText(draft.snapshot.gross_mmk)+' MMK'],['Adjustments',moneyText(draft.snapshot.adjustments_mmk||'0')+' MMK'],['Net',moneyText(draft.snapshot.net_mmk||draft.snapshot.gross_mmk)+' MMK']].map(([label,value])=><div key={label}><small>{label}</small><strong>{value}</strong></div>)}</div><p className="admin-note">Approval freezes the reviewed amounts and locks included class records. Eligibility, versions, rates and allocations are checked again by the server. This does not send or record payment. Use Payments for external payment records; reversal and Void workflows are not available yet.</p><label className="field"><span><input name="confirmed" type="checkbox" style={{width:18,height:18,marginRight:8}} required/> I have reviewed this payroll and intend to approve it.</span></label></>}
   <label className="field"><span>{mode==='approve'?'Approval comment (optional)':'Reason'}</span><textarea name="reason" required={mode!=='approve'} maxLength={1000}/></label>
   {error&&<p className="form-error" role="alert">{error}</p>}<div className="form-actions"><Button disabled={busy} onClick={close}>Cancel</Button><button className="btn primary" type="submit" disabled={busy||mode==='adjust'&&!teacher}>{busy?'Saving…':mode==='adjust'?'Save adjustment':mode==='withdraw'?'Withdraw adjustment':'Approve payroll'}</button></div>
  </form>
 </Dialog>
}
