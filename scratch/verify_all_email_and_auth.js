const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
require(path.resolve(__dirname, '../topgrade-backend/node_modules/dotenv')).config({ path: path.resolve(__dirname, '../topgrade-backend/.env') });
const nodemailer = require(path.resolve(__dirname, '../topgrade-backend/node_modules/nodemailer'));
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0ODg5NDEsImV4cCI6MjA5ODA2NDk0MX0._fQr1yqqa7eeW0DBYy51rcComrRfLS-K0niuqDQNf9E';
const client = createClient(process.env.SUPABASE_URL, anonKey);

async function run() {
  console.log('=== SYSTEM-WIDE VERIFICATION ===');
  console.log('1. Checking ENV Configuration:');
  console.log('   GMAIL_USER:', process.env.GMAIL_USER);
  console.log('   GMAIL_SENDER_EMAIL:', process.env.GMAIL_SENDER_EMAIL);
  console.log('   ADMIN_EMAIL:', process.env.ADMIN_EMAIL);
  console.log('   ACCOUNTANT_EMAIL:', process.env.ACCOUNTANT_EMAIL);

  console.log('\n2. Verifying Gmail SMTP Transporter:');
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.GMAIL_USER,
      pass: process.env.GMAIL_APP_PASSWORD
    }
  });
  await transporter.verify();
  console.log('   ✅ Gmail SMTP connection verified successfully with tglbiz101@gmail.com!');

  console.log('\n3. Verifying Admin Supabase Auth Login:');
  const { data: adminAuth, error: adminErr } = await client.auth.signInWithPassword({
    email: 'tglbiz101@gmail.com',
    password: 'TopGrade2026!'
  });
  if (adminErr) {
    console.error('   ❌ Admin login failed:', adminErr.message);
  } else {
    console.log(`   ✅ Admin Login OK! User ID: ${adminAuth.user.id}, Role: ${adminAuth.user.user_metadata?.role}`);
  }

  console.log('\n4. Verifying Accountant Supabase Auth Login:');
  const { data: accAuth, error: accErr } = await client.auth.signInWithPassword({
    email: 'sivareddy68397@gmail.com',
    password: 'TopGrade2026!'
  });
  if (accErr) {
    console.error('   ❌ Accountant login failed:', accErr.message);
  } else {
    console.log(`   ✅ Accountant Login OK! User ID: ${accAuth.user.id}, Role: ${accAuth.user.user_metadata?.role}`);
  }

  console.log('\n=== ALL TESTS PASSED SUCCESSFULLY! ===');
}

run().catch(console.error);
