'use client';
import { createBrowserClient } from '@supabase/ssr';
import { getSupabaseConfig } from './config';

// Prepared for the real authentication slice; the demo entry does not call this.
export function createClient() {
  const { url, key } = getSupabaseConfig();
  return createBrowserClient(url, key);
}
