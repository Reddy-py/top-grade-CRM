const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const url = 'https://zznzmzwiewsnmykcbcni.supabase.co';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0ODg5NDEsImV4cCI6MjA5ODA2NDk0MX0._fQr1yqqa7eeW0DBYy51rcComrRfLS-K0niuqDQNf9E';
const client = createClient(url, anonKey);

async function verifyParentChildren(parentEmail, expectedChildren) {
  const { data: authData, error: authErr } = await client.auth.signInWithPassword({
    email: parentEmail,
    password: 'Parent@TopGrade2026'
  });

  if (authErr || !authData?.user) {
    console.log(`[FAIL] Parent Login for ${parentEmail}:`, authErr?.message);
    return false;
  }

  const user = authData.user;
  const meta = user.user_metadata || {};

  // Fetch all students from DB matching this parent
  const { data: allStudents, error: stuErr } = await client.from('students').select('*');
  if (stuErr || !allStudents) {
    console.log(`[FAIL] Fetch students error:`, stuErr?.message);
    return false;
  }

  const childCodes = (meta.child_code || meta.student_id_code || "").split(/[,&]/).map(c => c.trim().toLowerCase()).filter(Boolean);
  const childNames = (meta.child_name || "").split(/[,&]/).map(n => n.trim().toLowerCase()).filter(Boolean);
  const cleanMetaPhone = (meta.phone || "").replace(/\D/g, "");
  const parentName = (meta.full_name || meta.father_name || "").toLowerCase();

  const matched = allStudents.filter(s => {
    const stuCode = (s.student_id_code || "").toLowerCase();
    const stuName = (s.name || "").toLowerCase();
    const stuFather = (s.father_name || "").toLowerCase();
    const stuPhone = (s.father_phone || s.phone || "").replace(/\D/g, "");
    const stuEmail = (s.email || "").toLowerCase();

    if (childCodes.length > 0 && childCodes.some(c => c === stuCode || stuCode.includes(c) || c.includes(stuCode))) return true;
    if (childNames.length > 0 && childNames.some(n => n === stuName || stuName.includes(n) || n.includes(stuName))) return true;
    if (parentName && stuFather && (stuFather === parentName || parentName.includes(stuFather) || stuFather.includes(parentName))) return true;
    if (cleanMetaPhone && stuPhone && cleanMetaPhone === stuPhone) return true;
    if (parentEmail && (stuEmail === parentEmail.toLowerCase())) return true;
    return false;
  });

  const matchedNames = matched.map(m => m.name);
  const allFound = expectedChildren.every(exp => matchedNames.some(m => m.toLowerCase().includes(exp.toLowerCase())));

  if (allFound) {
    console.log(`[PASS] Parent: "${meta.full_name}" (${parentEmail})`);
    console.log(`       Visible Children (${matched.length}):`);
    matched.forEach(m => {
      console.log(`         • [${m.student_id_code}] ${m.name} | ${m.nationality || 'Grade'} | ${m.address || 'School'} | Course: ${m.program || 'N/A'}`);
    });
    return true;
  } else {
    console.log(`[FAIL] Parent: "${meta.full_name}" (${parentEmail})`);
    console.log(`       Expected: ${expectedChildren.join(', ')}`);
    console.log(`       Found: ${matchedNames.join(', ')}`);
    return false;
  }
}

async function verifyStudentLogin(code, email, expectedName) {
  // Test code lookup
  const { data: stu } = await client.from('students').select('email, student_id_code, name').ilike('student_id_code', code).maybeSingle();
  if (!stu) {
    console.log(`[FAIL] Student code ${code} not found in database.`);
    return false;
  }

  const { data: authData, error: authErr } = await client.auth.signInWithPassword({
    email: stu.email,
    password: 'Student@TopGrade2026'
  });

  if (authErr || !authData?.user) {
    console.log(`[FAIL] Student Login for ${code} (${stu.email}):`, authErr?.message);
    return false;
  }

  console.log(`[PASS] Student Code "${code}" -> Login Email: ${stu.email} | Name: ${stu.name} | Auth Role: ${authData.user.user_metadata?.role}`);
  return true;
}

async function run() {
  console.log('=== VERIFYING MULTI-CHILD SIBLING FAMILIES UNDER PARENT PORTAL ===\n');

  console.log('--- 1. Testing Parent Dashboard Multi-Child Queries ---');
  await verifyParentChildren('annieb@cgsfs.com', ['Sophie Smith', 'Dahlia Smith']);
  console.log('----------------------------------------------------');
  await verifyParentChildren('parent.lakeshia.morgan.5059@parents.topgrade.edu', ['Kaliyah Morgan', 'Kalena Morgan']);
  console.log('----------------------------------------------------');
  await verifyParentChildren('soosanmathai@yahoo.com', ['Nehemiah Pappan', 'Bezaleel Pappan']);
  console.log('----------------------------------------------------');
  await verifyParentChildren('flossied@gmail.com', ['Isabelle Buaku', 'Julia Buaku']);
  console.log('----------------------------------------------------');
  await verifyParentChildren('anvita512@gmail.com', ['Noshi Gupta', 'Kiaan Gupta']);
  console.log('----------------------------------------------------');
  await verifyParentChildren('dhara.6n@gmail.com', ['Dhyana Desai', 'Aarshiv Desai']);
  console.log('----------------------------------------------------');
  await verifyParentChildren('marisol.maldonado96@icloud.com', ['Eric Penaloza', 'Robert Mora']);
  console.log('----------------------------------------------------');
  await verifyParentChildren('lani.garrido@gmail.com', ['Kiron Mercado', 'Cara Mercado']);
  console.log('----------------------------------------------------');
  await verifyParentChildren('n_pilotte@yahoo.com', ['Lydia Chaiban', 'Elias Chaiban']);

  console.log('\n--- 2. Testing Individual Student Logins for Siblings ---');
  await verifyStudentLogin('TG-STU-2026-5062', 'sophie.5062@student.topgrade.edu', 'Sophie Smith');
  await verifyStudentLogin('TG-STU-2026-5062-B', 'dahlia.5062b@student.topgrade.edu', 'Dahlia Smith');
  await verifyStudentLogin('TG-STU-2026-5059', 'kaliyah.5059@student.topgrade.edu', 'Kaliyah Morgan');
  await verifyStudentLogin('TG-STU-2026-5059-B', 'kalena.5059b@student.topgrade.edu', 'Kalena Morgan');
  await verifyStudentLogin('TG-STU-2026-5058', 'nehemiah.5058@student.topgrade.edu', 'Nehemiah Pappan');
  await verifyStudentLogin('TG-STU-2026-5058-B', 'bezaleel.5058b@student.topgrade.edu', 'Bezaleel Pappan');
}

run().catch(console.error);
