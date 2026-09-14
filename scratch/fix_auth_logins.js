const fs = require('fs');
const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const url = 'https://zznzmzwiewsnmykcbcni.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ4ODk0MSwiZXhwIjoyMDk4MDY0OTQxfQ.P8yhVbJhNoqq_ygIZh9KHlxEEJsBbj2wNAUUBJdvlsY';
const sb = createClient(url, key);

const csvPath = 'C:/Users/91778/.gemini/antigravity-ide/brain/d3a15eec-f3f7-4afa-a384-11644fa51258/.user_uploaded/media_1789021427288.csv';
const lines = fs.readFileSync(csvPath, 'utf8').split(/\r?\n/).filter(l => l.trim().length > 0);

function parseCsvLine(text) {
  const result = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      inQuotes = !inQuotes;
    } else if (c === ',' && !inQuotes) {
      result.push(cur.trim());
      cur = '';
    } else {
      cur += c;
    }
  }
  result.push(cur.trim());
  return result;
}

function cleanPhone(raw) {
  if (!raw) return '';
  const digits = raw.replace(/\D/g, '');
  if (!digits) return '';
  if (digits.length === 10) return `+1 ${digits.slice(0, 3)} ${digits.slice(3, 6)} ${digits.slice(6)}`;
  if (digits.length === 11 && digits.startsWith('1')) return `+1 ${digits.slice(1, 4)} ${digits.slice(4, 7)} ${digits.slice(7)}`;
  return `+1 ${raw}`;
}

function toSlug(name) {
  if (!name) return 'user';
  return name.toLowerCase()
    .replace(/[^a-z0-9]+/g, '.')
    .replace(/^\.+|\.+$/g, '')
    .slice(0, 30) || 'user';
}

async function getAllAuthUsers() {
  let allUsers = [];
  let page = 1;
  while (true) {
    const { data, error } = await sb.auth.admin.listUsers({ page, perPage: 100 });
    if (error) {
      console.error('Error fetching auth users:', error);
      break;
    }
    if (!data || !data.users || data.users.length === 0) break;
    allUsers.push(...data.users);
    if (data.users.length < 100) break;
    page++;
  }
  return allUsers;
}

async function fixAuthLogins() {
  console.log('=== STARTING RE-PROVISIONING OF STUDENT & PARENT AUTH ACCOUNTS ===');
  const authUsers = await getAllAuthUsers();
  console.log(`Fetched ${authUsers.length} total users from Supabase Auth.`);

  const { data: dbStudents, error: stuErr } = await sb.from('students').select('*');
  if (stuErr || !dbStudents) {
    console.error('Error fetching students table:', stuErr);
    return;
  }
  console.log(`Fetched ${dbStudents.length} rows from students table.`);

  // Load local JSON DB
  const localDbPath = path.resolve(__dirname, '../topgrade-backend/data/students_db.json');
  let localDb = [];
  if (fs.existsSync(localDbPath)) {
    localDb = JSON.parse(fs.readFileSync(localDbPath, 'utf8'));
  }

  const credentialsList = [];

  for (let idx = 0; idx < lines.length; idx++) {
    const parts = parseCsvLine(lines[idx]);
    const [rawParent, rawPhone, rawEmail, rawStudent, rawGrade, rawSchool, rawCourse] = parts;

    const rowNum = 5001 + idx;
    const studentCode = `TG-STU-2026-${rowNum}`;
    const rawStudentClean = (rawStudent || '').trim().replace(/^["']|["']$/g, '');
    const rawParentClean = (rawParent || '').trim().replace(/^["']|["']$/g, '');

    // Re-order definition
    const realStudentName = rawStudentClean.length > 0 ? rawStudentClean : rawParentClean;
    const realParentName = rawStudentClean.length > 0 ? rawParentClean : '';
    const phone = cleanPhone(rawPhone);
    const parentPersonalEmail = (rawEmail && rawEmail.includes('@')) ? rawEmail.trim().toLowerCase() : null;

    // Student Login Details
    const studentSlug = toSlug(realStudentName);
    const studentEmail = `${studentSlug}.${rowNum}@student.topgrade.edu`.toLowerCase();
    const studentPassword = 'Student@TopGrade2026';

    // Parent Login Details
    const parentSlug = realParentName ? toSlug(realParentName) : studentSlug;
    const parentInstEmail = `parent.${parentSlug}.${rowNum}@parents.topgrade.edu`.toLowerCase();
    const parentPassword = 'Parent@TopGrade2026';

    console.log(`\n[${idx + 1}/68] Processing ${studentCode}:`);
    console.log(`  Student: "${realStudentName}" -> ${studentEmail}`);
    console.log(`  Parent:  "${realParentName}" -> ${parentInstEmail} ${parentPersonalEmail ? `(Personal: ${parentPersonalEmail})` : ''}`);

    // --- 1. STUDENT AUTH ACCOUNT ---
    // Match existing student account by student_id_code in metadata, or email pattern
    let studentAuth = authUsers.find(u => 
      u.user_metadata?.student_id_code === studentCode || 
      u.user_metadata?.student_code === studentCode ||
      (u.email && u.email.endsWith('@student.topgrade.edu') && (
        u.email.includes(`${rowNum}`) || 
        (u.user_metadata?.full_name && toSlug(u.user_metadata.full_name) === toSlug(rawParentClean))
      ))
    );

    let studentUserId = null;
    if (studentAuth) {
      studentUserId = studentAuth.id;
      const { error: updErr } = await sb.auth.admin.updateUserById(studentUserId, {
        email: studentEmail,
        password: studentPassword,
        email_confirm: true,
        user_metadata: {
          role: 'STUDENT',
          full_name: realStudentName,
          student_id_code: studentCode,
          student_code: studentCode,
          email_verified: true
        }
      });
      if (updErr) {
        console.error(`  Error updating student auth ${studentCode}:`, updErr.message);
      } else {
        console.log(`  Updated student auth (ID: ${studentUserId}) to ${studentEmail}`);
      }
    } else {
      // Check if studentEmail already exists
      const existingByEmail = authUsers.find(u => u.email === studentEmail);
      if (existingByEmail) {
        studentUserId = existingByEmail.id;
        await sb.auth.admin.updateUserById(studentUserId, {
          password: studentPassword,
          email_confirm: true,
          user_metadata: {
            role: 'STUDENT',
            full_name: realStudentName,
            student_id_code: studentCode,
            student_code: studentCode,
            email_verified: true
          }
        });
        console.log(`  Updated existing student by email ${studentEmail}`);
      } else {
        const { data: newStuAuth, error: createErr } = await sb.auth.admin.createUser({
          email: studentEmail,
          password: studentPassword,
          email_confirm: true,
          user_metadata: {
            role: 'STUDENT',
            full_name: realStudentName,
            student_id_code: studentCode,
            student_code: studentCode,
            email_verified: true
          }
        });
        if (createErr) {
          console.error(`  Error creating student auth ${studentEmail}:`, createErr.message);
        } else {
          studentUserId = newStuAuth.user.id;
          console.log(`  Created new student auth (ID: ${studentUserId})`);
        }
      }
    }

    // Upsert Student Profile
    if (studentUserId) {
      await sb.from('profiles').upsert({
        id: studentUserId,
        email: studentEmail,
        full_name: realStudentName,
        phone: phone || null,
        role: 'STUDENT',
        status: 'Active',
        updated_at: new Date().toISOString()
      });
    }

    // Update students table record
    const dbMatch = dbStudents.find(s => s.student_id_code === studentCode);
    if (dbMatch) {
      await sb.from('students').update({
        user_id: studentUserId || dbMatch.user_id,
        email: studentEmail, // Primary login email for student code resolution
        name: realStudentName,
        father_name: realParentName || null,
        phone: phone || dbMatch.phone || null,
        father_phone: phone || null
      }).eq('id', dbMatch.id);
    }

    // Update local JSON DB
    const localIdx = localDb.findIndex(s => s.studentCode === studentCode);
    if (localIdx >= 0) {
      localDb[localIdx].email = studentEmail;
      localDb[localIdx].fullName = realStudentName;
      localDb[localIdx].fatherName = realParentName;
      localDb[localIdx].studentEmails = [studentEmail];
      if (parentPersonalEmail) {
        localDb[localIdx].parentEmails = [parentPersonalEmail, parentInstEmail];
      } else {
        localDb[localIdx].parentEmails = [parentInstEmail];
      }
    }

    // --- 2. PARENT INSTITUTIONAL AUTH ACCOUNT ---
    let parentAuth = authUsers.find(u =>
      (u.user_metadata?.child_code === studentCode && u.email?.endsWith('@parents.topgrade.edu')) ||
      (u.email && u.email === `parent.${toSlug(rawStudentClean)}@parents.topgrade.edu`) ||
      (u.email && u.email.endsWith('@parents.topgrade.edu') && u.email.includes(`${rowNum}`))
    );

    let parentUserId = null;
    if (parentAuth) {
      parentUserId = parentAuth.id;
      const { error: pUpdErr } = await sb.auth.admin.updateUserById(parentUserId, {
        email: parentInstEmail,
        password: parentPassword,
        email_confirm: true,
        user_metadata: {
          role: 'PARENT',
          full_name: realParentName || `${realStudentName} Parent`,
          father_name: realParentName || null,
          child_name: realStudentName,
          child_code: studentCode,
          student_id_code: studentCode,
          phone: phone,
          email_verified: true
        }
      });
      if (pUpdErr) {
        console.error(`  Error updating parent inst auth:`, pUpdErr.message);
      } else {
        console.log(`  Updated parent inst auth (${parentInstEmail})`);
      }
    } else {
      const { data: newPAuth, error: pCreateErr } = await sb.auth.admin.createUser({
        email: parentInstEmail,
        password: parentPassword,
        email_confirm: true,
        user_metadata: {
          role: 'PARENT',
          full_name: realParentName || `${realStudentName} Parent`,
          father_name: realParentName || null,
          child_name: realStudentName,
          child_code: studentCode,
          student_id_code: studentCode,
          phone: phone,
          email_verified: true
        }
      });
      if (pCreateErr) {
        console.error(`  Error creating parent inst auth:`, pCreateErr.message);
      } else {
        parentUserId = newPAuth.user.id;
        console.log(`  Created parent inst auth (${parentInstEmail})`);
      }
    }

    if (parentUserId) {
      await sb.from('profiles').upsert({
        id: parentUserId,
        email: parentInstEmail,
        full_name: realParentName || `${realStudentName} Parent`,
        phone: phone || null,
        role: 'PARENT',
        status: 'Active',
        updated_at: new Date().toISOString()
      });
    }

    // --- 3. PARENT PERSONAL AUTH ACCOUNT (if personal email exists) ---
    if (parentPersonalEmail) {
      let personalAuth = authUsers.find(u => u.email?.toLowerCase() === parentPersonalEmail);
      if (personalAuth) {
        const { error: persErr } = await sb.auth.admin.updateUserById(personalAuth.id, {
          password: parentPassword,
          email_confirm: true,
          user_metadata: {
            role: 'PARENT',
            full_name: realParentName || `${realStudentName} Parent`,
            father_name: realParentName || null,
            child_name: realStudentName,
            child_code: studentCode,
            student_id_code: studentCode,
            phone: phone,
            email_verified: true
          }
        });
        if (persErr) {
          console.error(`  Error updating parent personal auth:`, persErr.message);
        } else {
          console.log(`  Updated parent personal auth (${parentPersonalEmail})`);
        }

        await sb.from('profiles').upsert({
          id: personalAuth.id,
          email: parentPersonalEmail,
          full_name: realParentName || `${realStudentName} Parent`,
          phone: phone || null,
          role: 'PARENT',
          status: 'Active',
          updated_at: new Date().toISOString()
        });
      } else {
        const { data: newPers, error: persCreateErr } = await sb.auth.admin.createUser({
          email: parentPersonalEmail,
          password: parentPassword,
          email_confirm: true,
          user_metadata: {
            role: 'PARENT',
            full_name: realParentName || `${realStudentName} Parent`,
            father_name: realParentName || null,
            child_name: realStudentName,
            child_code: studentCode,
            student_id_code: studentCode,
            phone: phone,
            email_verified: true
          }
        });
        if (persCreateErr) {
          console.error(`  Error creating parent personal auth:`, persCreateErr.message);
        } else {
          console.log(`  Created parent personal auth (${parentPersonalEmail})`);
          await sb.from('profiles').upsert({
            id: newPers.user.id,
            email: parentPersonalEmail,
            full_name: realParentName || `${realStudentName} Parent`,
            phone: phone || null,
            role: 'PARENT',
            status: 'Active',
            updated_at: new Date().toISOString()
          });
        }
      }
    }

    credentialsList.push({
      studentCode,
      studentName: realStudentName,
      studentEmail,
      studentPassword,
      parentName: realParentName,
      parentInstEmail,
      parentPersonalEmail: parentPersonalEmail || 'N/A',
      parentPassword,
      phone
    });
  }

  // Save updated local JSON DB
  fs.writeFileSync(localDbPath, JSON.stringify(localDb, null, 2), 'utf8');
  console.log(`Updated local JSON database: ${localDbPath}`);

  // Write updated credentials CSV
  const csvHeaders = 'Student ID,Student Name,Student Login Email,Student Password,Parent Name,Parent Institutional Email,Parent Personal Email,Parent Password,Contact Phone\n';
  const csvContent = csvHeaders + credentialsList.map(c => 
    `"${c.studentCode}","${c.studentName}","${c.studentEmail}","${c.studentPassword}","${c.parentName}","${c.parentInstEmail}","${c.parentPersonalEmail}","${c.parentPassword}","${c.phone}"`
  ).join('\n');

  fs.writeFileSync('./student_and_parent_credentials.csv', csvContent, 'utf8');
  fs.writeFileSync('./topgrade/student_and_parent_credentials.csv', csvContent, 'utf8');
  console.log('Successfully wrote updated student_and_parent_credentials.csv');

  console.log('=== AUTH PROVISIONING COMPLETE ===');
}

fixAuthLogins().catch(err => {
  console.error('Fatal error during auth fix:', err);
});
