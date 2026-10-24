import {createServerClient} from '@supabase/ssr';
import {NextResponse,type NextRequest} from 'next/server';
import {getSupabaseConfig} from './lib/supabase/config';
import {verifiedAccess} from './lib/verified-access';

export async function proxy(request:NextRequest) {
  let response=NextResponse.next({request});
  const {url,key}=getSupabaseConfig();
  const client=createServerClient(url,key,{cookies:{
    getAll(){return request.cookies.getAll();},
    setAll(values){
      values.forEach(({name,value})=>request.cookies.set(name,value));
      response=NextResponse.next({request});
      values.forEach(({name,value,options})=>response.cookies.set(name,value,options));
    },
  }});
  const pathname=request.nextUrl.pathname;
  const protectedPath=pathname.startsWith('/admin')||pathname.startsWith('/teacher')||pathname==='/legacy/index.html';
  function finish(destination?:string) {
    if(destination){const redirected=NextResponse.redirect(new URL(destination,request.url));response.cookies.getAll().forEach(cookie=>redirected.cookies.set(cookie));response=redirected;}
    response.headers.set('Cache-Control','private, no-store, max-age=0');
    response.headers.set('Pragma','no-cache');response.headers.set('Expires','0');
    return response;
  }
  try {
    // Verify with Auth on each protected request; browser role markers are ignored.
    const verified=await client.auth.getUser();
    const user=verified.data.user;
    if(!protectedPath)return finish();
    if(verified.error || !user?.email_confirmed_at)return finish('/login');
    const access=await verifiedAccess(client,user.id);
    if(!access)return finish('/login?notice=access');
    if(pathname==='/legacy/index.html'&&access.role==='teacher')return finish('/teacher/home');
    if(pathname.startsWith('/admin')&&access.role!=='admin')return finish('/teacher/home');
    if(pathname.startsWith('/teacher')&&access.role!=='teacher')return finish('/admin/overview');
    return finish();
  }catch{return finish(protectedPath?'/login':undefined);}
}

export const config={matcher:['/admin/:path*','/teacher/:path*','/legacy/index.html','/login','/signup','/auth/:path*']};
