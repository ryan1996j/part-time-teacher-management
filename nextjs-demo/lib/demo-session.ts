// UI demo state only; never use this marker for production authorization.
export type DemoRole = 'admin' | 'teacher';
export const DEMO_SESSION_KEY = 'ai14-blue-demo-session';
export function createDemoSession(role: DemoRole, at = new Date().toISOString()) {
  return {role,teacherId:role === 'teacher' ? 'T001' : null,name:role === 'admin' ? 'School Admin' : 'Aye Aye Win',verified:true,at};
}
export function demoDestination(role: DemoRole) { return role === 'admin' ? '/admin/overview' : '/teacher/home'; }
