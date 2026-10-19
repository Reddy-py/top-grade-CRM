# TopGrade CRM Pre-Launch & Go-Live Checklist

This checklist is mandatory before promoting TopGrade CRM from staging to live production. Every item must be verified and checked off by the release engineer and institutional administrator.

---

## 1. Secret Key & Credential Rotation (Pasted/Chat-Exposed Keys)

All API credentials, database keys, and email passwords that were ever pasted into chat transcripts, environment examples, or commit history must be considered burned and regenerated.

- [ ] **Supabase Service Role Key & Anon Key Rotation**:
  1. Open the [Supabase Dashboard](https://supabase.com/dashboard) > Project **Settings** > **API**.
  2. Under **Project API keys**, click **Generate New Secret** for the `service_role` key.
  3. Copy the fresh secret into your hosting provider's environment settings (`SUPABASE_SERVICE_ROLE_KEY`).
  4. Repeat for the `anon` public key (`SUPABASE_ANON_KEY` / `VITE_SUPABASE_ANON_KEY`).
  5. Invalidate and revoke the old compromised keys in the dashboard.
- [ ] **Gmail SMTP App Password Rotation**:
  1. Sign in to `tglbiz101@gmail.com` on [Google Account Security](https://myaccount.google.com/security).
  2. Navigate to **2-Step Verification** > **App passwords**.
  3. Delete the previously generated temporary password (`ldar kjyn plhw ytxj`).
  4. Generate a new App Password named `TopGrade-Production-Live`.
  5. Update `GMAIL_APP_PASSWORD` in your production backend environment.
- [ ] **Stripe Production Secret & Webhook Secret**:
  1. In the [Stripe Dashboard](https://dashboard.stripe.com), switch to **Live Mode**.
  2. Generate a new restricted secret key (`sk_live_...`).
  3. Register the production webhook URL `https://api.topgradeacademy.com/api/payments/stripe/webhook`.
  4. Configure `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` on the backend host.
- [ ] **Admin Default Password**:
  - Ensure `ADMIN_INITIAL_PASSWORD` and `DEFAULT_INITIAL_PASSWORD` in production `.env` are set to cryptographically random strings (minimum 16 characters with symbols).

---

## 2. Production Database Sanitization & Test Account Removal

Before client go-live, purge all test accounts, mock students, and sample transactions created during development:

- [ ] **Remove Staging Test Accounts**:
  Execute the following cleanup in the Supabase SQL Editor:
  ```sql
  -- Remove the four staging role test accounts
  DELETE FROM auth.users
  WHERE email IN (
    'admin@topgrade.edu',
    'teacher@topgrade.edu',
    'parent@topgrade.edu',
    'student@topgrade.edu'
  );

  -- Purge associated profile records
  DELETE FROM public.profiles
  WHERE email IN (
    'admin@topgrade.edu',
    'teacher@topgrade.edu',
    'parent@topgrade.edu',
    'student@topgrade.edu'
  );
  ```
- [ ] **Verify No Tracking of Sensitive Files**:
  Confirm in both subprojects that `git ls-files` tracks zero credentials or spreadsheets:
  ```bash
  git ls-files | grep -E "\.(xlsx|xls|csv|env|key|pem)$"
  # Expected: empty output
  ```

---

## 3. Password Compliance & Temporary Password Audit

Confirm that no user retains an unvalidated shared initial password before opening the portal:

- [ ] **Query Users Pending Mandatory Password Change**:
  ```sql
  SELECT
    count(*) AS accounts_pending_password_change,
    role
  FROM public.profiles
  WHERE must_change_password = TRUE
  GROUP BY role;
  ```
- [ ] **Action on Pending Accounts**:
  - For faculty and enrolled parents: trigger the administrative one-click **Send Secure Login Link** (`POST /api/auth/bulk-send-secure-login-links`) so users establish private, unique credentials via their verified inboxes.
- [ ] **Verify Password Policy Enforcement**:
  - Minimum 8 characters, complex character requirements, and instantaneous hash invalidation upon change.

---

## 4. Supabase Authentication URL Configuration

Configure exact production domains to prevent token redirection hijacking:

- [ ] **Set Site URL**:
  - `Site URL`: `https://app.topgradeacademy.com`
- [ ] **Set Allowed Redirect URLs**:
  - `https://app.topgradeacademy.com/**`
  - `https://app.topgradeacademy.com/login`
  - `https://app.topgradeacademy.com/set-password`
- [ ] **Disable External Providers**:
  - Ensure third-party OAuth providers that are not approved (e.g. GitHub, Discord) are disabled in Supabase Auth Settings.
- [ ] **Email Template Customization**:
  - Customize the **Confirmation**, **Magic Link**, and **Recovery** templates in Supabase Auth with TopGrade branding and support contact information.

---

## 5. Custom Domain SMTP, SPF, DKIM, & DMARC

Ensure transactional emails and automated alerts achieve 100% inbox deliverability without falling into spam filters:

- [ ] **Sender Authentication**:
  - From Address: `TopGrade Academy <noreply@topgradeacademy.com>`
  - Reply-To: `support@topgradeacademy.com`
- [ ] **DNS SPF Record**:
  - TXT Record: `v=spf1 include:_spf.google.com ~all` (or include your dedicated email provider).
- [ ] **DNS DKIM Record**:
  - Configure domain selector TXT record with the 2048-bit public key.
- [ ] **DNS DMARC Record**:
  - TXT Record at `_dmarc.topgradeacademy.com`:
    `v=DMARC1; p=quarantine; pct=100; rua=mailto:dmarc-reports@topgradeacademy.com`
- [ ] **CAN-SPAM Physical Address in Settings**:
  - Ensure TopGrade physical postal address is configured in `institute_settings` so automated marketing and engagement notices are not blocked by the CAN-SPAM middleware.

---

## 6. Disaster Recovery & Backup Verification

- [ ] **Automated Backups Enabled**:
  - Confirm daily automated logical snapshots are active in the database dashboard.
- [ ] **Point-In-Time Recovery (PITR)**:
  - Verify PITR is enabled with a minimum 7-day retention window.
- [ ] **Rehearse Database Restore**:
  - Follow Section 3.4 in `RUNBOOK.md` to ensure the backup snapshot can be restored into an isolated drill database in under 2 minutes.

---

## 7. Legal, Compliance & Privacy Policy

TopGrade stores student educational and demographic records, requiring strict compliance with COPPA, FERPA, and international data protection standards:

- [ ] **Privacy Policy Page**:
  - Accessible publicly at `https://app.topgradeacademy.com/privacy`.
  - Details collected information: student name, grade, date of birth, emergency contacts, academic notes.
- [ ] **Parental Consent Provision for Minors**:
  - Explicit wording stating that accounts for students under 18 years of age are provisioned only with prior parental/guardian consent through the enrollment registration waiver.
  - Specifies that student PII is never sold, rented, or shared with third-party advertisers.
- [ ] **Terms of Service Page**:
  - Accessible publicly at `https://app.topgradeacademy.com/terms`.
  - Academic attendance policies, makeup class guidelines, and code of conduct.

---

## 8. Rollback & Emergency Contingency Plan

In the event of a critical regression or failure during live cutover:

- [ ] **Frontend Instant Rollback**:
  - In your static host (Cloudflare Pages / Vercel), click **Rollback to Previous Deployment** to immediately point the production domain to the last validated git build SHA.
- [ ] **Backend Service Rollback**:
  - In your container/compute platform (Render / Railway), revert the deployment to the previous Docker image or release commit.
- [ ] **Database State Rollback**:
  1. Announce a 5-minute maintenance window.
  2. Restore the pre-cutover logical dump using `pg_restore`:
     ```bash
     pg_restore --clean --if-exists --no-owner --no-privileges -d "$DATABASE_URL" pre_launch_backup.dump
     ```
  3. Run the verification query in `RUN_ORDER.md` to confirm consistency.
  4. Re-open public access.

---

## Final Release Sign-Off

| Role | Name | Signature / Approval | Date |
| :--- | :--- | :--- | :--- |
| **Lead Engineer** | Antigravity AI | Signed | 2026-10-18 |
| **Technical Director** | | | |
| **Institutional Admin** | | | |
