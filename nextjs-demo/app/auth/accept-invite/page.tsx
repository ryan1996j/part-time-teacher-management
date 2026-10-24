'use client';
import { useEffect, useState, type FormEvent } from 'react';
import { createBrowserClient } from '@supabase/ssr';
import type { SupabaseClient } from '@supabase/supabase-js';
import { getSupabaseConfig } from '../../../lib/supabase/config';
import Link from 'next/link';

let acceptance: Promise<SupabaseClient> | undefined;
function acceptInvitation() {
  if (acceptance) return acceptance;
  acceptance = (async () => {
    const fragment = new URLSearchParams(window.location.hash.slice(1));
    const access = fragment.get('access_token');
    const refresh = fragment.get('refresh_token');
    const kind = fragment.get('type');
    // Remove tokens from the address bar before making any requests.
    window.history.replaceState(null, '', window.location.pathname);
    if (!access || !refresh || kind !== 'invite') throw new Error('Open the invitation link from your email. If it expired, request a new invitation.');
    const { url, key } = getSupabaseConfig();
    const client = createBrowserClient(url, key, { auth: { detectSessionInUrl: false } });
    const { error } = await client.auth.setSession({ access_token: access, refresh_token: refresh });
    if (error) throw new Error('The invitation could not be verified. Request a new invitation.');
    const verified = await client.auth.getUser();
    if (verified.error || !verified.data.user) {
      await client.auth.signOut();
      throw new Error('The invitation could not be verified. Request a new invitation.');
    }
    return client;
  })();
  return acceptance;
}

export default function AcceptInvite() {
  const [client, setClient] = useState<SupabaseClient | null>(null);
  const [status, setStatus] = useState('Verifying invitation…');
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  useEffect(() => { let mounted = true; acceptInvitation().then(value => { if (mounted) {setClient(value); setStatus('Invitation verified. Set your password below.');} }).catch((error: Error) => { if (mounted) setStatus(error.message); }); return () => {mounted = false;}; }, []);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!client || busy) return;
    const form = event.currentTarget;
    const data = new FormData(form);
    const password = String(data.get('password') || '');
    if (password.length < 12 || password !== data.get('confirmation')) {setStatus('Use at least 12 characters and matching passwords.'); return;}
    setBusy(true);
    const { error } = await client.auth.updateUser({ password });
    form.reset();
    if (error) {setStatus('Password setup failed. Try again or request a new invitation.'); setBusy(false); return;}
    await client.auth.signOut();
    setClient(null); setDone(true); setBusy(false);
    setStatus('Password saved. Sign in with your invited email. School access requires an active administrator-approved membership and teacher profile link.');
  }
  return <main style={{maxWidth:440,margin:'60px auto',padding:24,fontFamily:'sans-serif',lineHeight:1.6}}>
    <h1>SayaSync · Accept invitation</h1>
    <p>Development account setup for Ryan’s school. This page sets a real Supabase password. Do not share it in chat.</p>
    <p role="status">{status}</p>
    {client && !done && <form onSubmit={submit}>
      <label>New password<input name="password" type="password" autoComplete="new-password" minLength={12} required style={{display:'block',width:'100%',padding:10,marginBottom:16}} /></label>
      <label>Confirm password<input name="confirmation" type="password" autoComplete="new-password" minLength={12} required style={{display:'block',width:'100%',padding:10,marginBottom:16}} /></label>
      <button disabled={busy} type="submit" style={{padding:'12px 20px',background:'#007acb',color:'white',border:0,borderRadius:8}}>{busy?'Saving…':'Set password'}</button>
    </form>}
    {done && <Link href="/login">Back to sign in</Link>}
  </main>;
}
