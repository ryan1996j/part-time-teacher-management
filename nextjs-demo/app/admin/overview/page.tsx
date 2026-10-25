import AdminOverview from '../../../components/workspace/AdminOverview';
import WorkspaceStyles from '../../../components/workspace/WorkspaceStyles';
import {readAdminOverview} from '../../overview-actions';
import './native-workspace.css';
export default async function Page(){return <><WorkspaceStyles/><AdminOverview initial={await readAdminOverview()}/></>}
