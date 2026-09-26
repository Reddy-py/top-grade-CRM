const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
require(path.resolve(__dirname, '../topgrade-backend/node_modules/dotenv')).config({ path: path.resolve(__dirname, '../topgrade-backend/.env') });
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

async function main() {
  const { data: usersData, error } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
  if (error) {
    console.error('Error listing users:', error);
    return;
  }
  const u = usersData.users.find(x => x.email?.toLowerCase() === 'tglbiz101@gmail.com');
  console.log('User tglbiz101@gmail.com in Supabase Auth:', u ? { id: u.id, email: u.email, meta: u.user_metadata } : 'NOT FOUND');

  const { data: profiles, error: pErr } = await supabaseAdmin.from('profiles').select('*').eq('email', 'tglbiz101@gmail.com');
  console.log('Profiles table for tglbiz101@gmail.com:', profiles);
}

main().catch(console.error);
