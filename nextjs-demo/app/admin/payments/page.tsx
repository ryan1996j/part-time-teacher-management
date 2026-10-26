import {requireWorkspace} from '../../../lib/auth';
import {readPayments} from '../../payment-actions';
import WorkspaceStyles from '../../../components/workspace/WorkspaceStyles';
import PaymentsWorkspace from '../../../components/workspace/PaymentsWorkspace';
import '../overview/native-workspace.css';
export default async function Page(){await requireWorkspace('admin');return <><WorkspaceStyles/><PaymentsWorkspace initial={await readPayments()}/></>}
