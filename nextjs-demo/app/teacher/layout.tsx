import {requireWorkspace} from '../../lib/auth';
export const dynamic='force-dynamic';
export default async function Layout({children}:{children:React.ReactNode}) {
  await requireWorkspace('teacher');
  return <>{children}</>;
}
