const fs = require('fs');
const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const url = 'https://zznzmzwiewsnmykcbcni.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ4ODk0MSwiZXhwIjoyMDk4MDY0OTQxfQ.P8yhVbJhNoqq_ygIZh9KHlxEEJsBbj2wNAUUBJdvlsY';
const sb = createClient(url, serviceKey);

// Detailed definition of the 9 multi-child families
const multiFamilies = [
  {
    rowNum: 5007,
    parentName: "Lani Mercado",
    parentPhone: "+1 713 319 8985",
    parentPersonalEmail: "lani.garrido@gmail.com",
    parentInstEmail: "parent.lani.mercado.5007@parents.topgrade.edu",
    children: [
      {
        name: "Kiron Mercado",
        code: "TG-STU-2026-5007",
        email: "kiron.5007@student.topgrade.edu",
        grade: "Grade 4",
        age: 9,
        school: "Silverlake",
        course: "Afterschool"
      },
      {
        name: "Cara Mercado",
        code: "TG-STU-2026-5007-B",
        email: "cara.5007b@student.topgrade.edu",
        grade: "Grade 2",
        age: 7,
        school: "Silverlake",
        course: "Afterschool"
      }
    ]
  },
  {
    rowNum: 5023,
    parentName: "Natalie Chaiban",
    parentPhone: "+1 504 495 3594",
    parentPersonalEmail: "n_pilotte@yahoo.com",
    parentInstEmail: "parent.natalie.chaiban.5023@parents.topgrade.edu",
    children: [
      {
        name: "Lydia Chaiban",
        code: "TG-STU-2026-5023",
        email: "lydia.5023@student.topgrade.edu",
        grade: "Kindergarten",
        age: 5,
        school: "Red Duke",
        course: "summer camp"
      },
      {
        name: "Elias Chaiban",
        code: "TG-STU-2026-5023-B",
        email: "elias.5023b@student.topgrade.edu",
        grade: "Kindergarten",
        age: 5,
        school: "Red Duke",
        course: "summer camp"
      }
    ]
  },
  {
    rowNum: 5027,
    parentName: "marisol penaloza",
    parentPhone: "+1 832 941 8419",
    parentPersonalEmail: "marisol.maldonado96@icloud.com",
    parentInstEmail: "parent.marisol.penaloza.5027@parents.topgrade.edu",
    children: [
      {
        name: "Eric Penaloza",
        code: "TG-STU-2026-5027",
        email: "eric.5027@student.topgrade.edu",
        grade: "Kindergarten",
        age: 5,
        school: "Mary Marek",
        course: "Afterschool"
      },
      {
        name: "Robert Mora",
        code: "TG-STU-2026-5027-B",
        email: "robert.mora.5027b@student.topgrade.edu",
        grade: "Grade 6",
        age: 11,
        school: "Nolan Ryan",
        course: "Afterschool"
      }
    ]
  },
  {
    rowNum: 5030,
    parentName: "Dhara Desai",
    parentPhone: "+1 713 894 4018",
    parentPersonalEmail: "dhara.6n@gmail.com",
    parentInstEmail: "parent.dhara.desai.5030@parents.topgrade.edu",
    children: [
      {
        name: "Dhyana Desai",
        code: "TG-STU-2026-5030",
        email: "dhyana.5030@student.topgrade.edu",
        grade: "Grade 2",
        age: 7,
        school: "Glen York elem",
        course: "GT prep/ Math & Reading"
      },
      {
        name: "Aarshiv Desai",
        code: "TG-STU-2026-5030-B",
        email: "aarshiv.5030b@student.topgrade.edu",
        grade: "Pre-K",
        age: 4,
        school: "Glen York elem",
        course: "GT prep/ Math & Reading"
      }
    ]
  },
  {
    rowNum: 5034,
    parentName: "Anvita Gupta",
    parentPhone: "+1 312 497 0695",
    parentPersonalEmail: "anvita512@gmail.com",
    parentInstEmail: "parent.anvita.gupta.5034@parents.topgrade.edu",
    children: [
      {
        name: "Noshi Gupta",
        code: "TG-STU-2026-5034",
        email: "noshi.5034@student.topgrade.edu",
        grade: "Grade 11",
        age: 16,
        school: "Top Grade Academy",
        course: "General Track"
      },
      {
        name: "Kiaan Gupta",
        code: "TG-STU-2026-5034-B",
        email: "kiaan.5034b@student.topgrade.edu",
        grade: "Grade 9",
        age: 14,
        school: "Top Grade Academy",
        course: "General Track"
      }
    ]
  },
  {
    rowNum: 5054,
    parentName: "Florence Buaku",
    parentPhone: "+1 734 709 1718",
    parentPersonalEmail: "flossied@gmail.com",
    parentInstEmail: "parent.florence.buaku.5054@parents.topgrade.edu",
    children: [
      {
        name: "Isabelle Buaku",
        code: "TG-STU-2026-5054",
        email: "isabelle.5054@student.topgrade.edu",
        grade: "Grade 3",
        age: 8,
        school: "Silvercrest",
        course: "Afterschool"
      },
      {
        name: "Julia Buaku",
        code: "TG-STU-2026-5054-B",
        email: "julia.5054b@student.topgrade.edu",
        grade: "Grade 6",
        age: 11,
        school: "Rogers",
        course: "Afterschool"
      }
    ]
  },
  {
    rowNum: 5058,
    parentName: "Soosan Pappan",
    parentPhone: "+1 832 746 7799",
    parentPersonalEmail: "soosanmathai@yahoo.com",
    parentInstEmail: "parent.soosan.pappan.5058@parents.topgrade.edu",
    children: [
      {
        name: "Nehemiah Pappan",
        code: "TG-STU-2026-5058",
        email: "nehemiah.5058@student.topgrade.edu",
        grade: "Grade 6",
        age: 11,
        school: "Sablatura",
        course: "ESL"
      },
      {
        name: "Bezaleel Pappan",
        code: "TG-STU-2026-5058-B",
        email: "bezaleel.5058b@student.topgrade.edu",
        grade: "Grade 7",
        age: 12,
        school: "PJHW",
        course: "ESL"
      }
    ]
  },
  {
    rowNum: 5059,
    parentName: "Lakeshia Morgan",
    parentPhone: "+1 936 414 7009",
    parentPersonalEmail: null,
    parentInstEmail: "parent.lakeshia.morgan.5059@parents.topgrade.edu",
    children: [
      {
        name: "Kaliyah Morgan",
        code: "TG-STU-2026-5059",
        email: "kaliyah.5059@student.topgrade.edu",
        grade: "Grade 4",
        age: 9,
        school: "Wilder elem",
        course: "Reading & Math"
      },
      {
        name: "Kalena Morgan",
        code: "TG-STU-2026-5059-B",
        email: "kalena.5059b@student.topgrade.edu",
        grade: "Grade 2",
        age: 7,
        school: "Wilder elem",
        course: "Reading & Math"
      }
    ]
  },
  {
    rowNum: 5062,
    parentName: "Annie Smith",
    parentPhone: "+1 832 275 5298",
    parentPersonalEmail: "annieb@cgsfs.com",
    parentInstEmail: "parent.annie.smith.5062@parents.topgrade.edu",
    children: [
      {
        name: "Sophie Smith",
        code: "TG-STU-2026-5062",
        email: "sophie.5062@student.topgrade.edu",
        grade: "Grade 9",
        age: 14,
        school: "Turner",
        course: "Afterschool"
      },
      {
        name: "Dahlia Smith",
        code: "TG-STU-2026-5062-B",
        email: "dahlia.5062b@student.topgrade.edu",
        grade: "Grade 5",
        age: 10,
        school: "Rogers",
        course: "Afterschool"
      }
    ]
  }
];

async function getAllAuthUsers() {
  let allUsers = [];
  let page = 1;
  while (true) {
    const { data, error } = await sb.auth.admin.listUsers({ page, perPage: 100 });
    if (error || !data?.users || data.users.length === 0) break;
    allUsers.push(...data.users);
    if (data.users.length < 100) break;
    page++;
  }
  return allUsers;
}

async function splitMultiFamilies() {
  console.log('=== STARTING SEPARATION OF MULTI-CHILD SIBLING FAMILIES ===\n');

  const authUsers = await getAllAuthUsers();
  console.log(`Fetched ${authUsers.length} total auth users from Supabase.`);

  const { data: dbStudents } = await sb.from('students').select('*');
  console.log(`Fetched ${dbStudents.length} total student rows from Supabase.\n`);

  // Local JSON DB
  const localDbPath = path.resolve(__dirname, '../topgrade-backend/data/students_db.json');
  let localDb = JSON.parse(fs.readFileSync(localDbPath, 'utf8'));

  for (const family of multiFamilies) {
    console.log(`>>> Family: Parent "${family.parentName}" (Children: ${family.children.map(c => c.name).join(', ')})`);

    const childNamesStr = family.children.map(c => c.name).join(', ');
    const childCodesStr = family.children.map(c => c.code).join(', ');

    // 1. Process each child
    for (let cIdx = 0; cIdx < family.children.length; cIdx++) {
      const child = family.children[cIdx];
      const isFirst = cIdx === 0;

      console.log(`  -> Processing Child ${cIdx + 1}: ${child.name} (${child.code}) - ${child.grade} at ${child.school}`);

      // Check if student record exists in Supabase
      let existingStu = dbStudents.find(s => s.student_id_code === child.code);

      // Auth Account for Student
      let stuAuthUser = authUsers.find(u => 
        u.email === child.email || 
        u.user_metadata?.student_id_code === child.code ||
        (isFirst && u.user_metadata?.student_id_code === `TG-STU-2026-${family.rowNum}`)
      );

      let stuUserId = null;
      if (stuAuthUser) {
        stuUserId = stuAuthUser.id;
        await sb.auth.admin.updateUserById(stuUserId, {
          email: child.email,
          password: 'Student@TopGrade2026',
          email_confirm: true,
          user_metadata: {
            role: 'STUDENT',
            full_name: child.name,
            student_id_code: child.code,
            student_code: child.code,
            parent_name: family.parentName,
            email_verified: true
          }
        });
        console.log(`     Updated student auth for ${child.name} (${child.email})`);
      } else {
        const { data: newStuAuth, error: newStuErr } = await sb.auth.admin.createUser({
          email: child.email,
          password: 'Student@TopGrade2026',
          email_confirm: true,
          user_metadata: {
            role: 'STUDENT',
            full_name: child.name,
            student_id_code: child.code,
            student_code: child.code,
            parent_name: family.parentName,
            email_verified: true
          }
        });
        if (newStuErr) {
          console.error(`     Error creating student auth:`, newStuErr.message);
        } else {
          stuUserId = newStuAuth.user.id;
          console.log(`     Created new student auth for ${child.name} (${child.email})`);
        }
      }

      // Upsert profiles table for student
      if (stuUserId) {
        await sb.from('profiles').upsert({
          id: stuUserId,
          email: child.email,
          full_name: child.name,
          phone: family.parentPhone,
          role: 'STUDENT',
          status: 'Active',
          updated_at: new Date().toISOString()
        });
      }

      // Upsert Supabase students table
      const stuPayload = {
        name: child.name,
        student_id_code: child.code,
        user_id: stuUserId,
        email: child.email,
        nationality: `Grade: ${child.grade}`,
        address: `School: ${child.school}`,
        program: child.course,
        age: child.age,
        dob: `20${26 - child.age}-01-01`,
        father_name: family.parentName,
        father_phone: family.parentPhone,
        phone: family.parentPhone,
        status: 'ACTIVE'
      };

      if (existingStu) {
        await sb.from('students').update(stuPayload).eq('id', existingStu.id);
        console.log(`     Updated Supabase students table for ${child.code}`);
      } else {
        const { data: inserted, error: insErr } = await sb.from('students').insert(stuPayload).select().single();
        if (insErr) {
          console.error(`     Error inserting student in Supabase:`, insErr.message);
        } else {
          console.log(`     Inserted new student in Supabase: ${child.code} (ID: ${inserted.id})`);
          existingStu = inserted;
        }
      }

      // Update local JSON DB
      const localIdx = localDb.findIndex(s => s.studentCode === child.code);
      const nameParts = child.name.split(' ');
      const localItem = {
        id: existingStu ? existingStu.id : `gen-${child.code}`,
        studentCode: child.code,
        fullName: child.name,
        firstName: nameParts[0] || child.name,
        lastName: nameParts.slice(1).join(' ') || (family.parentName.split(' ').slice(1).join(' ')),
        email: child.email,
        dob: `20${26 - child.age}-01-01`,
        age: child.age,
        school: child.school,
        grade: child.grade,
        status: 'ACTIVE',
        primaryMobile: family.parentPhone,
        studentPhones: [family.parentPhone],
        parentPhones: [family.parentPhone],
        studentEmails: [child.email],
        parentEmails: family.parentPersonalEmail ? [family.parentPersonalEmail, family.parentInstEmail] : [family.parentInstEmail],
        fatherName: family.parentName,
        motherName: '',
        guardianName: family.parentName,
        program: child.course,
        teacher: 'Unassigned',
        residentialAddress: '',
        studentAddress: '',
        alternateAddress: '',
        examDate: '',
        purchasedHours: 20,
        feePlan: 'Standard Plan',
        allocatedCourses: [{ courseName: child.course, duration: '3 Months' }]
      };

      if (localIdx >= 0) {
        localDb[localIdx] = { ...localDb[localIdx], ...localItem };
      } else {
        localDb.push(localItem);
      }
    }

    // 2. Update Parent Auth Metadata with all linked children
    const parentMeta = {
      role: 'PARENT',
      full_name: family.parentName,
      father_name: family.parentName,
      child_name: childNamesStr,
      child_code: childCodesStr,
      children: family.children.map(c => c.name),
      child_codes: family.children.map(c => c.code),
      student_id_code: childCodesStr,
      phone: family.parentPhone,
      email_verified: true
    };

    // Institutional parent account
    let pInstUser = authUsers.find(u => u.email === family.parentInstEmail);
    if (pInstUser) {
      await sb.auth.admin.updateUserById(pInstUser.id, {
        password: 'Parent@TopGrade2026',
        user_metadata: parentMeta
      });
      console.log(`  Updated parent institutional auth (${family.parentInstEmail}) with children: ${childNamesStr}`);
    }

    // Personal parent account
    if (family.parentPersonalEmail) {
      let pPersUser = authUsers.find(u => u.email === family.parentPersonalEmail.toLowerCase());
      if (pPersUser) {
        await sb.auth.admin.updateUserById(pPersUser.id, {
          password: 'Parent@TopGrade2026',
          user_metadata: parentMeta
        });
        console.log(`  Updated parent personal auth (${family.parentPersonalEmail}) with children: ${childNamesStr}`);
      }
    }
    console.log('----------------------------------------------------');
  }

  // Save local JSON DB
  fs.writeFileSync(localDbPath, JSON.stringify(localDb, null, 2), 'utf8');
  console.log(`Updated local JSON database: ${localDbPath}`);
  console.log('=== MULTI-CHILD SEPARATION COMPLETE ===');
}

splitMultiFamilies().catch(err => {
  console.error('Fatal error:', err);
});
