import {requireWorkspace} from '../../../lib/auth';
import {readTeachingWorkspace} from '../../session-actions';
import WorkspaceStyles from '../../../components/workspace/WorkspaceStyles';
import TeachingWorkspace from '../../../components/workspace/TeachingWorkspace';
import '../overview/native-workspace.css';
export default async function Page({searchParams}:{searchParams:Promise<{status?:string;query?:string}>}) {
 await requireWorkspace('admin');const params=await searchParams;
 return <><WorkspaceStyles/><TeachingWorkspace initial={await readTeachingWorkspace({filter:params.status,query:params.query})} page="sessions"/></>;
}
