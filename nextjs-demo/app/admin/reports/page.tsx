import {readReports} from '../../report-actions';
import ReportsWorkspace from '../../../components/workspace/ReportsWorkspace';
import WorkspaceStyles from '../../../components/workspace/WorkspaceStyles';
import '../overview/native-workspace.css';
export default async function Page(){return <><WorkspaceStyles/><ReportsWorkspace initial={await readReports()}/></>}
