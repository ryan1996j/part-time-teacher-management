import {requireWorkspace} from '../../../lib/auth';
import {readCorrections} from '../../review-actions';
import {readTeachingWorkspace} from '../../session-actions';
import CorrectionsWorkspace from '../../../components/workspace/CorrectionsWorkspace';
import TeachingWorkspace from '../../../components/workspace/TeachingWorkspace';
import WorkspaceStyles from '../../../components/workspace/WorkspaceStyles';
import '../overview/native-workspace.css';
export default async function Page({searchParams}:{searchParams:Promise<{view?:string}>}){
 await requireWorkspace('admin');const params=await searchParams;
 return <><WorkspaceStyles/>{params.view==='sessions'?<TeachingWorkspace initial={await readTeachingWorkspace({filter:'Pending'})} page="reviews"/>:<CorrectionsWorkspace initial={await readCorrections({filter:'Pending'})}/>}</>;
}
