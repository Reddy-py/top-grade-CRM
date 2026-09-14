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

function normalizeGrade(raw) {
  if (!raw) return 'Grade 10';
  const clean = raw.trim().replace(/^["']|["']$/g, '');
  if (/^grade\s*k/i.test(clean) || /^kindergarten/i.test(clean)) return 'Kindergarten';
  if (/^pre-?k/i.test(clean)) return 'Pre-K';
  if (/^grade\s*(\d+)/i.test(clean)) {
    const match = clean.match(/^grade\s*(\d+)/i);
    return `Grade ${match[1]}`;
  }
  if (/^grade/i.test(clean)) return clean;
  if (/^\d+$/.test(clean)) return `Grade ${clean}`;
  return clean;
}

function estimateAgeFromGrade(gradeStr) {
  if (!gradeStr) return 15;
  const lower = gradeStr.toLowerCase();
  if (lower.includes('kindergarten') || lower.includes('grade k') || lower.includes('pre-k')) return 5;
  if (lower.includes('grade 12')) return 17;
  if (lower.includes('grade 11')) return 16;
  if (lower.includes('grade 10')) return 15;
  if (lower.includes('grade 9')) return 14;
  if (lower.includes('grade 8')) return 13;
  if (lower.includes('grade 7')) return 12;
  if (lower.includes('grade 6')) return 11;
  if (lower.includes('grade 5')) return 10;
  if (lower.includes('grade 4')) return 9;
  if (lower.includes('grade 3')) return 8;
  if (lower.includes('grade 2')) return 7;
  if (lower.includes('grade 1')) return 6;
  return 14;
}

async function reorder() {
  console.log('=== STARTING RE-ORDERING OF REVERSED CLIENT STUDENTS ===');
  console.log(`Reading CSV with ${lines.length} rows...`);

  // 1. Fetch existing Supabase students
  const { data: dbStudents, error: fetchErr } = await sb.from('students').select('*');
  if (fetchErr || !dbStudents) {
    console.error('Failed to fetch students from Supabase:', fetchErr);
    return;
  }
  console.log(`Found ${dbStudents.length} total students in Supabase.`);

  // 2. Load local students_db.json
  const localDbPath = './topgrade-backend/data/students_db.json';
  let localDb = [];
  if (fs.existsSync(localDbPath)) {
    localDb = JSON.parse(fs.readFileSync(localDbPath, 'utf8'));
  }

  let updatedCount = 0;

  for (let idx = 0; idx < lines.length; idx++) {
    const parts = parseCsvLine(lines[idx]);
    const [rawParent, rawPhone, rawEmail, rawStudent, rawGrade, rawSchool, rawCourse] = parts;

    const studentCode = `TG-STU-2026-${5001 + idx}`;
    const rawStudentClean = (rawStudent || '').trim().replace(/^["']|["']$/g, '');
    const rawParentClean = (rawParent || '').trim().replace(/^["']|["']$/g, '');

    // Re-order logic:
    // If rawStudent is provided, that IS the student! The parent is rawParent.
    // If rawStudent is empty, it's an applicant without child info, so student is rawParent.
    const realStudentName = rawStudentClean.length > 0 ? rawStudentClean : rawParentClean;
    const realParentName = rawStudentClean.length > 0 ? rawParentClean : '';
    const cleanPh = cleanPhone(rawPhone);
    const cleanEm = (rawEmail && rawEmail.includes('@')) ? rawEmail.trim() : null;
    const cleanGr = normalizeGrade(rawGrade);
    const cleanSc = (rawSchool || 'Top Grade Academy').trim().replace(/^["']|["']$/g, '');
    const cleanCo = (rawCourse || '').trim().replace(/^["']|["']$/g, '');
    const estimatedAge = estimateAgeFromGrade(cleanGr);

    const dbMatch = dbStudents.find(s => s.student_id_code === studentCode);
    if (!dbMatch) {
      console.warn(`Record ${studentCode} (${realStudentName}) not found in Supabase.`);
    } else {
      // Update Supabase with CORRECT mapping
      const sbPayload = {
        name: realStudentName,
        father_name: realParentName || null,
        nationality: cleanGr ? `Grade: ${cleanGr}` : null,
        address: cleanSc ? `School: ${cleanSc}` : null,
        program: cleanCo || null,
        phone: cleanPh || dbMatch.phone || null,
        father_phone: cleanPh || null,
        email: cleanEm || dbMatch.email
      };

      const { error: updErr } = await sb.from('students').update(sbPayload).eq('id', dbMatch.id);
      if (updErr) {
        console.error(`Error updating Supabase ${studentCode}:`, updErr);
      }
    }

    // Update in localDb
    const localIdx = localDb.findIndex(s => s.studentCode === studentCode);
    const nameParts = realStudentName.split(' ');
    const firstName = nameParts[0] || realStudentName;
    const lastName = nameParts.slice(1).join(' ') || (realParentName ? realParentName.split(' ').slice(1).join(' ') : '');

    const localItem = {
      id: dbMatch ? dbMatch.id : (localIdx >= 0 ? localDb[localIdx].id : `gen-${studentCode}`),
      studentCode,
      fullName: realStudentName,
      firstName,
      lastName,
      email: cleanEm || (dbMatch ? dbMatch.email : `${firstName.toLowerCase()}@topgrade.edu`),
      dob: `20${26 - estimatedAge}-01-01`,
      age: estimatedAge,
      school: cleanSc || 'Top Grade Academy',
      grade: cleanGr || 'Grade 10',
      status: 'ACTIVE',
      primaryMobile: cleanPh || '',
      studentPhones: cleanPh ? [cleanPh] : [],
      parentPhones: cleanPh ? [cleanPh] : [],
      studentEmails: cleanEm ? [cleanEm] : [],
      parentEmails: cleanEm ? [cleanEm] : [],
      fatherName: realParentName,
      motherName: '',
      guardianName: realParentName,
      program: cleanCo || 'Standard Curriculum',
      teacher: 'Unassigned',
      residentialAddress: '',
      studentAddress: '',
      alternateAddress: '',
      examDate: '',
      purchasedHours: 20,
      feePlan: 'Standard Plan',
      allocatedCourses: cleanCo ? [{ courseName: cleanCo, duration: '3 Months' }] : [{ courseName: 'Standard Curriculum', duration: '3 Months' }]
    };

    if (localIdx >= 0) {
      localDb[localIdx] = { ...localDb[localIdx], ...localItem };
    } else {
      localDb.push(localItem);
    }

    updatedCount++;
  }

  // Save updated localDb
  fs.writeFileSync(localDbPath, JSON.stringify(localDb, null, 2), 'utf8');
  console.log(`✅ Successfully re-ordered ${updatedCount} students in both Supabase and students_db.json!`);

  // Verify sample re-ordered rows
  console.log('\nVerification of re-ordered students:');
  const sampleCodes = ['TG-STU-2026-5001', 'TG-STU-2026-5002', 'TG-STU-2026-5004', 'TG-STU-2026-5067', 'TG-STU-2026-5068'];
  sampleCodes.forEach(code => {
    const s = localDb.find(item => item.studentCode === code);
    if (s) {
      console.log(`[${s.studentCode}] Student: "${s.fullName}" | Parent: "${s.fatherName}" | Grade: "${s.grade}" | School: "${s.school}" | Course: "${s.program}" | Phone: "${s.primaryMobile}"`);
    }
  });
}

reorder().catch(console.error);
