'use server';
import {createClient} from '../../lib/supabase/server';
import {verifiedAccess} from '../../lib/verified-access';

export async function signIn(form:FormData) {
  const email=String(form.get('email')||'').trim();
  const password=String(form.get('password')||'');
  const denied={error:'Unable to sign in. Check your details or contact your school administrator.'};
  if(!email || email.length>254 || !email.includes('@') || !password || password.length>1024)return denied;
  try {
    const client=await createClient();
    const result=await client.auth.signInWithPassword({email,password});
    if(result.error || !result.data.user)return denied;
    const verified=await client.auth.getUser();
    if(verified.error || !verified.data.user?.email_confirmed_at){await client.auth.signOut();return denied;}
    const access=await verifiedAccess(client,verified.data.user.id);
    if(!access){await client.auth.signOut();return denied;}
    return {role:access.role,destination:access.role==='admin'?'/admin/overview':'/teacher/home'};
  }catch{return denied;}
}

export async function signOut() {
  const client=await createClient();
  const {error}=await client.auth.signOut();
  return {ok:!error};
}
