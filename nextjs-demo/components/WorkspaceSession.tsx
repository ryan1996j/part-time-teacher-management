'use client';
import {useEffect,useState,type ReactNode} from 'react';
import {createDemoSession,DEMO_SESSION_KEY,type DemoRole} from '../lib/demo-session';
// Legacy screens still contain fictional sample data. This marker is UI-only.
// The server layout and proxy already verified identity and membership.
export default function WorkspaceSession({role,children}:{role:DemoRole;children:ReactNode}) {
  const [ready,setReady]=useState(false);
  useEffect(()=>{try{sessionStorage.setItem(DEMO_SESSION_KEY,JSON.stringify(createDemoSession(role)));setReady(true);}catch{}},[role]);
  return ready?children:<p role="status">Preparing workspace… Browser session storage must be enabled.</p>;
}
