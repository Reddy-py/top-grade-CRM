const path = require('path');
const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');
require(path.resolve(__dirname, '../topgrade-backend/node_modules/dotenv')).config({ path: path.resolve(__dirname, '../topgrade-backend/.env') });
const { createClient } = require(path.resolve(__dirname, '../topgrade-backend/node_modules/@supabase/supabase-js'));

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

async function main() {
  const email = "sivareddy68397@gmail.com";
  const password = "TopGrade2026!";

  console.log(`Checking accountant account: ${email}...`);
  const { data: usersData } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
  let user = usersData.users.find(u => u.email?.toLowerCase() === email.toLowerCase());

  if (!user) {
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: "Priya Sharma",
        role: "ACCOUNTANT"
      }
    });
    if (error) {
      console.error("Error creating user:", error.message);
      return;
    }
    user = data.user;
    console.log("Created accountant user in Supabase Auth:", user.id);
  } else {
    console.log("Accountant user already exists:", user.id);
    await supabaseAdmin.auth.admin.updateUserById(user.id, {
      password,
      email_confirm: true,
      user_metadata: {
        full_name: "Priya Sharma",
        role: "ACCOUNTANT"
      }
    });
  }

  // Update profiles table
  await supabaseAdmin.from("profiles").upsert({
    id: user.id,
    email,
    full_name: "Priya Sharma",
    role: "ACCOUNTANT",
    status: "Active",
    updated_at: new Date().toISOString()
  });

  // Verify login
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0ODg5NDEsImV4cCI6MjA5ODA2NDk0MX0._fQr1yqqa7eeW0DBYy51rcComrRfLS-K0niuqDQNf9E';
  const client = createClient(process.env.SUPABASE_URL, anonKey);
  const { data: loginData, error: loginErr } = await client.auth.signInWithPassword({ email, password });
  if (loginErr) {
    console.error("Login verification failed:", loginErr.message);
  } else {
    console.log("✅ Accountant login verified successfully! ID:", loginData.user?.id, "Role:", loginData.user?.user_metadata?.role);
  }
}

main().catch(console.error);
