import MasterDataPage from '../../../components/workspace/MasterDataPage';
import WorkspaceStyles from '../../../components/workspace/WorkspaceStyles';
import {readMasterData} from '../master-actions';
import '../overview/native-workspace.css';
export default async function Page(){return <><WorkspaceStyles/><MasterDataPage initial={await readMasterData()} page="classes"/></>}
