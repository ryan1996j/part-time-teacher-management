"use client";
import {useRouter} from 'next/navigation';
/** Compatibility boundary for workspace screens not yet migrated to React. */
export default function LegacyPreview({role,page}:{role?:'admin'|'teacher';page?:string}) {
 const router=useRouter();const src=role&&page?`/legacy/index.html#${page}`:'/legacy/login.html';
 return <iframe title="SayaSync interactive prototype" src={src} sandbox="allow-scripts allow-same-origin allow-forms allow-modals allow-downloads" onLoad={event=>{
  const win=event.currentTarget.contentWindow;if(!win)return;
  try{
   if(win.location.pathname==='/legacy/login.html'){router.replace('/login');return}
   const params=new URLSearchParams(window.location.search),filter=new URLSearchParams();
   for(const key of ['status','view','tab','run']){const value=params.get(key);if(value)filter.set(key,value)}
   if(filter.size)win.location.hash=page+'?'+filter.toString();
   win.addEventListener('hashchange',()=>{if(role==='admin'&&win.location.hash==='#overview')router.replace('/admin/overview')});
   const action=params.get('action'),id=params.get('id')||'';
   if(action&&['session-detail','request','verify','review','add-session'].includes(action)){
    win.requestAnimationFrame(()=>{const button=win.document.createElement('button');button.dataset.action=action;button.dataset.id=id;button.hidden=true;win.document.body.appendChild(button);button.click();button.remove()});
   }
  }catch{/* Access is limited to the same-origin demo. */}
 }}/>
}
