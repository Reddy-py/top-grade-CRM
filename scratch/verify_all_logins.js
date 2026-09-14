const fs = require('fs');
const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const url = 'https://zznzmzwiewsnmykcbcni.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0ODg5NDEsImV4cCI6MjA5ODA2NDk0MX0._fQr1yqqa7eeW0DBYy51rcComrRfLS-K0niuqDQNf9E';
// Use regular client (anon key) to simulate actual client app authentication!
const client = createClient(url, anonKey);

async function testLogin(emailOrCode, password, expectedRole, expectedName) {
  let targetEmail = emailOrCode.trim().toLowerCase();

  // If code, resolve to email like AuthContext
  if (!targetEmail.includes('@')) {
    const { data: stu, error: stuErr } = await client
      .from('students')
      .select('email, student_id_code, name')
      .ilike('student_id_code', targetEmail)
      .maybeSingle();

    if (stuErr || !stu) {
      return { success: false, error: `Student code lookup failed: ${stuErr?.message || 'Not found'}` };
    }
    targetEmail = stu.email.toLowerCase();
  }

  const { data, error } = await client.auth.signInWithPassword({
    email: targetEmail,
    password: password
  });

  if (error || !data?.user) {
    return { success: false, error: error?.message || 'Login failed' };
  }

  const meta = data.user.user_metadata || {};
  const role = meta.role;
  const fullName = meta.full_name;
  const childName = meta.child_name;

  return {
    success: true,
    email: data.user.email,
    role,
    fullName,
    childName,
    meta
  };
}

async function runVerification() {
  console.log('=== STARTING END-TO-END AUTHENTICATION TEST ===\n');

  const testCases = [
    {
      title: 'Student Login by Code (Charlie)',
      input: 'TG-STU-2026-5068',
      password: 'Student@TopGrade2026',
      expectedRole: 'STUDENT',
      expectedName: 'Charlie'
    },
    {
      title: 'Student Login by Email (Charlie)',
      input: 'charlie.5068@student.topgrade.edu',
      password: 'Student@TopGrade2026',
      expectedRole: 'STUDENT',
      expectedName: 'Charlie'
    },
    {
      title: 'Parent Login by Personal Email (Liz Rodwell)',
      input: 'elizabethannrodwell@gmail.com',
      password: 'Parent@TopGrade2026',
      expectedRole: 'PARENT',
      expectedName: 'Liz Rodwell'
    },
    {
      title: 'Parent Login by Institutional Email (Liz Rodwell)',
      input: 'parent.liz.rodwell.5068@parents.topgrade.edu',
      password: 'Parent@TopGrade2026',
      expectedRole: 'PARENT',
      expectedName: 'Liz Rodwell'
    },
    {
      title: 'Student Login by Code (Charlotte)',
      input: 'TG-STU-2026-5067',
      password: 'Student@TopGrade2026',
      expectedRole: 'STUDENT',
      expectedName: 'Charlotte'
    },
    {
      title: 'Parent Login by Personal Email (Frank Fernandez)',
      input: 'ftfern24@yahoo.com',
      password: 'Parent@TopGrade2026',
      expectedRole: 'PARENT',
      expectedName: 'Frank Fernandez'
    },
    {
      title: 'Student Login by Code (Jacob)',
      input: 'TG-STU-2026-5001',
      password: 'Student@TopGrade2026',
      expectedRole: 'STUDENT',
      expectedName: 'Jacob'
    },
    {
      title: 'Parent Login by Personal Email (Tanyea Fowls)',
      input: 'tanyeafowls@yahoo.com',
      password: 'Parent@TopGrade2026',
      expectedRole: 'PARENT',
      expectedName: 'Tanyea Fowls'
    },
    {
      title: 'Student Login by Code (Evan Li)',
      input: 'TG-STU-2026-5064',
      password: 'Student@TopGrade2026',
      expectedRole: 'STUDENT',
      expectedName: 'Evan Li'
    },
    {
      title: 'Parent Login by Personal Email (Ke Li)',
      input: 'ke.li@outlook.com',
      password: 'Parent@TopGrade2026',
      expectedRole: 'PARENT',
      expectedName: 'Ke Li'
    }
  ];

  let passed = 0;
  for (const tc of testCases) {
    const res = await testLogin(tc.input, tc.password, tc.expectedRole, tc.expectedName);
    if (res.success && res.role === tc.expectedRole) {
      console.log(`[PASS] ${tc.title}`);
      console.log(`       Authenticated: ${res.email}`);
      console.log(`       Role: ${res.role} | Full Name: ${res.fullName}${res.childName ? ` | Child: ${res.childName}` : ''}`);
      passed++;
    } else {
      console.log(`[FAIL] ${tc.title}`);
      console.log(`       Error: ${res.error || 'Role mismatch'}`);
    }
    console.log('----------------------------------------------------');
  }

  console.log(`\nSUMMARY: ${passed} / ${testCases.length} Tests Passed successfully.`);
}

runVerification().catch(console.error);
