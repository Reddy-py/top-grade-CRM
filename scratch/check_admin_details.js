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
  const { data: usersData } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
  const adminUsers = usersData.users.filter(u => u.email?.includes('admin') || u.user_metadata?.role === 'ADMIN');
  console.log('Admin users in Supabase Auth:', adminUsers.map(u => ({ id: u.id, email: u.email, meta: u.user_metadata })));

  const { data: profiles } = await supabaseAdmin.from('profiles').select('*').eq('role', 'ADMIN');
  console.log('Admin profiles in DB:', profiles);
}

main().catch(console.error);
