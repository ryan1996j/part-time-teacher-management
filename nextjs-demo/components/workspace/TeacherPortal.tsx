import {redirect} from 'next/navigation';
import {requireWorkspace} from '../../lib/auth';
import {readTeachingWorkspace} from '../../app/session-actions';
import WorkspaceStyles from './WorkspaceStyles';
import TeachingWorkspace from './TeachingWorkspace';
import {readCorrections} from '../../app/review-actions';
import CorrectionsWorkspace from './CorrectionsWorkspace';
import AppShell from './AppShell';
import {Icon} from './Ui';
import {teacherCode} from '../../lib/master-data';
import '../../app/admin/overview/native-workspace.css';

export default async function TeacherPortal({page}:{page:'home'|'sessions'|'corrections'|'payments'}) {
 const access=await requireWorkspace('teacher');
 if(!access.teacher)redirect('/login?notice=access');
 if(page==='home'||page==='sessions')return <><WorkspaceStyles/><TeachingWorkspace initial={await readTeachingWorkspace()} page={page}/></>;
 if(page==='corrections')return <><WorkspaceStyles/><CorrectionsWorkspace initial={await readCorrections()}/></>;
 const teacher=access.teacher;
 const title='My payments';
 return <><WorkspaceStyles/><AppShell role="teacher" profile={teacher} activePage={page} reviewCount={0}>
  <section className="page-head"><div><div className="eyebrow">TEACHER WORKSPACE</div><h1>{title}</h1><p className="subtext">Your teaching time, records and payment status.</p></div><span className="mini-badge">{teacher.name} · {teacherCode(teacher.code)}</span></section>
  <section className="card"><div className="empty"><Icon name="leaf"/><h3>{title}</h3><p>This part of your teacher workspace is not connected yet. Fictional records from other teachers are not shown.</p></div></section>
 </AppShell></>;
}
