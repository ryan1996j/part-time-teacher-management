'use client';
import {useEffect,useRef,useState,type FormEvent} from 'react';
import {readPaymentDetail,recordTeacherPayment} from '../../app/payment-actions';
import {paymentMethods,paymentCode,type PaymentSummary,type PaymentDetail} from '../../lib/payment-types';
import {draftCode,moneyText} from '../../lib/payroll-types';
import {teachingTime} from '../../lib/review-types';
import {recordCode,yangonInput} from '../../lib/teaching-types';
import Dialog from './Dialog';
import SelectField from './SelectField';
import {Button,Badge} from './Ui';
export default function PaymentDialog({row,recording,serverNow,onClose,onSaved}:{row:PaymentSummary;recording:boolean;serverNow:string;onClose:()=>void;onSaved:()=>Promise<void>}){
 const [detail,setDetail]=useState<PaymentDetail|null>(null),[error,setError]=useState(''),[busy,setBusy]=useState(false),[dirty,setDirty]=useState(false),[method,setMethod]=useState('Cash');
 const pending=useRef<{key:string;fingerprint:string}|null>(null);
 useEffect(()=>{let active=true;readPaymentDetail(row.run_id,row.teacher_id).then(d=>{if(active)setDetail(d)}).catch(()=>{if(active)setError('Unable to load approved details. Close and reopen to retry.')});return()=>{active=false}},[row.run_id,row.teacher_id]);
 useEffect(()=>{const warn=(e:BeforeUnloadEvent)=>{if(dirty){e.preventDefault();e.returnValue=''}};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn)},[dirty]);
 function close(){if(!busy&&(!dirty||window.confirm('Discard unsaved payment record?')))onClose()}
 async function submit(event:FormEvent<HTMLFormElement>){
  event.preventDefault();if(busy||!detail)return;const form=event.currentTarget;if(!form.reportValidity())return;
  const values=new FormData(form),input={run_id:row.run_id,teacher_id:row.teacher_id,version:detail.summary.run_version,paid_date:String(values.get('date')||''),method,reference:String(values.get('reference')||'')};
  const fingerprint=JSON.stringify(input);if(pending.current?.fingerprint!==fingerprint)pending.current={key:crypto.randomUUID(),fingerprint};
  setBusy(true);setError('');try{const result=await recordTeacherPayment(input,pending.current!.key);if(result.error){setError(result.error);return;}pending.current=null;setDirty(false);await onSaved();onClose();}catch{setError('Unable to confirm save. Retry unchanged values safely or refresh to check the result.')}finally{setBusy(false)}
 }
 const summary=detail?.summary||row;
 return <Dialog hideClose eyebrow={draftCode(row.run_code)} title={recording?'Record full payment':'Approved teacher payroll'} onClose={close}>
  <div className="flex items-center justify-between"><strong>{summary.teacher_name}</strong><Badge status={summary.payment_status}/></div>
  <div className="info-grid">{[['Period',row.period_start+' → '+row.period_end],['Approved',teachingTime(row.approved_at)],['Gross',moneyText(summary.gross_mmk)+' MMK'],['Adjustments',moneyText(summary.adjustments_mmk)+' MMK'],['Full net amount',moneyText(summary.net_mmk)+' MMK']].map(([label,value])=><div key={label}><small>{label}</small><strong>{value}</strong></div>)}</div>
  {summary.payment_id&&<p className="request-reason">{paymentCode(summary.payment_code!)} · {summary.paid_date} · {summary.method}<br/>{summary.reference}<br/>Recorded {teachingTime(summary.recorded_at)}</p>}
  {detail?<><details className="workflow-help"><summary>Approved sessions & adjustments</summary>{detail.lines.map(l=><div className="request-reason" key={l.code}><strong>{recordCode(l.code)} · {l.class_name} · {l.subject}</strong><p>{teachingTime(l.start_at)} → {teachingTime(l.end_at)}</p><p>{l.minutes} min × {moneyText(l.hourly_mmk)} MMK/hour = {moneyText(l.amount_mmk)} MMK · rate from {l.rate_effective_from}</p></div>)}{detail.adjustments.map((a,i)=><p className="request-reason" key={i}>{moneyText(a.amount_mmk)} MMK · {a.reason}<br/>{a.reference}</p>)}{!detail.lines.length&&!detail.adjustments.length&&<p>No approved lines.</p>}</details></>:<p className="record-note">Loading approved detail…</p>}
  {recording&&summary.payment_status==='Not paid'?<form onSubmit={submit} onChange={()=>setDirty(true)}>
   <p className="admin-note">Record only after the full amount was paid outside SayaSync. This form does not transfer money. Partial payments and reversals are not available in this step.</p>
   <div className="form-grid"><label className="field"><span>Actual paid date · Myanmar</span><input name="date" type="date" required defaultValue={yangonInput(serverNow).slice(0,10)} max={yangonInput(serverNow).slice(0,10)}/></label><SelectField label="Payment method" name="method" value={method} options={paymentMethods.map(id=>({id,name:id}))} onChange={v=>{setMethod(v);setDirty(true)}}/></div>
   <label className="field"><span>Reference or cash receipt note</span><textarea name="reference" required maxLength={1000}/></label>
   <label className="field"><span><input name="confirmed" type="checkbox" style={{width:18,height:18,marginRight:8}} required/> I confirm the full {moneyText(summary.net_mmk)} MMK was paid outside SayaSync.</span></label>
   {error&&<p className="form-error" role="alert">{error}</p>}<div className="form-actions"><Button disabled={busy} onClick={close}>Cancel</Button><button className="btn primary" type="submit" disabled={busy||!detail}>{busy?'Saving…':'Record payment'}</button></div>
  </form>:<>{error&&<p className="form-error" role="alert">{error}</p>}<div className="form-actions"><Button onClick={close}>Close</Button></div></>}
 </Dialog>
}
