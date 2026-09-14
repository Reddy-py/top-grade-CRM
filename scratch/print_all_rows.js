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
  console.log(`${idx + 1}: Parent="${parts[0]}" | Phone="${parts[1]}" | Email="${parts[2]}" | Student="${parts[3]}" | Grade="${parts[4]}" | School="${parts[5]}" | Course="${parts[6]}"`);
});
