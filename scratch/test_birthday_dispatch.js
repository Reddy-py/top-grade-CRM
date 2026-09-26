const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
require(path.resolve(__dirname, '../topgrade-backend/node_modules/dotenv')).config({ path: path.resolve(__dirname, '../topgrade-backend/.env') });

const nodemailer = require(path.resolve(__dirname, '../topgrade-backend/node_modules/nodemailer'));

async function testDispatch() {
  const gmailUser = process.env.GMAIL_USER;
  const gmailPass = process.env.GMAIL_APP_PASSWORD;
  const adminEmail = process.env.ADMIN_EMAIL;

  console.log('ENV Values:');
  console.log('GMAIL_USER:', gmailUser);
  console.log('GMAIL_APP_PASSWORD exists:', Boolean(gmailPass), 'length:', gmailPass?.length);
  console.log('ADMIN_EMAIL:', adminEmail);

  const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: gmailUser, pass: gmailPass }
  });

  const studentName = 'Siva Reddy';
  const studentEmail = 'sivareddy683970@gmail.com';
  const senderAddress = process.env.GMAIL_SENDER_EMAIL || gmailUser;

  const html = `
    <div style="font-family: 'Segoe UI', Tahoma, sans-serif; background: #fff0f5; padding: 25px; border-radius: 18px; border: 2px solid #ec4899;">
      <div style="text-align: center; margin-bottom: 20px;">
        <span style="font-size: 48px;">🎂 🎈 🎁</span>
        <h1 style="color: #be185d; margin: 10px 0 5px 0; font-size: 26px;">Happy Birthday, ${studentName}!</h1>
        <p style="color: #9d174d; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; font-size: 12px; margin: 0;">Warm Wishes from Top Grade Learning</p>
      </div>
      <div style="background: #ffffff; padding: 25px; border-radius: 14px; color: #334155; line-height: 1.7; font-size: 14px;">
        <p>Dear <strong>${studentName}</strong>,</p>
        <p>On this very special day, your entire faculty and the leadership team at <strong>Top Grade Learning</strong> wish you the happiest of birthdays! 🌟</p>
        <p>May your year ahead be filled with curiosity, continuous learning, exciting milestones, and outstanding achievements in all your academic endeavors.</p>
        <p style="margin-top: 25px; font-weight: bold; color: #004ac6;">
          Warmest Regards,<br/>
          <strong>Top Grade Learning Team</strong><br/>
          <span style="font-size: 12px; color: #64748b; font-weight: normal;">${senderAddress}</span>
        </p>
      </div>
    </div>
  `;

  // We send to BOTH: studentEmail AND adminEmail!
  const recipients = [studentEmail, adminEmail];

  console.log(`\nDispatching real email to BOTH recipients: ${recipients.join(', ')}...`);

  for (const to of recipients) {
    try {
      const info = await transporter.sendMail({
        from: `"Top Grade Learning" <${senderAddress}>`,
        to,
        subject: `🎂 Happy Birthday, ${studentName}! Best Wishes from Top Grade Learning 🎉`,
        html
      });
      console.log(`✅ SUCCESS sending to ${to}! Message ID: ${info.messageId}, Response: ${info.response}`);
    } catch (err) {
      console.error(`❌ FAILED sending to ${to}:`, err.message);
    }
  }
}

testDispatch().catch(console.error);
