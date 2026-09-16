const http = require('http');

async function get(path) {
  return new Promise((resolve, reject) => {
    http.get('http://localhost:5000' + path, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve(JSON.parse(d)); } catch (e) { resolve(d); }
      });
    }).on('error', reject);
  });
}

async function post(path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request('http://localhost:5000' + path, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }
    }, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve(JSON.parse(d)); } catch (e) { resolve(d); }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function run() {
  console.log('=== TEST 1: Backend Health & Port 5000 ===');
  const health = await get('/api/health');
  console.log('Health check response:', health);

  console.log('\n=== TEST 2: Accountant Role Resolution with sivareddy683970@gmail.com ===');
  const roleRes = await post('/api/students/resolve-role', { identifier: 'sivareddy683970@gmail.com' });
  console.log('Role resolved for sivareddy683970@gmail.com:', roleRes);

  console.log('\n=== TEST 3: Birthday Scanner Endpoint ===');
  const bdayRes = await post('/api/notifications/send-birthday-wishes', {});
  console.log('Birthday scan trigger result:', bdayRes);

  console.log('\n=== TEST 4: Schedules List Endpoint (Auto-sync verification) ===');
  const schedList = await get('/api/schedules/list');
  console.log('Schedules count:', schedList?.data?.length || schedList?.length || 0);

  console.log('\n=== ALL AUTOMATED TESTS COMPLETED ===');
}

run().catch(console.error);
