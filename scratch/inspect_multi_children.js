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

lines.forEach((l, idx) => {
  const parts = parseCsvLine(l);
  const [rawParent, rawPhone, rawEmail, rawStudent, rawGrade, rawSchool, rawCourse] = parts;
  const rowNum = 5001 + idx;
  const s = rawStudent || '';
  const g = rawGrade || '';
  const isMulti = s.includes('&') || s.includes(',') || s.toLowerCase().includes(' and ') || g.includes('&') || g.includes(',') || g.toLowerCase().includes(' and ');
  if (isMulti) {
    console.log(`[ROW ${idx+1} | TG-STU-2026-${rowNum}]`);
    console.log(`  Parent: "${rawParent}" | Phone: "${rawPhone}" | Email: "${rawEmail}"`);
    console.log(`  Student raw: "${rawStudent}"`);
    console.log(`  Grade raw: "${rawGrade}"`);
    console.log(`  School raw: "${rawSchool}"`);
    console.log(`  Course raw: "${rawCourse}"`);
    console.log('----------------------------------------------------');
  }
});
