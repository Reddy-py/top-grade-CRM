async function testApiCall() {
  const url = 'http://localhost:5000/api/notifications/send-birthday-wish';
  const payload = {
    studentName: 'Siva Reddy',
    studentEmail: 'sivareddy683970@gmail.com',
    dob: '2003-04-08'
  };

  console.log('Sending POST to', url, 'with payload:', payload);

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  const json = await res.json();
  console.log('HTTP Status:', res.status);
  console.log('Response body:', json);
}

testApiCall().catch(console.error);
