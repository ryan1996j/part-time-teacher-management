import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { getSupabaseConfig } from './config';

// Use per request. This helper alone does not grant workspace access.
export async function createClient() {
  const { url, key } = getSupabaseConfig();
  const cookieStore = await cookies();
  return createServerClient(url, key, {
    cookies: {
      getAll() { return cookieStore.getAll(); },
      setAll(cookiesToSet) {
        // Proxy handles refresh cookies before read-only Server Components render.
        try {for (const { name, value, options } of cookiesToSet) cookieStore.set(name, value, options);}
        catch(error) {if (!(error instanceof Error && error.message.includes('Cookies can only be modified'))) throw error;}
      },
    },
  });
}
