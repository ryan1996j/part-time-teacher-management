export interface DraftLine {
 session_id:string;code:number;teacher_id:string;teacher_name:string;teacher_code:number;class_name:string;subject:string;
 start_at:string;end_at:string|null;minutes:number|null;session_version:number;verification:string;
 rate_id:string|null;rate_effective_from:string|null;hourly_mmk:string|null;amount_mmk:string;included:boolean;reasons:string[];
}
export interface PayrollAdjustment {id:string;teacher_id:string;teacher_name:string;teacher_code:number;amount_mmk:string;reason:string;reference:string;created_at:string}
export interface DraftTeacher {teacher_id:string;teacher_name:string;teacher_code:number;minutes:number;gross_mmk:string;adjustments_mmk?:string;net_mmk?:string;included_count:number;held_count:number}
export interface PayrollSnapshot {policy:string;timezone:string;lines:DraftLine[];teachers:DraftTeacher[];minutes:number;gross_mmk:string;adjustments?:PayrollAdjustment[];adjustments_mmk?:string;net_mmk?:string;included_count:number;held_count:number}
export interface PayrollDraft {id:string;code:number;period_start:string;period_end:string;status:'Draft'|'Approved';version:number;policy_version:string;calculated_at:string;approved_at?:string|null;approved_by?:string|null;snapshot:PayrollSnapshot}
export interface DraftOption {id:string;code:number;period_start:string;period_end:string;status:'Draft'|'Approved';version:number;calculated_at:string}
export interface PayrollData {drafts:DraftOption[];selected:PayrollDraft|null;stale:boolean;page:number;total:number;serverNow:string;teachers:{id:string;name:string;code:number}[]}
export const draftCode=(n:number)=>'PD'+String(n).padStart(4,'0');
export function validPeriodDate(value:unknown):value is string {
 if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return false;
 const stamp=new Date(value+'T00:00:00Z');return Number.isFinite(stamp.getTime())&&stamp.toISOString().slice(0,10)===value;
}
export function moneyText(value:string){return BigInt(value).toLocaleString('en-US')}
export function validAdjustmentAmount(value:unknown):value is string {
 if(typeof value!=='string'||! /^[+-]?[0-9]{1,19}$/.test(value))return false;
 const n=BigInt(value);return n!==BigInt(0)&&n>=BigInt('-9223372036854775808')&&n<=BigInt('9223372036854775807');
}
