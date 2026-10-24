import {requireWorkspace} from '../../lib/auth';
import WorkspaceSession from '../../components/WorkspaceSession';
export const dynamic='force-dynamic';
export default async function Layout({children}:{children:React.ReactNode}) {
  const access=await requireWorkspace('admin');
  return <WorkspaceSession role={access.role}>{children}</WorkspaceSession>;
}
