import { createClient } from "@supabase/supabase-js";

// These come from Vite env vars. Set them in a local `.env` file for development
// and in the Vercel project settings for production. They are SAFE to expose to
// the browser: the anon key only grants what your Row-Level Security policies allow.
const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  // Fail loudly during setup instead of silently producing a broken app.
  console.error(
    "Missing Supabase config. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY " +
    "in app/.env (local) and in Vercel project settings (production)."
  );
}

export const supabase = createClient(url, anonKey, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
});
