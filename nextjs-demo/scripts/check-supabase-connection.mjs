import { readFile } from 'node:fs/promises';
const entries = (await readFile(new URL('../.env.local', import.meta.url), 'utf8')).split(/\r?\n/).filter(line => line && !line.startsWith('#')).map(line => { const split = line.indexOf('='); return [line.slice(0, split), line.slice(split + 1)]; });
const env = Object.fromEntries(entries);
const url = new URL(env.NEXT_PUBLIC_SUPABASE_URL);
if (url.hostname !== 'ereyjhtkypeowifrmyqv.supabase.co' || url.protocol !== 'https:') throw new Error('Unexpected development project.');
const response = await fetch(new URL('/auth/v1/settings', url), { headers: { apikey: env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY }, signal: AbortSignal.timeout(15000) });
if (!response.ok) throw new Error(`Supabase Auth settings request failed: ${response.status}`);
const settings = await response.json();
console.log(JSON.stringify({ project: 'ereyjhtkypeowifrmyqv', connected: true, emailProviderEnabled: settings.external?.email, publicSignupDisabled: settings.disable_signup, emailAutoConfirm: settings.mailer_autoconfirm }, null, 2));
