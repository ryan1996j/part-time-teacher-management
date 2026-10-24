import {redirect} from 'next/navigation';
import {requireWorkspace} from '../../lib/auth';
import {createClient} from '../../lib/supabase/server';
import WorkspaceStyles from './WorkspaceStyles';
import AppShell from './AppShell';
import {Icon} from './Ui';
import {teacherCode,classCode} from '../../lib/master-data';
import '../../app/admin/overview/native-workspace.css';

export default async function TeacherPortal({page}:{page:'home'|'sessions'|'corrections'|'payments'}) {
 const access=await requireWorkspace('teacher');
 if(!access.teacher)redirect('/login?notice=access');
 const teacher=access.teacher;
 const client=await createClient();
 // RLS returns only this linked teacher's effective assigned classes.
 const classes=await client.from('classes').select('id,code,name,subject').eq('school_id',access.schoolId).eq('active',true).order('code');
 const titles={home:'Today & check-in',sessions:'My class records',corrections:'My corrections',payments:'My payments'};
 return <><WorkspaceStyles/><AppShell role="teacher" profile={teacher} activePage={page} reviewCount={0}>
  <section className="page-head"><div><div className="eyebrow">TEACHER WORKSPACE</div><h1>{page==='home'?'မင်္ဂလာပါ '+teacher.name:titles[page]}</h1><p className="subtext">Your teaching time, records and payment status.</p></div><span className="mini-badge">{teacher.name} · {teacherCode(teacher.code)}</span></section>
  {page==='home'?<><section className="teaching-layout"><section className="clock-card"><div className="timer-status"><span className="timer-dot"/><span>Account linked</span></div><h2>Your next class</h2><p className="record-note">Check-in and class recording are the next development step. They are not available in this preview yet.</p></section><section className="card assigned-classes"><div className="card-head"><div><h2>Your assigned classes</h2><p className="subtext">Classes assigned to your school account.</p></div><Icon name="classes"/></div>{classes.error?<p className="request-reason" role="alert">Unable to load your assigned classes. Please refresh.</p>:classes.data?.length?classes.data.map(c=><div className="class-option" key={c.id}><span className="class-glyph"><Icon name="classes"/></span><div><h3>{c.subject}</h3><p>{c.name} · {classCode(c.code)}</p></div><button className="btn" disabled aria-label={'Check in to '+c.subject}><Icon name="plus"/> Check in</button></div>):<div className="empty"><Icon name="leaf"/><h3>No assigned classes</h3><p>Contact your administrator to assign a class before checking in.</p></div>}</section></section><details className="workflow-help"><summary>How your teaching time becomes pay</summary><p>Check out after class. Your administrator verifies the record, includes eligible minutes in payroll, and records your payment.</p></details></>:<section className="card"><div className="empty"><Icon name="leaf"/><h3>{titles[page]}</h3><p>This part of your teacher workspace is not connected yet. Fictional records from other teachers are not shown.</p></div></section>}
 </AppShell></>;
}
