import type {SupabaseClient} from '@supabase/supabase-js';
import {resolveAccess} from './auth-access';

export async function verifiedAccess(client:SupabaseClient,userId:string) {
 const memberships=await client.from('memberships').select('school_id,role,active').eq('user_id',userId).eq('active',true);
 const access=memberships.error?null:resolveAccess(memberships.data);
 if(!access)return null;
 if(access.role==='teacher'){
  const teacher=await client.from('teachers').select('id,name,code').eq('school_id',access.schoolId).eq('user_id',userId).eq('active',true).maybeSingle();
  if(teacher.error||!teacher.data)return null;
  return {...access,teacher:teacher.data as {id:string;name:string;code:number}};
 }
 return {...access,teacher:null};
}
