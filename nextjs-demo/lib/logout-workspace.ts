'use client';
import {signOut} from '../app/auth/actions';
import {DEMO_SESSION_KEY} from './demo-session';
export async function logoutWorkspace() {
  try {
    const result=await signOut();
    if(!result.ok)throw new Error('Sign out failed');
    sessionStorage.removeItem(DEMO_SESSION_KEY);
    // Discard the client router cache as well as the fictional UI marker.
    window.location.replace('/login');
  }catch {window.alert('Sign out could not be completed. Please try again.');}
}
