export function getSupabaseConfig() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error('Supabase development configuration is missing.');
  const parsed = new URL(url);
  if (parsed.protocol !== 'https:') throw new Error('Supabase must use HTTPS.');
  if (!key.startsWith('sb_publishable_')) throw new Error('Use a Supabase publishable key, never a secret key.');
  return { url, key };
}
