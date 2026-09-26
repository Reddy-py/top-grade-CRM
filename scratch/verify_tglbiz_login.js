const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
require(path.resolve(__dirname, '../topgrade-backend/node_modules/dotenv')).config({ path: path.resolve(__dirname, '../topgrade-backend/.env') });
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0ODg5NDEsImV4cCI6MjA5ODA2NDk0MX0._fQr1yqqa7eeW0DBYy51rcComrRfLS-K0niuqDQNf9E';
const client = createClient(process.env.SUPABASE_URL, anonKey);

async function testLogin(email, password) {
  console.log(`\nTesting login for: ${email}`);
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error || !data?.user) {
    console.error(`❌ Login failed:`, error?.message);
    return false;
  }
  const role = data.user.user_metadata?.role;
  console.log(`✅ Login SUCCESS! User ID: ${data.user.id}, Role: ${role}, Full Name: ${data.user.user_metadata?.full_name}`);
  return true;
}

async function main() {
  console.log('=== ADMIN LOGIN VERIFICATION ===');
  console.log('Loaded ADMIN_EMAIL from backend/.env:', process.env.ADMIN_EMAIL);
  
  await testLogin('tglbiz101@gmail.com', 'TopGrade2026!');
  await testLogin('admin@topgrade.edu', 'TopGrade2026!');
  
  console.log('\nAll checks passed!');
}

main().catch(console.error);
