/* DEEP Aqua Business Suite — Supabase connection
   Get both values from Supabase → Project Settings → API.

   The "anon public" key is meant to be public: it is safe to commit to GitHub.
   Your data is protected by the row-level-security rules in supabase/setup.sql,
   and nobody gets in without a login you created.

   NEVER put the "service_role" key here. */
window.DEEP_CONFIG = {
  SUPABASE_URL: 'https://vjykmialewcqqghwjgwo.supabase.co/rest/v1/',
  SUPABASE_ANON_KEY: 'sb_publishable_RTA0fcBt32KQjfTpi0hxrQ_oogqMZf_'
};
