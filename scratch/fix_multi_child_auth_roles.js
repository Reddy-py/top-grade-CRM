const fs = require('fs');
const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const url = 'https://zznzmzwiewsnmykcbcni.supabase.co';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ4ODk0MSwiZXhwIjoyMDk4MDY0OTQxfQ.P8yhVbJhNoqq_ygIZh9KHlxEEJsBbj2wNAUUBJdvlsY';
const sb = createClient(url, serviceKey);

const multiFamilies = [
  {
    rowNum: 5007,
    parentName: "Lani Mercado",
    parentPhone: "+1 713 319 8985",
    parentPersonalEmail: "lani.garrido@gmail.com",
    parentInstEmail: "parent.lani.mercado.5007@parents.topgrade.edu",
    children: [
      { name: "Kiron Mercado", code: "TG-STU-2026-5007", email: "kiron.5007@student.topgrade.edu", grade: "Grade 4", school: "Silverlake", course: "Afterschool" },
      { name: "Cara Mercado", code: "TG-STU-2026-5007-B", email: "cara.5007b@student.topgrade.edu", grade: "Grade 2", school: "Silverlake", course: "Afterschool" }
    ]
  },
  {
    rowNum: 5023,
    parentName: "Natalie Chaiban",
    parentPhone: "+1 504 495 3594",
    parentPersonalEmail: "n_pilotte@yahoo.com",
    parentInstEmail: "parent.natalie.chaiban.5023@parents.topgrade.edu",
    children: [
      { name: "Lydia Chaiban", code: "TG-STU-2026-5023", email: "lydia.5023@student.topgrade.edu", grade: "Kindergarten", school: "Red Duke", course: "summer camp" },
      { name: "Elias Chaiban", code: "TG-STU-2026-5023-B", email: "elias.5023b@student.topgrade.edu", grade: "Kindergarten", school: "Red Duke", course: "summer camp" }
    ]
  },
  {
    rowNum: 5027,
    parentName: "marisol penaloza",
    parentPhone: "+1 832 941 8419",
    parentPersonalEmail: "marisol.maldonado96@icloud.com",
    parentInstEmail: "parent.marisol.penaloza.5027@parents.topgrade.edu",
    children: [
      { name: "Eric Penaloza", code: "TG-STU-2026-5027", email: "eric.5027@student.topgrade.edu", grade: "Kindergarten", school: "Mary Marek", course: "Afterschool" },
      { name: "Robert Mora", code: "TG-STU-2026-5027-B", email: "robert.mora.5027b@student.topgrade.edu", grade: "Grade 6", school: "Nolan Ryan", course: "Afterschool" }
    ]
  },
  {
    rowNum: 5030,
    parentName: "Dhara Desai",
    parentPhone: "+1 713 894 4018",
    parentPersonalEmail: "dhara.6n@gmail.com",
    parentInstEmail: "parent.dhara.desai.5030@parents.topgrade.edu",
    children: [
      { name: "Dhyana Desai", code: "TG-STU-2026-5030", email: "dhyana.5030@student.topgrade.edu", grade: "Grade 2", school: "Glen York elem", course: "GT prep/ Math & Reading" },
      { name: "Aarshiv Desai", code: "TG-STU-2026-5030-B", email: "aarshiv.5030b@student.topgrade.edu", grade: "Pre-K", school: "Glen York elem", course: "GT prep/ Math & Reading" }
    ]
  },
  {
    rowNum: 5034,
    parentName: "Anvita Gupta",
    parentPhone: "+1 312 497 0695",
    parentPersonalEmail: "anvita512@gmail.com",
    parentInstEmail: "parent.anvita.gupta.5034@parents.topgrade.edu",
    children: [
      { name: "Noshi Gupta", code: "TG-STU-2026-5034", email: "noshi.5034@student.topgrade.edu", grade: "Grade 11", school: "Top Grade Academy", course: "General Track" },
      { name: "Kiaan Gupta", code: "TG-STU-2026-5034-B", email: "kiaan.5034b@student.topgrade.edu", grade: "Grade 9", school: "Top Grade Academy", course: "General Track" }
    ]
  },
  {
    rowNum: 5054,
    parentName: "Florence Buaku",
    parentPhone: "+1 734 709 1718",
    parentPersonalEmail: "flossied@gmail.com",
    parentInstEmail: "parent.florence.buaku.5054@parents.topgrade.edu",
    children: [
      { name: "Isabelle Buaku", code: "TG-STU-2026-5054", email: "isabelle.5054@student.topgrade.edu", grade: "Grade 3", school: "Silvercrest", course: "Afterschool" },
      { name: "Julia Buaku", code: "TG-STU-2026-5054-B", email: "julia.5054b@student.topgrade.edu", grade: "Grade 6", school: "Rogers", course: "Afterschool" }
    ]
  },
  {
    rowNum: 5058,
    parentName: "Soosan Pappan",
    parentPhone: "+1 832 746 7799",
    parentPersonalEmail: "soosanmathai@yahoo.com",
    parentInstEmail: "parent.soosan.pappan.5058@parents.topgrade.edu",
    children: [
      { name: "Nehemiah Pappan", code: "TG-STU-2026-5058", email: "nehemiah.5058@student.topgrade.edu", grade: "Grade 6", school: "Sablatura", course: "ESL" },
      { name: "Bezaleel Pappan", code: "TG-STU-2026-5058-B", email: "bezaleel.5058b@student.topgrade.edu", grade: "Grade 7", school: "PJHW", course: "ESL" }
    ]
  },
  {
    rowNum: 5059,
    parentName: "Lakeshia Morgan",
    parentPhone: "+1 936 414 7009",
    parentPersonalEmail: null,
    parentInstEmail: "parent.lakeshia.morgan.5059@parents.topgrade.edu",
    children: [
      { name: "Kaliyah Morgan", code: "TG-STU-2026-5059", email: "kaliyah.5059@student.topgrade.edu", grade: "Grade 4", school: "Wilder elem", course: "Reading & Math" },
      { name: "Kalena Morgan", code: "TG-STU-2026-5059-B", email: "kalena.5059b@student.topgrade.edu", grade: "Grade 2", school: "Wilder elem", course: "Reading & Math" }
    ]
  },
  {
    rowNum: 5062,
    parentName: "Annie Smith",
    parentPhone: "+1 832 275 5298",
    parentPersonalEmail: "annieb@cgsfs.com",
    parentInstEmail: "parent.annie.smith.5062@parents.topgrade.edu",
    children: [
      { name: "Sophie Smith", code: "TG-STU-2026-5062", email: "sophie.5062@student.topgrade.edu", grade: "Grade 9", school: "Turner", course: "Afterschool" },
      { name: "Dahlia Smith", code: "TG-STU-2026-5062-B", email: "dahlia.5062b@student.topgrade.edu", grade: "Grade 5", school: "Rogers", course: "Afterschool" }
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

async function fixRoles() {
  console.log('=== FIXING ROLES AND PASSWORDS FOR MULTI-CHILD FAMILIES ===\n');
  const authUsers = await getAllAuthUsers();

  for (const family of multiFamilies) {
    console.log(`Processing ${family.parentName}:`);

    // 1. Ensure/Update Parent Institutional Account
    const parentMeta = {
      role: 'PARENT',
      full_name: family.parentName,
      father_name: family.parentName,
      child_name: family.children.map(c => c.name).join(', '),
      child_code: family.children.map(c => c.code).join(', '),
      children: family.children.map(c => c.name),
      child_codes: family.children.map(c => c.code),
      student_id_code: family.children.map(c => c.code).join(', '),
      phone: family.parentPhone,
      email_verified: true
    };

    let pInst = authUsers.find(u => u.email === family.parentInstEmail);
    if (pInst) {
      await sb.auth.admin.updateUserById(pInst.id, {
        password: 'Parent@TopGrade2026',
        email_confirm: true,
        user_metadata: parentMeta
      });
      await sb.from('profiles').upsert({
        id: pInst.id,
        email: family.parentInstEmail,
        full_name: family.parentName,
        phone: family.parentPhone,
        role: 'PARENT',
        status: 'Active'
      });
      console.log(`  Updated parent inst: ${family.parentInstEmail}`);
    } else {
      const { data: newP, error: pErr } = await sb.auth.admin.createUser({
        email: family.parentInstEmail,
        password: 'Parent@TopGrade2026',
        email_confirm: true,
        user_metadata: parentMeta
      });
      if (pErr) console.error(`  Error creating parent inst ${family.parentInstEmail}:`, pErr.message);
      else {
        console.log(`  Created parent inst: ${family.parentInstEmail}`);
        await sb.from('profiles').upsert({
          id: newP.user.id,
          email: family.parentInstEmail,
          full_name: family.parentName,
          phone: family.parentPhone,
          role: 'PARENT',
          status: 'Active'
        });
      }
    }

    // 2. Ensure/Update Parent Personal Account
    if (family.parentPersonalEmail) {
      let pPers = authUsers.find(u => u.email === family.parentPersonalEmail.toLowerCase());
      if (pPers) {
        await sb.auth.admin.updateUserById(pPers.id, {
          password: 'Parent@TopGrade2026',
          email_confirm: true,
          user_metadata: parentMeta
        });
        await sb.from('profiles').upsert({
          id: pPers.id,
          email: family.parentPersonalEmail.toLowerCase(),
          full_name: family.parentName,
          phone: family.parentPhone,
          role: 'PARENT',
          status: 'Active'
        });
        console.log(`  Updated parent personal: ${family.parentPersonalEmail}`);
      } else {
        const { data: newPers, error: persErr } = await sb.auth.admin.createUser({
          email: family.parentPersonalEmail.toLowerCase(),
          password: 'Parent@TopGrade2026',
          email_confirm: true,
          user_metadata: parentMeta
        });
        if (persErr) console.error(`  Error creating parent personal:`, persErr.message);
        else {
          console.log(`  Created parent personal: ${family.parentPersonalEmail}`);
          await sb.from('profiles').upsert({
            id: newPers.user.id,
            email: family.parentPersonalEmail.toLowerCase(),
            full_name: family.parentName,
            phone: family.parentPhone,
            role: 'PARENT',
            status: 'Active'
          });
        }
      }
    }

    // 3. Ensure/Update each child's Student Account
    for (const child of family.children) {
      const studentMeta = {
        role: 'STUDENT',
        full_name: child.name,
        student_id_code: child.code,
        student_code: child.code,
        parent_name: family.parentName,
        email_verified: true
      };

      let stuUser = authUsers.find(u => u.email === child.email);
      let stuUserId = null;
      if (stuUser) {
        stuUserId = stuUser.id;
        await sb.auth.admin.updateUserById(stuUser.id, {
          email: child.email,
          password: 'Student@TopGrade2026',
          email_confirm: true,
          user_metadata: studentMeta
        });
        console.log(`  Updated student auth: ${child.name} (${child.email})`);
      } else {
        const { data: newStu, error: sErr } = await sb.auth.admin.createUser({
          email: child.email,
          password: 'Student@TopGrade2026',
          email_confirm: true,
          user_metadata: studentMeta
        });
        if (sErr) console.error(`  Error creating student auth ${child.email}:`, sErr.message);
        else {
          stuUserId = newStu.user.id;
          console.log(`  Created student auth: ${child.name} (${child.email})`);
        }
      }

      if (stuUserId) {
        await sb.from('profiles').upsert({
          id: stuUserId,
          email: child.email,
          full_name: child.name,
          phone: family.parentPhone,
          role: 'STUDENT',
          status: 'Active'
        });

        // Ensure students table points to this student email and user_id
        await sb.from('students').update({
          user_id: stuUserId,
          email: child.email,
          name: child.name,
          father_name: family.parentName,
          father_phone: family.parentPhone,
          phone: family.parentPhone
        }).eq('student_id_code', child.code);
      }
    }
    console.log('----------------------------------------------------');
  }

  console.log('=== ROLE FIX COMPLETE ===');
}

fixRoles().catch(console.error);
