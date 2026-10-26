export interface TeachingRecord {
 id:string;code:number;teacher_id:string;class_id:string;teacher_name:string;teacher_code:number;
 class_name:string;class_code:number;subject:string;start_at:string;end_at:string|null;
 original_start_at:string;original_end_at:string|null;verification:string;record_status:string;
 source:string;reason:string;overlap_flag:boolean;minutes:number|null;version:number;
 overlap_resolution:string;review_comment:string;reviewed_at:string|null;pending_correction:boolean;
 payroll_locked?:boolean;
}
export interface TeachingClass {id:string;code:number;name:string;subject:string;active:boolean}
export interface TeachingTeacher {id:string;code:number;name:string;active:boolean}
export interface TeachingAssignment {teacher_id:string;class_id:string;effective_from:string;effective_to:string|null}
export interface TeachingData {
 role:'admin'|'teacher';teacher:{id:string;name:string;code:number}|null;serverNow:string;
 records:TeachingRecord[];open:TeachingRecord|null;total:number;page:number;pageSize:number;filter:string;query:string;
 classes:TeachingClass[];teachers:TeachingTeacher[];assignments:TeachingAssignment[];
}
export const recordCode=(code:number)=>'S'+String(code).padStart(4,'0');
export function yangonInputToISO(value:string) {
 if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value))throw new Error('Enter a valid date and time.');
 const calendar=new Date(value+':00Z');
 if(!Number.isFinite(calendar.getTime())||calendar.toISOString().slice(0,16)!==value)throw new Error('Enter a valid date and time.');
 return new Date(value+':00+06:30').toISOString();
}
export function yangonInput(value:string) {
 return new Date(new Date(value).getTime()+390*60000).toISOString().slice(0,16);
}
export function assignedAt(a:TeachingAssignment,teacherId:string,classId:string,at:string) {
 const time=Date.parse(at);return a.teacher_id===teacherId&&a.class_id===classId&&Date.parse(a.effective_from)<=time&&(!a.effective_to||Date.parse(a.effective_to)>time);
}
