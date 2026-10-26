export interface PaymentSummary {
 run_id:string;run_code:number;period_start:string;period_end:string;approved_at:string;run_version:number;
 teacher_id:string;teacher_name:string;teacher_code:number;minutes:number;gross_mmk:string;adjustments_mmk:string;net_mmk:string;
 payment_status:'Paid'|'Not paid';payment_id:string|null;payment_code:number|null;paid_date:string|null;method:string|null;reference:string|null;recorded_at:string|null;
 paid_count?:number;teacher_count?:number;
}
export interface PaymentDetail {
 summary:PaymentSummary;
 lines:{code:number;class_name:string;subject:string;start_at:string;end_at:string;minutes:number;hourly_mmk:string;rate_effective_from:string;amount_mmk:string}[];
 adjustments:{amount_mmk:string;reason:string;reference:string}[];
}
export interface PaymentData {role:'admin'|'teacher';teacher:{id:string;name:string;code:number}|null;teachers:{id:string;name:string;code:number}[];records:PaymentSummary[];total:number;page:number;status:string;teacherFilter:string;serverNow:string}
export const paymentMethods=['Cash','Bank transfer','Mobile wallet','Other'];
export const paymentCode=(n:number)=>'PT'+String(n).padStart(4,'0');
