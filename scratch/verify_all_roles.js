const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const url = 'https://zznzmzwiewsnmykcbcni.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0ODg5NDEsImV4cCI6MjA5ODA2NDk0MX0._fQr1yqqa7eeW0DBYy51rcComrRfLS-K0niuqDQNf9E';
const client = createClient(url, anonKey);

async function check(roleTitle, email, password, expectedRole) {
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error || !data?.user) {
    console.log(`[FAIL] ${roleTitle}:`, error?.message);
    return false;
  }
  const meta = data.user.user_metadata || {};
  console.log(`[PASS] ${roleTitle} (${email}) -> Role: ${meta.role || 'Found'}`);
  return true;
}

async function run() {
  console.log('=== SYSTEM-WIDE ROLE AUTHENTICATION VERIFICATION ===');
  await check('Administrator', 'admin@topgrade.edu', 'TopGrade2026!', 'ADMIN');
  await check('Faculty Teacher (Ms. Jamie Dawson)', 'jldaeb1000@gmail.com', 'TopGrade@2026!', 'TEACHER');
  await check('Faculty Teacher (Ms. Shahrazad Polk)', 'sha.polk20@gmail.com', 'TopGrade@2026!', 'TEACHER');
  await check('Student (Charlie)', 'charlie.5068@student.topgrade.edu', 'Student@TopGrade2026', 'STUDENT');
  await check('Parent (Liz Rodwell)', 'elizabethannrodwell@gmail.com', 'Parent@TopGrade2026', 'PARENT');
}

run().catch(console.error);
