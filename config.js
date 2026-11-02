/* DEEP Aqua Business Suite — Supabase connection
   Get both values from Supabase → Project Settings → API.

   The "anon public" key is meant to be public: it is safe to commit to GitHub.
   Your data is protected by the row-level-security rules in supabase/setup.sql,
   and nobody gets in without a login you created.

   NEVER put the "service_role" key here. */
window.DEEP_CONFIG = {
  SUPABASE_URL: 'https://vjykmialewcqqghwjgwo.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZqeWttaWFsZXdjcXFnaHdqZ3dvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM1OTA5MjEsImV4cCI6MjEwOTE2NjkyMX0.u_4sNdB2gvqBdldePnO_G9jWTw9ISauwzYVisFRNBYI'
};
