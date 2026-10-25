import type {TeachingRecord} from './teaching-types';
export interface CorrectionRecord {
 id:string;code:number;session_id:string;session_code:number;base_version:number;session_version:number;
 teacher_name:string;teacher_code:number;class_name:string;subject:string;proposed_start:string;proposed_end:string;
 start_at:string;end_at:string|null;original_start_at:string;original_end_at:string|null;
 reason:string;status:string;requested_by:string;created_at:string;review_comment:string;reviewed_at:string|null;version:number;
 prior_snapshot:TeachingRecord;
}
export interface CorrectionData {
 role:'admin'|'teacher';teacher:{id:string;name:string;code:number}|null;actor:string;
 records:CorrectionRecord[];total:number;page:number;filter:string;
}
export const correctionCode=(n:number)=>'CR'+String(n).padStart(4,'0');
export const teachingTime=(v:string|null)=>v?new Date(v).toLocaleString('en-GB',{timeZone:'Asia/Yangon',day:'2-digit',month:'short',year:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit'}):'—';
