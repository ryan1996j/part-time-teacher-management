import type {PaymentSummary} from './payment-types';
export interface ReportFilters {start:string;end:string;teacher:string;status:string}
export interface FinanceTotals {approved:string;paid:string;unpaid:string;gross:string;adjustments:string;minutes:number;count:number}
export function filterReport(rows:PaymentSummary[],f:ReportFilters){return rows.filter(x=>(!f.start||x.period_end>=f.start)&&(!f.end||x.period_start<=f.end)&&(!f.teacher||x.teacher_id===f.teacher)&&(!f.status||x.payment_status===f.status));}
export function financeTotals(rows:PaymentSummary[]):FinanceTotals {
 let approved=BigInt(0),paid=BigInt(0),gross=BigInt(0),adjustments=BigInt(0),minutes=0;
 for(const x of rows){const net=BigInt(x.net_mmk);approved+=net;if(x.payment_status==='Paid')paid+=net;gross+=BigInt(x.gross_mmk);adjustments+=BigInt(x.adjustments_mmk);minutes+=x.minutes;}
 return {approved:String(approved),paid:String(paid),unpaid:String(approved-paid),gross:String(gross),adjustments:String(adjustments),minutes,count:rows.length};
}
// Quote every field and neutralize spreadsheet formulas, including leading whitespace/control characters.
export function csvCell(value:unknown){let text=String(value??'');if(/^[\s\u0000-\u001f]*[=+@-]/u.test(text))text="'"+text;return '"'+text.replaceAll('"','""')+'"';}
export function reportCsv(rows:PaymentSummary[]){
 const header=['Payroll','Period start','Period end','Teacher code','Teacher','Teaching minutes','Gross MMK','Adjustments MMK','Net MMK','Payment status','Paid date','Method','Receipt code','Reference'];
 const data=rows.map(x=>['PD'+String(x.run_code).padStart(4,'0'),x.period_start,x.period_end,'T'+String(x.teacher_code).padStart(3,'0'),x.teacher_name,x.minutes,x.gross_mmk,x.adjustments_mmk,x.net_mmk,x.payment_status,x.paid_date,x.method,x.payment_code===null?'':'PT'+String(x.payment_code).padStart(4,'0'),x.reference]);
 return '\ufeff'+[header,...data].map(row=>row.map(csvCell).join(',')).join('\r\n')+'\r\n';
}
export interface ReportData {records:PaymentSummary[];totals:FinanceTotals;filters:ReportFilters;teachers:{id:string;name:string;code:number}[];generatedAt:string;page:number;total:number}
