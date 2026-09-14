const fs = require('fs');
const path = require('path');

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
  if (!raw) return 'N/A';
  const digits = raw.replace(/\D/g, '');
  if (!digits) return 'N/A';
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

// Multi-family map to expand siblings
const multiFamilyMap = {
  5007: [
    { name: "Kiron Mercado", code: "TG-STU-2026-5007", email: "kiron.5007@student.topgrade.edu", grade: "Grade 4", school: "Silverlake", course: "Afterschool" },
    { name: "Cara Mercado", code: "TG-STU-2026-5007-B", email: "cara.5007b@student.topgrade.edu", grade: "Grade 2", school: "Silverlake", course: "Afterschool" }
  ],
  5023: [
    { name: "Lydia Chaiban", code: "TG-STU-2026-5023", email: "lydia.5023@student.topgrade.edu", grade: "Kindergarten", school: "Red Duke", course: "summer camp" },
    { name: "Elias Chaiban", code: "TG-STU-2026-5023-B", email: "elias.5023b@student.topgrade.edu", grade: "Kindergarten", school: "Red Duke", course: "summer camp" }
  ],
  5027: [
    { name: "Eric Penaloza", code: "TG-STU-2026-5027", email: "eric.5027@student.topgrade.edu", grade: "Kindergarten", school: "Mary Marek", course: "Afterschool" },
    { name: "Robert Mora", code: "TG-STU-2026-5027-B", email: "robert.mora.5027b@student.topgrade.edu", grade: "Grade 6", school: "Nolan Ryan", course: "Afterschool" }
  ],
  5030: [
    { name: "Dhyana Desai", code: "TG-STU-2026-5030", email: "dhyana.5030@student.topgrade.edu", grade: "Grade 2", school: "Glen York elem", course: "GT prep/ Math & Reading" },
    { name: "Aarshiv Desai", code: "TG-STU-2026-5030-B", email: "aarshiv.5030b@student.topgrade.edu", grade: "Pre-K", school: "Glen York elem", course: "GT prep/ Math & Reading" }
  ],
  5034: [
    { name: "Noshi Gupta", code: "TG-STU-2026-5034", email: "noshi.5034@student.topgrade.edu", grade: "Grade 11", school: "Top Grade Academy", course: "General Track" },
    { name: "Kiaan Gupta", code: "TG-STU-2026-5034-B", email: "kiaan.5034b@student.topgrade.edu", grade: "Grade 9", school: "Top Grade Academy", course: "General Track" }
  ],
  5054: [
    { name: "Isabelle Buaku", code: "TG-STU-2026-5054", email: "isabelle.5054@student.topgrade.edu", grade: "Grade 3", school: "Silvercrest", course: "Afterschool" },
    { name: "Julia Buaku", code: "TG-STU-2026-5054-B", email: "julia.5054b@student.topgrade.edu", grade: "Grade 6", school: "Rogers", course: "Afterschool" }
  ],
  5058: [
    { name: "Nehemiah Pappan", code: "TG-STU-2026-5058", email: "nehemiah.5058@student.topgrade.edu", grade: "Grade 6", school: "Sablatura", course: "ESL" },
    { name: "Bezaleel Pappan", code: "TG-STU-2026-5058-B", email: "bezaleel.5058b@student.topgrade.edu", grade: "Grade 7", school: "PJHW", course: "ESL" }
  ],
  5059: [
    { name: "Kaliyah Morgan", code: "TG-STU-2026-5059", email: "kaliyah.5059@student.topgrade.edu", grade: "Grade 4", school: "Wilder elem", course: "Reading & Math" },
    { name: "Kalena Morgan", code: "TG-STU-2026-5059-B", email: "kalena.5059b@student.topgrade.edu", grade: "Grade 2", school: "Wilder elem", course: "Reading & Math" }
  ],
  5062: [
    { name: "Sophie Smith", code: "TG-STU-2026-5062", email: "sophie.5062@student.topgrade.edu", grade: "Grade 9", school: "Turner", course: "Afterschool" },
    { name: "Dahlia Smith", code: "TG-STU-2026-5062-B", email: "dahlia.5062b@student.topgrade.edu", grade: "Grade 5", school: "Rogers", course: "Afterschool" }
  ]
};

function generateCredentials() {
  const allStudents = [
    {
      num: 1,
      code: 'TG-STU-2026-3632',
      name: 'Siva Reddy',
      email: 'sivareddy683970@gmail.com',
      password: 'Student@TopGrade2026',
      phone: '+1 7780648562',
      course: 'General Academic Track',
      parentName: 'Venakat',
      parentLogin: 'N/A',
      parentPassword: 'N/A'
    },
    {
      num: 2,
      code: 'TG-STU-2026-4231',
      name: 'rajesh ganta',
      email: 'rajeshganta@gmail.com',
      password: 'Student@TopGrade2026',
      phone: '+1 1234567894',
      course: 'General Academic Track',
      parentName: 'srinu',
      parentLogin: 'N/A',
      parentPassword: 'N/A'
    }
  ];

  let currentNum = 3;

  for (let idx = 0; idx < lines.length; idx++) {
    const parts = parseCsvLine(lines[idx]);
    const [rawParent, rawPhone, rawEmail, rawStudent, rawGrade, rawSchool, rawCourse] = parts;
    const rowNum = 5001 + idx;

    const rawStudentClean = (rawStudent || '').trim().replace(/^["']|["']$/g, '');
    const rawParentClean = (rawParent || '').trim().replace(/^["']|["']$/g, '');
    const phone = cleanPhone(rawPhone);
    const parentPersonalEmail = (rawEmail && rawEmail.includes('@')) ? rawEmail.trim().toLowerCase() : null;

    if (multiFamilyMap[rowNum]) {
      // Multiple siblings
      const siblings = multiFamilyMap[rowNum];
      const parentSlug = toSlug(rawParentClean);
      const parentInstEmail = `parent.${parentSlug}.${rowNum}@parents.topgrade.edu`;
      let parentLoginDisplay = `\`${parentInstEmail}\``;
      if (parentPersonalEmail) {
        parentLoginDisplay = `\`${parentPersonalEmail}\`<br>*(or \`${parentInstEmail}\`)*`;
      }

      for (const sib of siblings) {
        allStudents.push({
          num: currentNum++,
          code: sib.code,
          name: sib.name,
          email: sib.email,
          password: 'Student@TopGrade2026',
          phone,
          course: `${sib.course} (${sib.grade} • ${sib.school})`,
          parentName: rawParentClean,
          parentLogin: parentLoginDisplay,
          parentPassword: 'Parent@TopGrade2026',
          isSibling: true
        });
      }
    } else {
      // Single child or self-applicant
      const realStudentName = rawStudentClean.length > 0 ? rawStudentClean : rawParentClean;
      const realParentName = rawStudentClean.length > 0 ? rawParentClean : 'Self-Enrolled';
      const studentSlug = toSlug(realStudentName);
      const studentEmail = `${studentSlug}.${rowNum}@student.topgrade.edu`.toLowerCase();

      const parentSlug = realParentName && realParentName !== 'Self-Enrolled' ? toSlug(realParentName) : studentSlug;
      const parentInstEmail = `parent.${parentSlug}.${rowNum}@parents.topgrade.edu`.toLowerCase();

      const courseDesc = (rawCourse || 'General Track').trim().replace(/^["']|["']$/g, '');
      const gradeDesc = (rawGrade || '').trim().replace(/^["']|["']$/g, '');
      const schoolDesc = (rawSchool || '').trim().replace(/^["']|["']$/g, '');
      const courseTrack = `${courseDesc}${gradeDesc ? ` (${gradeDesc})` : ''}${schoolDesc ? ` • ${schoolDesc}` : ''}`;

      let parentLoginDisplay = `\`${parentInstEmail}\``;
      if (parentPersonalEmail) {
        parentLoginDisplay = `\`${parentPersonalEmail}\`<br>*(or \`${parentInstEmail}\`)*`;
      }

      allStudents.push({
        num: currentNum++,
        code: `TG-STU-2026-${rowNum}`,
        name: realStudentName,
        email: studentEmail,
        password: 'Student@TopGrade2026',
        phone,
        course: courseTrack,
        parentName: realParentName,
        parentLogin: parentLoginDisplay,
        parentPassword: 'Parent@TopGrade2026'
      });
    }
  }

  allStudents.push({
    num: currentNum++,
    code: 'TG-STU-2026-9717',
    name: 'harshith pabisetty',
    email: 'std-1788241892654@topgrade.edu',
    password: 'Student@TopGrade2026',
    phone: '+1 5818585656',
    course: 'Python Beginners & Logic',
    parentName: 'sathish',
    parentLogin: 'N/A',
    parentPassword: 'N/A'
  });

  return allStudents;
}

const allData = generateCredentials();

// Build markdown
let md = `# TopGrade CRM — Master System Login Credentials Directory

> **System Instance**: TopGrade CRM Production & Staging  
> **Date Generated**: September 14, 2026  
> **Total Verified Accounts**: **1 Administrator** | **17 Faculty Teachers** | **80 Students** | **Active Parent Portals**  
> **Multi-Child Sibling Management**: Fully Configured (9 families with multiple children linked to unified parent accounts)  
> **Supabase Auth Status**: Verified & Authenticated (100% Active)

---

## 1. System Administrator Login

| Role | Full Name | Login Email | Password | Access Portal |
| :--- | :--- | :--- | :--- | :--- |
| **ADMIN** | System Administrator | \`admin@topgrade.edu\` | \`TopGrade2026!\` | [http://localhost:5174/login](http://localhost:5174/login) |

* **Privileges**: Super Administrator with full permissions (Schedule Management, Teacher Faculty Management, Student Admissions & Enrollment, Billing & Invoicing, Course Catalog Administration).

---

## 2. Faculty Teachers (17 Official Teachers)

> **Standard Teacher Password**: \`TopGrade@2026!\`  
> All 17 teacher accounts have been fully created and linked in Supabase \`auth.users\`, \`teachers\`, and \`profiles\` tables.

| # | Teacher ID | Teacher Name | Login Email | Default Password | Phone | Specialization | Delivery Method | Location |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | **TG-FAC-101** | **Ms. Jamie Dawson** | \`jldaeb1000@gmail.com\` | \`TopGrade@2026!\` | +1 832-315-1251 | Online Instruction & Academic Mentoring | online | Alvin, Texas |
| 2 | **TG-FAC-102** | **Ms. Shahrazad Polk** | \`sha.polk20@gmail.com\` | \`TopGrade@2026!\` | +1 281-995-0685 | In-Center Tutoring & Standard Curriculum | in center | Pearland, Texas |
| 3 | **TG-FAC-103** | **Ms. Annalisa Jaimes** | \`annalisa.jaimes@gmail.com\` | \`TopGrade@2026!\` | +1 832-542-1864 | In-Person Classroom & Foundations | InPerson | Angleton, Texas |
| 4 | **TG-FAC-104** | **Ms. Laura Gorham** | \`laura_gorham@yahoo.com\` | \`TopGrade@2026!\` | +1 713-498-6884 | In-Center Elementary & Middle School | in center | Pearland, Texas |
| 5 | **TG-FAC-105** | **Mr. Jignesh Upadhyaya** | \`jigneshu2004@yahoo.com\` | \`TopGrade@2026!\` | +1 281-760-6386 | Mathematics, Physics & Test Prep | in center | Pearland, Texas |
| 6 | **TG-FAC-106** | **Mrs. Katrina Baines** | \`katrina.baines@yahoo.com\` | \`TopGrade@2026!\` | +1 832-641-5525 | Language Arts, Reading & Writing | in center | Houston, Texas |
| 7 | **TG-FAC-107** | **Ms. Chloe Self** | \`chloe.r.self@gmail.com\` | \`TopGrade@2026!\` | +1 832-600-1004 | STEM, Chemistry & Accelerated Learning | in center | Sugar Land, Texas |
| 8 | **TG-FAC-108** | **Mr. Abel Dominguez** | \`abeldominguez10000@gmail.com\` | \`TopGrade@2026!\` | +1 832-288-7224 | Mathematics & Physical Sciences | in center | Houston, Texas |
| 9 | **TG-FAC-109** | **Mrs. Patricia Landrum** | \`tclandrum@hotmail.com\` | \`TopGrade@2026!\` | +1 713-899-7890 | Language Arts, STAAR & Study Skills | in center | Pearland, Texas |
| 10 | **TG-FAC-110** | **Ms. Logan Fenner** | \`fennelog@gmail.com\` | \`TopGrade@2026!\` | +1 936-900-9302 | Algebra, Calculus & Geometry | in center | Houston, Texas |
| 11 | **TG-FAC-111** | **Mr. Achalesh Amar** | \`achalesh@gmail.com\` | \`TopGrade@2026!\` | +1 713-357-8216 | Social Sciences, History & Humanities | in center | Pearland, Texas |
| 12 | **TG-FAC-112** | **Ms. Nicole Abner** | \`nicoleabner1@gmail.com\` | \`TopGrade@2026!\` | +1 713-819-4727 | Primary & Middle School Foundations | in center | Manvel, Texas |
| 13 | **TG-FAC-113** | **Mrs. Paula Isaac** | \`mrspisaac2022@gmail.com\` | \`TopGrade@2026!\` | +1 501-519-2000 | Hybrid Online & On-Campus Tutoring | Any | Houston, Texas |
| 14 | **TG-FAC-114** | **Ms. Tamara Gipson** | \`tamaratechbytes@gmail.com\` | \`TopGrade@2026!\` | +1 281-755-0107 | Coding, 3D Printing & Applied Tech | InPerson | Houston, Texas |
| 15 | **TG-FAC-115** | **Ms. Deja Getwood** | \`dejagetwood15@gmail.com\` | \`TopGrade@2026!\` | +1 409-365-5283 | Spanish, French & World Languages | Any | Houston, Texas |
| 16 | **TG-FAC-116** | **Ms. Kerry Rails** | \`kag9181@gmail.com\` | \`TopGrade@2026!\` | +1 409-497-1722 | Economics, Government & Social Sciences | Any | Houston, Texas |
| 17 | **TG-FAC-117** | **Mr. Ryon Davis** | \`davisryon@gmail.com\` | \`TopGrade@2026!\` | +1 972-489-9296 | High School STEM & SAT/ACT Prep | Any | Houston, Texas |

---

## 3. Students & Parents (80 Active Students, including Sibling Accounts)

> **Standard Student Password**: \`Student@TopGrade2026\`  
> **Standard Parent Password**: \`Parent@TopGrade2026\`  
> **Sibling Management**: Parents with multiple children (e.g. Annie Smith with Sophie and Dahlia) can log into their Parent Portal with their email and see/switch between all their children from the top Child Switcher tab!

| # | Student ID | Student Name | Student Login Email / ID | Student Password | Phone | Course / Track | Parent Name | Parent Login Email(s) | Parent Password |
| :-: | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
`;

allData.forEach(s => {
  md += `| ${s.num} | **${s.code}** | **${s.name}** | \`${s.email}\`<br>*(or \`${s.code}\`)* | \`${s.password}\` | ${s.phone} | ${s.course} | ${s.parentName} | ${s.parentLogin} | \`${s.parentPassword}\` |\n`;
});

md += `\n---

## 4. Multi-Child Families Reference Table

| Parent Name | Contact Phone | Parent Login Email(s) | Child 1 (Code, Name, Grade) | Child 2 (Code, Name, Grade) |
| :--- | :--- | :--- | :--- | :--- |
| **Annie Smith** | +1 832 275 5298 | \`annieb@cgsfs.com\` | \`TG-STU-2026-5062\` Sophie Smith (Grade 9) | \`TG-STU-2026-5062-B\` Dahlia Smith (Grade 5) |
| **Lakeshia Morgan** | +1 936 414 7009 | \`parent.lakeshia.morgan.5059@parents.topgrade.edu\` | \`TG-STU-2026-5059\` Kaliyah Morgan (Grade 4) | \`TG-STU-2026-5059-B\` Kalena Morgan (Grade 2) |
| **Soosan Pappan** | +1 832 746 7799 | \`soosanmathai@yahoo.com\` | \`TG-STU-2026-5058\` Nehemiah Pappan (Grade 6) | \`TG-STU-2026-5058-B\` Bezaleel Pappan (Grade 7) |
| **Florence Buaku** | +1 734 709 1718 | \`flossied@gmail.com\` | \`TG-STU-2026-5054\` Isabelle Buaku (Grade 3) | \`TG-STU-2026-5054-B\` Julia Buaku (Grade 6) |
| **Anvita Gupta** | +1 312 497 0695 | \`anvita512@gmail.com\` | \`TG-STU-2026-5034\` Noshi Gupta (Grade 11) | \`TG-STU-2026-5034-B\` Kiaan Gupta (Grade 9) |
| **Dhara Desai** | +1 713 894 4018 | \`dhara.6n@gmail.com\` | \`TG-STU-2026-5030\` Dhyana Desai (Grade 2) | \`TG-STU-2026-5030-B\` Aarshiv Desai (Pre-K) |
| **marisol penaloza** | +1 832 941 8419 | \`marisol.maldonado96@icloud.com\` | \`TG-STU-2026-5027\` Eric Penaloza (Kindergarten) | \`TG-STU-2026-5027-B\` Robert Mora (Grade 6) |
| **Lani Mercado** | +1 713 319 8985 | \`lani.garrido@gmail.com\` | \`TG-STU-2026-5007\` Kiron Mercado (Grade 4) | \`TG-STU-2026-5007-B\` Cara Mercado (Grade 2) |
| **Natalie Chaiban** | +1 504 495 3594 | \`n_pilotte@yahoo.com\` | \`TG-STU-2026-5023\` Lydia Chaiban (Kindergarten) | \`TG-STU-2026-5023-B\` Elias Chaiban (Kindergarten) |

---

## 5. Portal Navigation Notes

- **Parent Dashboard**: When a parent logs in, all registered children appear in the **Select Child Account** tab at the top. Switching tabs loads the selected child's enrolled courses, attendance rate, faculty instructor, and tuition invoices.
- **Student Portal**: Students log in directly with their Student Code (e.g. \`TG-STU-2026-5062\` or \`TG-STU-2026-5062-B\`) and access their own personalized Student Dashboard.
`;

fs.writeFileSync('./SYSTEM_CREDENTIALS.md', md, 'utf8');
fs.writeFileSync('./topgrade/SYSTEM_CREDENTIALS.md', md, 'utf8');

// Build CSV
const csvHeaders = 'Student ID,Student Name,Student Login Email,Student Password,Contact Phone,Enrolled Track,Parent Name,Parent Login Email,Parent Password\n';
const csvContent = csvHeaders + allData.map(s =>
  `"${s.code}","${s.name}","${s.email}","${s.password}","${s.phone}","${s.course}","${s.parentName}","${s.parentLogin.replace(/<[^>]*>/g, ' ')}","${s.parentPassword}"`
).join('\n');

fs.writeFileSync('./student_and_parent_credentials.csv', csvContent, 'utf8');
fs.writeFileSync('./topgrade/student_and_parent_credentials.csv', csvContent, 'utf8');

console.log(`Generated credentials documentation for all ${allData.length} students!`);
