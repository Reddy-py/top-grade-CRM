const nodemailer = require(require('path').resolve(__dirname, '../topgrade-backend/node_modules/nodemailer'));

async function testSmtp() {
  const user = 'tglbiz101@gmail.com';
  const pass = 'ldar kjyn plhw ytxj';

  console.log(`Verifying SMTP transport for ${user}...`);
  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user, pass }
  });

  try {
    await transporter.verify();
    console.log('✅ SMTP TRANSPORTER VERIFIED SUCCESSFULLY!');
  } catch (err) {
    console.error('❌ SMTP verification failed:', err.message);
  }
}

testSmtp();
