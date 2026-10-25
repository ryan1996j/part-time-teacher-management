import {redirect} from 'next/navigation';
import {requireWorkspace} from '../../lib/auth';
import {readTeachingWorkspace} from '../../app/session-actions';
import WorkspaceStyles from './WorkspaceStyles';
import TeachingWorkspace from './TeachingWorkspace';
import {readCorrections} from '../../app/review-actions';
import CorrectionsWorkspace from './CorrectionsWorkspace';
import {readPayments} from '../../app/payment-actions';
import PaymentsWorkspace from './PaymentsWorkspace';
import '../../app/admin/overview/native-workspace.css';

export default async function TeacherPortal({page}:{page:'home'|'sessions'|'corrections'|'payments'}) {
 const access=await requireWorkspace('teacher');
 if(!access.teacher)redirect('/login?notice=access');
 if(page==='home'||page==='sessions')return <><WorkspaceStyles/><TeachingWorkspace initial={await readTeachingWorkspace()} page={page}/></>;
 if(page==='corrections')return <><WorkspaceStyles/><CorrectionsWorkspace initial={await readCorrections()}/></>;
 return <><WorkspaceStyles/><PaymentsWorkspace initial={await readPayments()}/></>;
}
