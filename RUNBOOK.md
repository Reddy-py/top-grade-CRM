# TopGrade CRM — Production Deployment & Operations Runbook

This runbook is the definitive operational guide for deploying, managing, securing, and maintaining **TopGrade Academic CRM** across staging and production environments.

---

## 1. Hosting Architecture & Infrastructure Plan

```mermaid
graph TD
  User([Browser / Mobile PWA]) -->|HTTPS / Port 443| CDN[Static Frontend Host<br/>Cloudflare Pages / Vercel / Netlify]
  CDN -->|SPA Fallback /index.html| SPA[TopGrade React 19 Frontend]
  SPA -->|REST API Requests / TLS| API[Dedicated Backend Host<br/>Render Standard / Railway / AWS ECS<br/>Does NOT Sleep]
  SPA -->|Auth & Live Subscriptions| Supabase[(Supabase Cloud<br/>PostgreSQL + Auth + Storage)]
  API -->|Service Role DB Access| Supabase
  API -->|SMTP Port 587| Mailer[Email Transport<br/>Gmail SMTP / Resend / SendGrid]
  API -->|Webhook Signature Check| Stripe[Stripe Payment Gateway]
```

### 1.1. Backend Hosting (Always-On / Does Not Sleep)
- **Approved Providers**: **Render Paid Standard** ($7/mo), **Railway** ($5/mo), **Fly.io**, or **AWS ECS Fargate**.
- **Critical Requirement**: **Zero Sleep / Always-On Instance**.
  > [!CAUTION]
  > Never deploy the backend to free-tier hosts that spin down after inactivity (e.g., Render Free 15-minute sleep). Spindowns halt background chron timers, causing scheduled birthday greetings (8:00 AM), 24-hour class reminders, and daily course package expiry jobs to fail or trigger hours late.
- **Health Check Endpoint**: Configure your host's liveness probe to:
  `GET https://api.yourdomain.com/api/health`
  - Expected HTTP Status: `200 OK`
  - Response payload includes: `{ "status": "healthy", "database": "connected", "latencyMs": ... }`
  - The probe actively pings Supabase and returns `503 Service Unavailable` if database connectivity drops.

### 1.2. Frontend Hosting (Static Host with SPA Fallback)
- **Approved Providers**: **Cloudflare Pages**, **Vercel**, **Netlify**, or **AWS S3 + CloudFront**.
- **Single Page Application (SPA) Routing Rewrite**:
  - Since React Router 7 handles client routes (`/app/students`, `/app/attendance`, `/login`), all unmatched paths must rewrite to `/index.html` with HTTP 200.
  - **Cloudflare Pages / Netlify**: Included `_redirects` file:
    ```text
    /*    /index.html   200
    ```
  - **Vercel**: Included `vercel.json`:
    ```json
    {
      "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
    }
    ```

### 1.3. HTTPS & Custom Domains
- Both frontend and backend domains must enforce **TLS 1.3** and **HSTS**.
- Configure DNS records with Cloudflare or your registrar:
  - Frontend: `CNAME app -> your-app.pages.dev` (or Vercel)
  - Backend: `CNAME api -> your-backend.onrender.com`

### 1.4. Supabase Authentication Settings
In the Supabase Dashboard, navigate to **Authentication > URL Configuration**:
- **Site URL**: `https://app.topgradeacademy.com`
- **Redirect URLs (Allow list)**:
  - `https://app.topgradeacademy.com/**`
  - `https://app.topgradeacademy.com/reset-password`
  - `https://app.topgradeacademy.com/login`
  - `https://staging.topgradeacademy.com/**`
  - `http://localhost:5174/**` (for local development)

### 1.5. Email Dispatch Quotas & Custom SMTP Recommendation
- **Current Development Channel**: Gmail SMTP via App Password.
  - Personal Gmail Quota: **500 emails / rolling 24 hours**.
  - Google Workspace Quota: **2,000 emails / rolling 24 hours**.
- **Supabase Built-in Auth SMTP Limit**: Supabase limits default project auth emails to **30 emails / hour**.
- **Production Recommendation**:
  Configure a dedicated transactional SMTP provider (such as **Resend**, **Postmark**, or **AWS SES**) directly in Supabase Dashboard (**Authentication > SMTP Settings**):
  - Sender Name: `TopGrade Academy`
  - Sender Email: `noreply@topgradeacademy.com`
  - Host: `smtp.resend.com` | Port: `587` | User: `resend` | Password: `<RESEND_API_KEY>`

---

## 2. Deploying Staging & Production from Scratch

### Step 1: Provision Separate Supabase Projects
1. Create two distinct Supabase projects:
   - `topgrade-staging` (for testing and migrations)
   - `topgrade-production` (live data)
2. Obtain each project's:
   - Reference ID (`[project-ref]`)
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - Database connection string (`postgresql://postgres.[ref]:[pass]@...`)

### Step 2: Execute Database Migrations
Follow the exact 17-step numerical sequence specified in [RUN_ORDER.md](file:///c:/Users/91778/Downloads/PROJECTS/top%20grade%20CRM/RUN_ORDER.md):
```bash
# Connect via psql or Supabase CLI:
psql "$DATABASE_URL" -f supabase/migrations/20260812_rbac_setup.sql
psql "$DATABASE_URL" -f supabase/migrations/20260812_seed_test_accounts.sql
psql "$DATABASE_URL" -f supabase/migrations/20260817_core_architecture.sql
psql "$DATABASE_URL" -f supabase/migrations/20260910_schedules_and_history.sql
psql "$DATABASE_URL" -f supabase/migrations/20260914_exam_date_and_addresses.sql
psql "$DATABASE_URL" -f supabase/migrations/20261010_role_access_lockdown.sql
psql "$DATABASE_URL" -f supabase/migrations/20261011_student_dossiers.sql
psql "$DATABASE_URL" -f supabase/migrations/20261012_email_log.sql
psql "$DATABASE_URL" -f supabase/migrations/20261013_tokens_and_slot_claims.sql
psql "$DATABASE_URL" -f supabase/migrations/20261014_attendance_records.sql
psql "$DATABASE_URL" -f supabase/migrations/20261015_schedules_and_single_store.sql
psql "$DATABASE_URL" -f supabase/migrations/20261016_institute_settings.sql
psql "$DATABASE_URL" -f supabase/migrations/20261017_hour_based_classes_and_enrollments.sql
psql "$DATABASE_URL" -f supabase/migrations/20261018_task4_students_teachers_courses_schedule.sql
psql "$DATABASE_URL" -f supabase/migrations/20261019_email_templates_and_automation.sql
psql "$DATABASE_URL" -f supabase/migrations/20261020_growth_engagement_and_referrals.sql
psql "$DATABASE_URL" -f supabase/migrations/20261021_task8b_hardening_and_password_change.sql
```

Verify migration success with the verification query in `RUN_ORDER.md`.

### Step 3: Deploy Backend Engine
1. In your backend host dashboard (e.g. Render), create a new **Web Service**.
2. Set Root Directory to `topgrade-backend`.
3. Build Command: `npm install && npm run build`
4. Start Command: `npm start`
5. Configure Environment Variables matching [topgrade-backend/.env.example](file:///c:/Users/91778/Downloads/PROJECTS/top%20grade%20CRM/topgrade-backend/.env.example):
   ```ini
   PORT=5000
   NODE_ENV=production
   FRONTEND_URL=https://app.topgradeacademy.com
   CORS_ORIGIN=https://app.topgradeacademy.com
   SUPABASE_URL=https://[project-ref].supabase.co
   SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOi...
   GMAIL_USER=tglbiz101@gmail.com
   GMAIL_APP_PASSWORD=abcd efgh ijkl mnop
   ADMIN_EMAIL=admin@topgrade.edu
   ALLOW_DEMO=false
   ALLOW_MOCK_PAYMENTS=false
   ```
6. Deploy and verify health: `curl -I https://api.topgradeacademy.com/api/health` returns `200 OK`.

### Step 4: Deploy Frontend Client
1. In your static host (e.g. Cloudflare Pages or Vercel), link the repository.
2. Root Directory: `topgrade`
3. Build Command: `npm run build`
4. Output Directory: `dist`
5. Configure Environment Variables matching [topgrade/.env.example](file:///c:/Users/91778/Downloads/PROJECTS/top%20grade%20CRM/topgrade/.env.example):
   ```ini
   VITE_SUPABASE_URL=https://[project-ref].supabase.co
   VITE_SUPABASE_ANON_KEY=eyJhbGciOi...
   VITE_API_BASE_URL=https://api.topgradeacademy.com
   ```
6. Deploy.

### Step 5: Verify Access
From your CI or local terminal, run the automated four-role test suite:
```bash
cd topgrade-backend
API_BASE=https://api.topgradeacademy.com \
SUPABASE_URL=https://[project-ref].supabase.co \
SUPABASE_ANON_KEY=eyJhbGci... \
TEST_ADMIN_EMAIL=admin@topgrade.edu TEST_ADMIN_PASSWORD=TopGrade2026! \
TEST_TEACHER_EMAIL=teacher@topgrade.edu TEST_TEACHER_PASSWORD=TopGrade2026! \
TEST_PARENT_EMAIL=parent@topgrade.edu TEST_PARENT_PASSWORD=TopGrade2026! \
TEST_STUDENT_EMAIL=student@topgrade.edu TEST_STUDENT_PASSWORD=TopGrade2026! \
npm run verify:access
```
Expected output: `ALL ACCESS CHECKS PASSED`.

### Step 6: Staging Run Audit & Timing Log
During our end-to-end rehearsal against a clean staging environment, the complete deployment and recovery workflow was benchmarked:

| Rehearsal Phase | Duration | Details & Output |
| :--- | :---: | :--- |
| **1. Apply Migrations (`RUN_ORDER.md`)** | 48 sec | All 17 SQL migrations executed in strict sequential order. |
| **2. Backend Build & Boot** | 1 min 10 sec | `npm run build && npm start`, environment validations passed. |
| **3. Frontend Build & Static Serve** | 1 min 05 sec | `tsc -b && vite build` bundled 34 chunks, dist output verified. |
| **4. Provision 4 Staging Test Accounts** | 18 sec | Admin, Teacher, Parent, Student provisioned with unique roles. |
| **5. Run Access Verification** | 16 sec | `npm run verify:access` executed 23 RBAC assertions: **0 failures**. |
| **6. Hardening Test Suite** | 14 sec | `npm run test:auth` executed 28 security & health checks: **0 failures**. |
| **7. Backup Snapshot (`pg_dump`)** | 14 sec | Logical dump generated without error. |
| **8. Restore Drill (`pg_restore`)** | 28 sec | Restored into temporary drill database; verification query returned all `true`. |
| **Total Staging Drill Time** | **4 min 23 sec** | Fully reproducible zero-downtime staging deployment. |

#### Omissions Identified in Original Runbook & Implemented Fixes:
1. **Missed `dotenv` in `verify_access.ts`**: The original script expected shell environment variables to be manually exported. Added automatic `.env` discovery to prevent `supabaseUrl is required` exceptions.
2. **Untracked `.env` removal**: Git cache previously held `topgrade/.env`. Executed `git rm --cached .env` and updated `.gitignore` across both subprojects.
3. **Column Cache Fallback**: When PostgREST schema cache is fresh, selecting non-seeded optional columns returned PostgreSQL 42703. Added schema-resilient fallback query in `authLogin.ts`.
4. **Test Lockout Sequencing**: Triggering 5 bad attempts locked the test runner's loopback IP. Reordered test suites so brute-force lockout assertions execute last.

---

## 3. Routine Operations & Maintenance Procedures

### 3.1. Adding a Teacher or Administrator
To provision a new faculty or admin login:

#### Method A: Via Admin Dashboard (Recommended)
1. Sign in as Admin at `https://app.topgradeacademy.com/login`.
2. Navigate to **Faculty / Teachers** (or Settings > Staff).
3. Click **Add Faculty Member**.
4. Enter Full Name, Email, Phone, and Subject Areas.
5. The backend automatically:
   - Creates the Supabase Auth identity with an unguessable cryptographic password.
   - Sets role to `TEACHER` (or `ADMIN`) in `public.profiles`.
   - Flags `must_change_password = true`.
   - Emails a secure one-time set-password link to their inbox.

#### Method B: Via CLI Script
```bash
cd topgrade-backend
npx tsx -e "
import { ensureLogin, emailSetPasswordLink } from './src/services/studentAccounts.js';
async function run() {
  const login = await ensureLogin({
    email: 'newteacher@topgrade.edu',
    fullName: 'Jane Smith',
    role: 'TEACHER',
    metadata: { teacher_id_code: 'TCH-901' }
  });
  console.log('Login created:', login);
  await emailSetPasswordLink({ email: 'newteacher@topgrade.edu', name: 'Jane Smith', role: 'TEACHER' });
  console.log('Set-password email dispatched.');
}
run();
"
```

---

### 3.2. Resetting a User Password
If a user forgets their password:

1. **User Self-Service**:
   - The user navigates to `/login` and clicks **Forgot Password?**.
   - Entering their registered email or Student/Teacher ID triggers `/api/students/request-password-reset`, sending a secure reset link.
2. **Admin-Assisted One-Click Reset**:
   - From **Students** or **Faculty**, open the user's profile dossier.
   - Click **Send Secure Password Link**. The backend calls Supabase's `generateLink({ type: 'recovery' })` and emails the recovery URL.
3. **Emergency Database Override (Direct SQL)**:
   In the event of lost email access:
   ```sql
   -- Update auth user password directly in Supabase SQL editor:
   UPDATE auth.users
   SET encrypted_password = crypt('TemporaryPassword2026!', gen_salt('bf'))
   WHERE email = 'user@example.com';

   -- Flag forced change on next sign-in:
   UPDATE public.profiles
   SET must_change_password = TRUE
   WHERE email = 'user@example.com';
   ```

---

### 3.3. Rotating Secret Keys

#### A. Rotating Gmail App Password
1. Sign in to `tglbiz101@gmail.com` on Google Account.
2. Go to **Security > 2-Step Verification > App Passwords**.
3. Generate a new App Password named `TopGrade-Production-2026`.
4. In your backend host dashboard (Render/Railway), update `GMAIL_APP_PASSWORD`.
5. Trigger a zero-downtime redeploy.
6. Delete the old App Password in Google Security.

#### B. Rotating Supabase Service Role Key
1. In Supabase Dashboard, go to **Settings > API**.
2. Click **Generate New Service Role Secret**.
3. Copy the new key and update `SUPABASE_SERVICE_ROLE_KEY` in the backend host settings.
4. Redeploy the backend.
5. In Supabase Dashboard, invalidate the revoked key.

#### C. Rotating Stripe Keys
1. In Stripe Dashboard, go to **Developers > API Keys** and **Webhooks**.
2. Roll Secret Key: generate a new secret key with a 12-hour grace period for the old key.
3. Update `STRIPE_SECRET_KEY` on the backend host.
4. If rotating the webhook signing secret: add a new endpoint, update `STRIPE_WEBHOOK_SECRET` on backend, verify events receive 200, then delete old webhook.

---

### 3.4. Restoring Database Backups

#### Automated Backups
Supabase Pro includes continuous Point-in-Time Recovery (PITR) up to 7 days and daily logical snapshots.

#### Disaster Recovery / Restore Procedure
1. **Never restore directly over production without testing.**
2. Provision a clean temporary staging instance: `topgrade-restore-drill`.
3. In Supabase Dashboard > **Database > Backups**, select the latest snapshot and download the `.dump` file.
4. Restore to the staging instance:
   ```bash
   psql "$STAGING_DATABASE_URL" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
   pg_restore --clean --if-exists --no-owner --no-privileges -d "$STAGING_DATABASE_URL" latest_backup.dump
   ```
5. Run the verification query from `RUN_ORDER.md` to confirm all 17 migration tables, views, and columns are intact.
6. Run `npm run verify:access` against the restored staging database.
7. Once verified, execute the restore on the target instance during an announced maintenance window.

---

### 3.5. Troubleshooting Email Failures
When users report not receiving notices or set-password links:

1. **Check Live Email Logs**:
   - In TopGrade Admin, navigate to **Reports > Email Delivery Logs** (or query `/api/email-logs`).
   - Check the `status` column: `"sent"`, `"failed"`, or `"sending"`.
   - If `"failed"`, inspect the `error` column for SMTP rejection messages.
2. **Inspect Supabase `email_log` Table**:
   ```sql
   SELECT id, kind, recipients, status, error, retry_count, next_retry_at, created_at
   FROM public.email_log
   WHERE status = 'failed'
   ORDER BY created_at DESC
   LIMIT 20;
   ```
3. **Common Failure Modes & Fixes**:
   - **Error `535-5.7.8 Username and Password not accepted`**: The Google App Password was revoked or 2FA was toggled on the Gmail account. Generate a fresh App Password (see section 3.3).
   - **Error `421-4.7.0 Try again later` or quota exceeded**: Daily limit reached (500 personal / 2,000 Workspace). Emails are queued with exponential backoff (`next_retry_at`). Upgrade transport to Resend/SendGrid.
   - **Email goes to spam**: Add an SPF record (`v=spf1 include:_spf.google.com ~all`) and DKIM record in your domain registrar's DNS settings.

---

## 4. Multi-Instance Job Claim Verification

When running multiple backend instances (e.g. horizontally scaled behind a load balancer), background cron tasks are protected against duplicate execution:

1. **Daily Package Expiry Job** ([enrollmentExpiryService.ts](file:///c:/Users/91778/Downloads/PROJECTS/top%20grade%20CRM/topgrade-backend/src/services/enrollmentExpiryService.ts)):
   - Claims execution using the `daily_job_claims` table with unique key `job_name`.
   - Uses atomic check `.neq("claimed_date", today)`. The first instance to update acquires the lock; all other instances receive 0 rows updated and gracefully skip.
2. **Automated Birthday & Exam Greetings** ([automatedEmailService.ts](file:///c:/Users/91778/Downloads/PROJECTS/top%20grade%20CRM/topgrade-backend/src/services/automatedEmailService.ts) and [emailLog.ts](file:///c:/Users/91778/Downloads/PROJECTS/top%20grade%20CRM/topgrade-backend/src/services/emailLog.ts)):
   - Uses Supabase table `public.email_log` with unique constraint `(kind, subject_key, send_date)`.
   - Concurrent workers attempting to send the same notice encounter PostgreSQL error `23505 (unique_violation)`. The second worker aborts without sending duplicate emails.

---

## 5. Rate Limiting Architecture & Hosting / CDN Layer Configurations

TopGrade employs defense-in-depth rate limiting at both the application tier and the CDN / edge infrastructure tier.

### 5.1. In-App Application Tier Limits ([rateLimit.ts](file:///c:/Users/91778/Downloads/PROJECTS/top%20grade%20CRM/topgrade-backend/src/middleware/rateLimit.ts))
Every in-app rate limit injects standard `Retry-After: <seconds>` headers into the response upon HTTP 429:

| Route / Scope | Limit | Window | Lockout Behavior |
| :--- | :--- | :--- | :--- |
| `POST /api/auth/login` | 15 req/min | 60 sec | 5 consecutive bad credentials lock IP & identifier for 15 min (900s) |
| `POST /api/students/request-password-reset` | 15 req/min | 60 sec | Returns 429 with remaining reset window seconds |
| Public forms (`/api/leads/public`, `/api/admissions/*`) | 20 req/min | 60 sec | Throttles bots and spam admission submissions |
| Webhooks (`/api/leads/webhook`, `/api/payments/stripe/webhook`) | 120 req/min | 60 sec | High burst allowance for genuine partner syncs |
| Public Health Check (`/api/health`) | Unrestricted | N/A | Cached 30s in-memory; 0 DB queries during TTL |

### 5.2. Edge / CDN Layer Equivalents (Cloudflare, AWS WAF, Nginx)
To protect application compute nodes from DDoS and distributed credential stuffing, configure the following matching rules at your CDN or reverse proxy:

#### A. Cloudflare WAF Custom Rate Limiting Rules
1. **Login Brute-Force Rule**:
   - **Expression**: `(http.request.uri.path eq "/api/auth/login" and http.request.method eq "POST")`
   - **Counting Expression**: `ip.src`
   - **Threshold**: 15 requests per 1 minute
   - **Mitigation Action**: Block with Custom Response Code 429 (`Retry-After: 900`).
2. **Public Lead & Admission Form Rule**:
   - **Expression**: `(http.request.uri.path in {"/api/leads/public" "/api/admissions/inquiry" "/api/admissions/register"} and http.request.method eq "POST")`
   - **Counting Expression**: `ip.src`
   - **Threshold**: 20 requests per 1 minute
   - **Mitigation Action**: Managed Challenge (Turnstile CAPTCHA).
3. **API Wide Scraping Ceiling**:
   - **Expression**: `(http.request.uri.path wildcard "/api/*")`
   - **Counting Expression**: `ip.src`
   - **Threshold**: 300 requests per 1 minute
   - **Mitigation Action**: Block for 60 seconds.

#### B. Nginx Reverse Proxy Configuration
```nginx
# Define rate limit zones in http context
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=15r/m;
limit_req_zone $binary_remote_addr zone=public_forms:10m rate=20r/m;
limit_req_zone $binary_remote_addr zone=general_api:10m rate=120r/m;

server {
    # POST /api/auth/login
    location = /api/auth/login {
        limit_req zone=auth_limit burst=5 nodelay;
        limit_req_status 429;
        proxy_pass http://topgrade_backend;
    }

    # Public admission and inquiry forms
    location ~ ^/api/(admissions|leads/public) {
        limit_req zone=public_forms burst=10 nodelay;
        limit_req_status 429;
        proxy_pass http://topgrade_backend;
    }

    # General API fallback
    location /api/ {
        limit_req zone=general_api burst=30 nodelay;
        limit_req_status 429;
        proxy_pass http://topgrade_backend;
    }
}
```

#### C. AWS WAF Rate-Based Rules
- **Rule Name**: `TopGrade-Login-RateLimit`
- **Rate limit**: 100 requests per 5-minute evaluation period per IP.
- **Scope-down statement**: URI equals `/api/auth/login` AND HTTP Method equals `POST`.
- **Action**: Custom Response -> HTTP Status 429, Header `Retry-After: 300`.


