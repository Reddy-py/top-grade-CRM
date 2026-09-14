const fs = require('fs');

const multiRows = [
  {
    rowNum: 5007,
    parentName: "Lani Mercado",
    parentPhone: "+1 713 319 8985",
    parentEmail: "lani.garrido@gmail.com",
    children: [
      {
        name: "Kiron Mercado",
        code: "TG-STU-2026-5007",
        grade: "Grade 4",
        age: 9,
        school: "Silverlake",
        course: "Afterschool"
      },
      {
        name: "Cara Mercado",
        code: "TG-STU-2026-5007-B",
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
    parentEmail: "n_pilotte@yahoo.com",
    children: [
      {
        name: "Lydia Chaiban",
        code: "TG-STU-2026-5023",
        grade: "Kindergarten",
        age: 5,
        school: "Red Duke",
        course: "summer camp"
      },
      {
        name: "Elias Chaiban",
        code: "TG-STU-2026-5023-B",
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
    parentEmail: "marisol.maldonado96@icloud.com",
    children: [
      {
        name: "Eric Penaloza",
        code: "TG-STU-2026-5027",
        grade: "Kindergarten",
        age: 5,
        school: "Mary Marek",
        course: "Afterschool"
      },
      {
        name: "Robert Mora",
        code: "TG-STU-2026-5027-B",
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
    parentEmail: "dhara.6n@gmail.com",
    children: [
      {
        name: "Dhyana Desai",
        code: "TG-STU-2026-5030",
        grade: "Grade 2",
        age: 7,
        school: "Glen York elem",
        course: "GT prep/ Math & Reading"
      },
      {
        name: "Aarshiv Desai",
        code: "TG-STU-2026-5030-B",
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
    parentEmail: "anvita512@gmail.com",
    children: [
      {
        name: "Noshi Gupta",
        code: "TG-STU-2026-5034",
        grade: "Grade 11",
        age: 16,
        school: "Top Grade Academy",
        course: "General Track"
      },
      {
        name: "Kiaan Gupta",
        code: "TG-STU-2026-5034-B",
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
    parentEmail: "flossied@gmail.com",
    children: [
      {
        name: "Isabelle Buaku",
        code: "TG-STU-2026-5054",
        grade: "Grade 3",
        age: 8,
        school: "Silvercrest",
        course: "Afterschool"
      },
      {
        name: "Julia Buaku",
        code: "TG-STU-2026-5054-B",
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
    parentEmail: "soosanmathai@yahoo.com",
    children: [
      {
        name: "Nehemiah Pappan",
        code: "TG-STU-2026-5058",
        grade: "Grade 6",
        age: 11,
        school: "Sablatura",
        course: "ESL"
      },
      {
        name: "Bezaleel Pappan",
        code: "TG-STU-2026-5058-B",
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
    parentEmail: null,
    children: [
      {
        name: "Kaliyah Morgan",
        code: "TG-STU-2026-5059",
        grade: "Grade 4",
        age: 9,
        school: "Wilder elem",
        course: "Reading & Math"
      },
      {
        name: "Kalena Morgan",
        code: "TG-STU-2026-5059-B",
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
    parentEmail: "annieb@cgsfs.com",
    children: [
      {
        name: "Sophie Smith",
        code: "TG-STU-2026-5062",
        grade: "Grade 9",
        age: 14,
        school: "Turner",
        course: "Afterschool"
      },
      {
        name: "Dahlia Smith",
        code: "TG-STU-2026-5062-B",
        grade: "Grade 5",
        age: 10,
        school: "Rogers",
        course: "Afterschool"
      }
    ]
  }
];

console.log(`Verified ${multiRows.length} families with multiple children.`);
multiRows.forEach(f => {
  console.log(`\nParent: ${f.parentName} (${f.parentEmail || 'No personal email'})`);
  f.children.forEach(c => {
    console.log(`  - [${c.code}] ${c.name} | ${c.grade} (Age ${c.age}) | School: ${c.school} | Course: ${c.course}`);
  });
});
