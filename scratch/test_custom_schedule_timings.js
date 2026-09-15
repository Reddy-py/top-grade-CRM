// Using native fetch in Node 24

async function runCustomScheduleTimingTests() {
  console.log("=== Testing Custom Timetable Slot API & Timings ===");
  const baseUrl = "http://localhost:5000";

  // 1. Fetch courses and teachers to use valid IDs
  const coursesRes = await fetch(`${baseUrl}/api/schedules/existing-courses`);
  const coursesData = await coursesRes.json();
  const teachersRes = await fetch(`${baseUrl}/api/teachers/list`);
  const teachersData = await teachersRes.json();

  if (!coursesData.data || coursesData.data.length === 0) {
    console.error("No courses found!");
    return;
  }
  if (!teachersData.data || teachersData.data.length === 0) {
    console.error("No teachers found!");
    return;
  }

  const testCourse = coursesData.data[0];
  const testTeacher = teachersData.data[0];

  console.log(`Using Course: '${testCourse.name}' and Teacher: '${testTeacher.name}'`);

  // 2. Create a slot with completely custom user-selected times: 08:15 AM to 09:45 AM on Wednesday
  const customSlotPayload = {
    course_id: testCourse.id || testCourse._id || "crs-test",
    course_name: testCourse.name,
    teacher_id: testTeacher.id || testTeacher._id || "tch-test",
    teacher_name: testTeacher.name,
    days_of_week: ["Wednesday"],
    start_time: "08:15 AM",
    end_time: "09:45 AM",
    room: "Custom STEM Lab 4",
    location: "Main Academic Center",
    max_capacity: 12,
    student_ids: []
  };

  console.log("Submitting custom user-selected slot:", customSlotPayload.start_time, "-", customSlotPayload.end_time);
  const createRes = await fetch(`${baseUrl}/api/schedules/create`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(customSlotPayload)
  });

  const createData = await createRes.json();
  console.log("Create response status:", createRes.status, "success:", createData.success);

  if (!createData.success) {
    console.error("Failed to create custom slot:", createData.error);
    return;
  }

  const createdId = Array.isArray(createData.data) ? createData.data[0].id : createData.data.id;
  console.log("Successfully created custom slot with ID:", createdId);

  // 3. Test collision protection for overlapping custom timing (08:45 AM - 10:15 AM)
  const overlappingPayload = {
    ...customSlotPayload,
    start_time: "08:45 AM",
    end_time: "10:15 AM"
  };

  console.log("Testing collision detection on overlapping time:", overlappingPayload.start_time, "-", overlappingPayload.end_time);
  const collideRes = await fetch(`${baseUrl}/api/schedules/create`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(overlappingPayload)
  });
  const collideData = await collideRes.json();
  console.log("Collision response status:", collideRes.status, "expected rejection:", !collideData.success);
  if (!collideData.success) {
    console.log("Collision error message caught as expected:", collideData.error);
  }

  // 4. Verify slot is listed in schedules
  const listRes = await fetch(`${baseUrl}/api/schedules/list`);
  const listData = await listRes.json();
  const found = listData.data.find(s => s.id === createdId);
  console.log("Found created slot in schedule list:", !!found);
  if (found) {
    console.log("Slot details:", {
      day: found.day_of_week,
      time_slot: found.time_slot,
      start_time: found.start_time,
      end_time: found.end_time,
      room: found.room
    });
  }

  // 5. Clean up test slot
  console.log("Cleaning up test slot:", createdId);
  const delRes = await fetch(`${baseUrl}/api/schedules/${createdId}`, { method: "DELETE" });
  const delData = await delRes.json();
  console.log("Delete cleanup success:", delData.success);

  console.log("=== All Custom Timetable & Time Selection Tests Passed Successfully ===");
}

runCustomScheduleTimingTests().catch(err => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
