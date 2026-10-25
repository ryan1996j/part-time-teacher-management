import {redirect} from 'next/navigation';
import {createClient} from './supabase/server';
import {verifiedAccess} from './verified-access';

export async function requireSchoolAccess() {
  const client=await createClient();
  const {data:{user},error}=await client.auth.getUser();
  if(error || !user || !user.email_confirmed_at)redirect('/login');
  const access=await verifiedAccess(client,user.id);
  if(!access)redirect('/login?notice=access');
  return access;
}
export async function requireWorkspace(role:'admin'|'teacher') {
  const access=await requireSchoolAccess();
  if(access.role!==role)redirect(access.role==='admin'?'/admin/overview':'/teacher/home');
  return access;
}
