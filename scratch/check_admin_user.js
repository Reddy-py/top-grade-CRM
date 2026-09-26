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
  console.log('ENV ADMIN_EMAIL:', process.env.ADMIN_EMAIL);
  console.log('ENV GMAIL_SENDER_EMAIL:', process.env.GMAIL_SENDER_EMAIL);

  const { data: usersData, error } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
  if (error) {
    console.error('Error listing users:', error);
    return;
  }

  const matches = usersData.users.filter(u => 
    u.email?.toLowerCase().includes('tglbiz') || 
    u.email?.toLowerCase().includes('topgrade') ||
    u.email?.toLowerCase().includes('admin')
  );

  console.log('Found users:');
  for (const u of matches) {
    console.log(`- ID: ${u.id}, Email: ${u.email}, Meta:`, JSON.stringify(u.user_metadata));
  }
}

main().catch(console.error);
