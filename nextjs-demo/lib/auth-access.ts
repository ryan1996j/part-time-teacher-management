export type Membership = {school_id:string;role:string;active:boolean};
export function resolveAccess(rows:Membership[] | null) {
  const active=(rows||[]).filter(row=>row.active && ['admin','teacher'].includes(row.role));
  // Pilot supports one school per session. Never silently pick another school.
  if(active.length!==1)return null;
  const row=active[0];
  return {schoolId:row.school_id,role:row.role as 'admin'|'teacher'};
}
