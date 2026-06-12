// ─────────────────────────────────────────────────────────────────
//  Courseific Sessions · Supabase Client Configuration
//
//  Replace the two placeholder values below with your project's
//  credentials from:
//    Supabase Dashboard → Project Settings → API
//
//  The anon key is safe to commit — security is enforced by RLS.
// ─────────────────────────────────────────────────────────────────

const SUPABASE_URL      = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';

window._supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession:    true,   // keeps admin logged in across page refreshes
    autoRefreshToken:  true
  }
});
