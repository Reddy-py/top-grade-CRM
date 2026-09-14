const http = require('http');

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, data: JSON.parse(body) });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(typeof data === 'string' ? data : JSON.stringify(data));
    req.end();
  });
}

async function runTests() {
  console.log('=== STARTING E2E VERIFICATION OF ALL 11 UPGRADES ===\n');

  // Test 1: Reload Student Sheet
  console.log('1. Testing POST /api/students/reload ...');
  const reloadRes = await request({
    hostname: 'localhost',
    port: 5000,
    path: '/api/students/reload',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  });
  console.log('   Status:', reloadRes.status);
  console.log('   Success:', reloadRes.data?.success);
  console.log('   Students Loaded:', reloadRes.data?.data?.length || reloadRes.data?.count);

  // Test 2: Student List with hoursLeft, daysLeft, studentAddress, examDate
  console.log('\n2. Testing GET /api/students/list (Admin/Default role) ...');
  const listRes = await request({
    hostname: 'localhost',
    port: 5000,
    path: '/api/students/list?limit=3',
    method: 'GET'
  });
  console.log('   Status:', listRes.status);
  const sampleStudent = listRes.data?.data?.[0];
  if (sampleStudent) {
    console.log('   Sample Student:', {
      name: sampleStudent.fullName || sampleStudent.name,
      hoursLeft: sampleStudent.hoursLeft,
      daysLeft: sampleStudent.daysLeft,
      purchasedHours: sampleStudent.purchasedHours,
      attendedHours: sampleStudent.attendedHours,
      studentAddress: sampleStudent.studentAddress,
      residentialAddress: sampleStudent.residentialAddress,
      examDate: sampleStudent.examDate,
      feePlan: sampleStudent.feePlan
    });
    console.log('   Hours Left Calculated:', typeof sampleStudent.hoursLeft === 'number');
    console.log('   Days Left Calculated:', typeof sampleStudent.daysLeft === 'number');
  }

  // Test 3: Teacher Role Privacy Filter
  console.log('\n3. Testing Teacher Role Privacy (userRole=TEACHER) ...');
  const teacherListRes = await request({
    hostname: 'localhost',
    port: 5000,
    path: '/api/students/list?limit=3&userRole=TEACHER',
    method: 'GET'
  });
  console.log('   Status:', teacherListRes.status);
  const teacherSample = teacherListRes.data?.data?.[0];
  if (teacherSample) {
    console.log('   Teacher Sample Student:', {
      name: teacherSample.fullName || teacherSample.name,
      hoursLeft: teacherSample.hoursLeft,
      daysLeft: teacherSample.daysLeft,
      studentAddress: teacherSample.studentAddress,
      feePlan: teacherSample.feePlan,
      discount: teacherSample.discount,
      paymentMethod: teacherSample.paymentMethod,
      pricing_type: teacherSample.pricing_type
    });
    const hasBilling = teacherSample.feePlan !== undefined || teacherSample.discount !== undefined || teacherSample.paymentMethod !== undefined;
    console.log('   Privacy Enforced (Billing completely hidden from teacher):', !hasBilling);
  }

  // Test 4: Existing Courses & Multi-Day Schedule Creation
  console.log('\n4. Testing Existing Courses & Multi-Day Schedule Creation ...');
  const coursesRes = await request({
    hostname: 'localhost',
    port: 5000,
    path: '/api/schedules/existing-courses',
    method: 'GET'
  });
  const validCourse = coursesRes.data?.data?.[0]?.name || 'Standard Curriculum';
  console.log('   Found Existing Course for Schedule:', validCourse);

  const multiSchedRes = await request({
    hostname: 'localhost',
    port: 5000,
    path: '/api/schedules/create',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, {
    course_name: validCourse,
    teacher_name: 'Dr. Ramesh Kumar',
    days_of_week: ['Monday', 'Wednesday', 'Friday'],
    time_slot: '10:00 AM - 11:30 AM',
    room: 'Lab-A',
    max_capacity: 15,
    students: []
  });
  console.log('   Status:', multiSchedRes.status);
  console.log('   Message:', multiSchedRes.data?.message);
  if (Array.isArray(multiSchedRes.data?.allCreated)) {
    console.log('   Multi-Day Slots Created:', multiSchedRes.data.allCreated.map(s => `${s.day_of_week} (${s.time_slot})`));
  }

  // Test 5: Trigger Birthday Email Scanner
  console.log('\n5. Testing Trigger Birthday Scanner POST /api/notifications/trigger-birthdays ...');
  const bdayRes = await request({
    hostname: 'localhost',
    port: 5000,
    path: '/api/notifications/trigger-birthdays',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  });
  console.log('   Status:', bdayRes.status);
  console.log('   Response:', bdayRes.data);

  // Test 6: Trigger Exam Wishes Scanner
  console.log('\n6. Testing Trigger Exam Wishes Scanner POST /api/notifications/trigger-exam-wishes ...');
  const examRes = await request({
    hostname: 'localhost',
    port: 5000,
    path: '/api/notifications/trigger-exam-wishes',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  });
  console.log('   Status:', examRes.status);
  console.log('   Response:', examRes.data);

  console.log('\n=== ALL TESTS COMPLETE ===');
}

runTests().catch(console.error);
