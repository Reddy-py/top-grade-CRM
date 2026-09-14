const fs = require('fs');

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
  const clean = raw.trim();
  if (/^grade\s*k/i.test(clean)) return 'Kindergarten';
  if (/^grades?\s*(\d+)/i.test(clean)) {
    const match = clean.match(/^grades?\s*(\d+)/i);
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
  if (lower.includes('grade 1')) return 6;
  if (lower.includes('grade 2')) return 7;
  if (lower.includes('grade 3')) return 8;
  if (lower.includes('grade 4')) return 9;
  if (lower.includes('grade 5')) return 10;
  if (lower.includes('grade 6')) return 11;
  if (lower.includes('grade 7')) return 12;
  if (lower.includes('grade 8')) return 13;
  if (lower.includes('grade 9')) return 14;
  if (lower.includes('grade 10')) return 15;
  if (lower.includes('grade 11')) return 16;
  if (lower.includes('grade 12')) return 17;
  return 14;
}

console.log(`Total CSV lines: ${lines.length}`);
const parsedRows = [];

for (let i = 0; i < lines.length; i++) {
  const parts = parseCsvLine(lines[i]);
  const [rawParent, rawPhone, rawEmail, rawStudent, rawGrade, rawSchool, rawCourse] = parts;
  
  const studentCode = `TG-STU-2026-${5001 + i}`;
  const parentName = (rawParent || '').trim();
  const parentPhone = cleanPhone(rawPhone);
  const parentEmail = (rawEmail && rawEmail.includes('@')) ? rawEmail.trim() : '';
  const studentName = (rawStudent || '').trim();
  const grade = normalizeGrade(rawGrade);
  const school = (rawSchool || 'Top Grade Academy').trim().replace(/^["']|["']$/g, '');
  const course = (rawCourse || '').trim().replace(/^["']|["']$/g, '');

  parsedRows.push({
    code: studentCode,
    // REVERSED (CURRENT WRONG):
    wrongStudent: parentName,
    wrongFather: studentName,
    // CORRECT RE-ORDERED:
    correctStudent: studentName || parentName,
    correctFather: studentName ? parentName : '',
    correctParentPhone: parentPhone,
    correctParentEmail: parentEmail,
    grade,
    school: school || 'Top Grade Academy',
    course,
    age: estimateAgeFromGrade(grade)
  });
}

console.log('Sample first 5 re-ordered:');
console.log(parsedRows.slice(0, 5));
console.log('\nSample last 5 re-ordered:');
console.log(parsedRows.slice(-5));
