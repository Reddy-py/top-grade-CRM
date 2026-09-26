const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
require(path.resolve(__dirname, '../topgrade-backend/node_modules/dotenv')).config({ path: path.resolve(__dirname, '../topgrade-backend/.env') });
const nodemailer = require(path.resolve(__dirname, '../topgrade-backend/node_modules/nodemailer'));

async function testSend() {
  const user = process.env.GMAIL_USER;
  const pass = process.env.GMAIL_APP_PASSWORD;
  const fromEmail = process.env.GMAIL_SENDER_EMAIL || user;
  const toEmail = 'sivareddy683970@gmail.com';

  console.log(`Sending from: "${fromEmail}" to "${toEmail}" using auth "${user}"...`);

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user, pass }
  });

  try {
    const info = await transporter.sendMail({
      from: `"Top Grade Learning" <${fromEmail}>`,
      to: toEmail,
      subject: `🎂 Happy Birthday Test! Best Wishes from Top Grade Learning 🎉`,
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px; background: #fff0f5; border-radius: 10px;">
          <h1 style="color: #d946ef;">🎂 Happy Birthday from Top Grade Learning!</h1>
          <p>This is a live test email sent directly from <strong>${fromEmail}</strong> to <strong>${toEmail}</strong>.</p>
          <p>Time sent: ${new Date().toISOString()}</p>
        </div>
      `
    });

    console.log('✅ Email sent successfully!');
    console.log('Message ID:', info.messageId);
    console.log('Accepted:', info.accepted);
    console.log('Rejected:', info.rejected);
    console.log('Response:', info.response);
  } catch (err) {
    console.error('❌ Error sending mail:', err);
  }
}

testSend();
