import {readPayrollDrafts} from '../../payroll-actions';
import WorkspaceStyles from '../../../components/workspace/WorkspaceStyles';
import PayrollWorkspace from '../../../components/workspace/PayrollWorkspace';
import '../overview/native-workspace.css';
export default async function Page(){return <><WorkspaceStyles/><PayrollWorkspace initial={await readPayrollDrafts()}/></>}
