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
  const email = "tglbiz101@gmail.com";
  const password = "TopGrade2026!";

  console.log(`Checking/provisioning ${email}...`);

  // Check if exists
  const { data: usersData } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
  let user = usersData.users.find(u => u.email?.toLowerCase() === email.toLowerCase());

  if (!user) {
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: "System Administrator",
        role: "ADMIN"
      }
    });
    if (error) {
      console.error("Error creating user in Supabase Auth:", error);
      return;
    }
    user = data.user;
    console.log("Created user in Supabase Auth:", user.id);
  } else {
    console.log("User already exists in Supabase Auth:", user.id);
    // Update password and metadata to be sure
    const { data: upd, error: updErr } = await supabaseAdmin.auth.admin.updateUserById(user.id, {
      password,
      email_confirm: true,
      user_metadata: {
        full_name: "System Administrator",
        role: "ADMIN"
      }
    });
    if (updErr) console.error("Error updating user:", updErr);
    else console.log("Updated user password and metadata.");
  }

  // Ensure profiles table has it
  const { data: prof, error: profErr } = await supabaseAdmin
    .from("profiles")
    .upsert({
      id: user.id,
      email,
      full_name: "System Administrator",
      role: "ADMIN",
      status: "Active",
      updated_at: new Date().toISOString()
    })
    .select();

  if (profErr) {
    console.error("Error upserting profile:", profErr);
  } else {
    console.log("Upserted profile successfully:", prof);
  }

  // Verify signInWithPassword using anon key
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6bnptendpZXdzbm15a2NiY25pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0ODg5NDEsImV4cCI6MjA5ODA2NDk0MX0._fQr1yqqa7eeW0DBYy51rcComrRfLS-K0niuqDQNf9E';
  const client = createClient(process.env.SUPABASE_URL, anonKey);
  const { data: authTest, error: authErr } = await client.auth.signInWithPassword({
    email,
    password
  });

  if (authErr) {
    console.error("Auth test failed:", authErr.message);
  } else {
    console.log("✅ LIVE SUPABASE AUTH LOGIN TEST PASSED! User ID:", authTest.user?.id, "Role:", authTest.user?.user_metadata?.role);
  }
}

main().catch(console.error);
