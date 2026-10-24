"use client";
import {useState, type FormEvent} from 'react';
import {useRouter} from 'next/navigation';
import Link from 'next/link';
import {createDemoSession, demoDestination, DEMO_SESSION_KEY, type DemoRole} from '../lib/demo-session';

export default function DemoEntry({initialMode='login'}:{initialMode?:'login'|'signup'}) {
  const router=useRouter();
  const [error,setError]=useState('');
  const signup=initialMode==='signup';
  const [signupComplete,setSignupComplete]=useState(false);
  function submitSignup(event:FormEvent<HTMLFormElement>){event.preventDefault();setError('');const form=event.currentTarget;if(!form.reportValidity())return;const data=new FormData(form);if(data.get('password')!==data.get('confirmPassword')){setError('Passwords do not match.');form.querySelector<HTMLInputElement>('#confirm-password')?.focus();return;}form.reset();setShowPassword(false);setSignupComplete(true);}
  const [role,setRole]=useState<DemoRole>('admin');
  const [showPassword,setShowPassword]=useState(false);
  const [recovery,setRecovery]=useState(false);
  function submit(event: FormEvent<HTMLFormElement>){event.preventDefault();event.currentTarget.reset();enter(role);}
  function enter(role: DemoRole) {
    try { sessionStorage.setItem(DEMO_SESSION_KEY,JSON.stringify(createDemoSession(role))); }
    catch {setError('Browser session storage is unavailable. Enable it to explore the demo.');return;}
    router.replace(demoDestination(role));
  }
  return <div className="login-page native-demo-entry">
    <a className="skip-link" href="#demo-entry">Skip to demo choices</a>
    <div className="layout">
      <aside className="story" aria-label="Saya-Sync">
        <a className="brand" href="/login" aria-label="Saya-Sync home"><img className="primary-logo" src="/legacy/assets/saya-sync.svg" alt="Saya-Sync" /></a>
        <h2 className="story-heading"><span lang="en">Teaching records.<br/>Clearer decisions.</span><span className="myanmar-heading" lang="my">သင်ကြားမှုမှတ်တမ်းမှ<br/>ရှင်းလင်းသော ဆုံးဖြတ်ချက်များဆီသို့</span></h2>
      </aside>
      <main className="signin">
        <div className="form-wrap">
          <h1 id="demo-entry" tabIndex={-1}>{recovery?'Account recovery':signup?'Sign up':'Sign in'}</h1>
          {signup ? <>
            <p className="auth-intro">Request access to your school workspace. An administrator must invite or approve you; signing up does not grant access.</p>
            {signupComplete?<div className="signup-feedback" role="status"><h2>Demo completed</h2><p>No account was created and no request or email was sent. Production access will require your school administrator’s invitation.</p><Link href="/login" className="primary">Back to sign in</Link></div>:<form onSubmit={submitSignup} aria-describedby="signup-note signup-error">
              <label htmlFor="full-name"><span>Full name</span><input id="full-name" name="fullName" placeholder="Your name" autoComplete="off" required maxLength={120}/></label>
              <label htmlFor="signup-email"><span>Email address</span><input id="signup-email" name="email" type="email" placeholder="you@example.com" autoComplete="off" required/></label>
              <label htmlFor="signup-password"><span>Password</span><div className="input-wrap"><input id="signup-password" name="password" type={showPassword?'text':'password'} placeholder="At least 8 characters" autoComplete="off" minLength={8} required/><button type="button" className="show" aria-label={showPassword?'Hide password':'Show password'} aria-pressed={showPassword} onClick={()=>setShowPassword(!showPassword)}>{showPassword?'Hide':'Show'}</button></div></label>
              <label htmlFor="confirm-password"><span>Confirm password</span><input id="confirm-password" name="confirmPassword" type={showPassword?'text':'password'} placeholder="Re-enter your password" autoComplete="off" minLength={8} required aria-invalid={!!error}/></label>
              <p id="signup-error" className="field-error" role="alert">{error}</p><button type="submit" className="primary">Sign up <span aria-hidden="true">→</span></button>
            </form>}
            <p className="auth-switch">Already have access? <Link href="/login">Sign in</Link></p>
            <p id="signup-note" className="auth-demo-note">Local UI demo only. Use fictional details and a sample password. Nothing is saved or sent. No Admin role can be selected during sign up.</p>
          </> : recovery ? <div className="login-recovery"><p>This local preview does not send password reset emails. Production recovery will use Supabase Auth.</p><button type="button" className="primary" onClick={()=>setRecovery(false)}>Back to sign in</button></div> : <>
            <form onSubmit={submit} noValidate aria-describedby="preview-note">
              <label htmlFor="email"><span>Email address</span><input id="email" name="email" type="email" autoComplete="off" placeholder="you@example.com" /></label>
              <label htmlFor="password"><span>Password</span><div className="input-wrap"><input id="password" name="password" type={showPassword?'text':'password'} autoComplete="off" placeholder="Enter your password" /><button type="button" className="show" aria-label={showPassword?'Hide password':'Show password'} aria-pressed={showPassword} onClick={()=>setShowPassword(!showPassword)}>{showPassword?'Hide':'Show'}</button></div></label>
              <p className="field-error" id="entry-error" role="alert">{error}</p>
              <button className="primary" type="submit">Sign in <span aria-hidden="true">→</span></button>
            </form>
            <button type="button" className="recovery-link" onClick={()=>setRecovery(true)}>Forgot password?</button>
            <p className="auth-switch">Need access? <Link href="/signup">Sign up</Link></p>
            <div className="preview-controls"><p id="preview-note">Local UI preview only. Do not enter real credentials. Inputs are not checked, stored or sent. Select a demo role, then Sign in.</p><div className="preview-roles" role="group" aria-label="Demo role"><button type="button" aria-pressed={role==='admin'} onClick={()=>setRole('admin')}>Admin demo</button><button type="button" aria-pressed={role==='teacher'} onClick={()=>setRole('teacher')}>Teacher demo</button></div></div>
          </> }
        </div>
      </main>
    </div>
  </div>;
}
