export interface DbTeacher {id:string;code:number;name:string;email:string;active:boolean;version:number;user_id:string|null;account_state?:string}
export interface DbClass {id:string;code:number;name:string;subject:string;active:boolean;version:number}
export interface DbRate {id:string;teacher_id:string;effective_from:string;hourly_mmk:number}
export interface DbAssignment {id:string;teacher_id:string;class_id:string;effective_from:string}
export interface MasterData {teachers:DbTeacher[];classes:DbClass[];rates:DbRate[];assignments:DbAssignment[]}
export const teacherCode=(code:number)=>'T'+String(code).padStart(3,'0');
export const classCode=(code:number)=>'C'+String(code).padStart(3,'0');
export const schoolDate=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Yangon',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
