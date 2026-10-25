# TopGrade CRM — Client Live Demo Presentation Guide

Welcome to the **TopGrade Learning CRM Live Demo**. This guide provides a complete, plain-language walkthrough for demonstrating the application to stakeholders and clients.

---

## 🌐 Live Access Information

| Component | URL | Notes |
| :--- | :--- | :--- |
| **Frontend Application** | `https://topgrade-vert.vercel.app` | Hosted on Vercel |
| **Backend API Engine** | `https://topgrade-backend.onrender.com` | Hosted on Render |
| **API Health Status** | `https://topgrade-backend.onrender.com/api/health` | Public health check |

---

## 🔒 Safety Guardrails in Effect

During this demonstration, two strict safety switches are actively enforced:

1. **Email Simulation (`SIMULATE_EMAILS=true`)**:
   - **Why it is off:** Prevents real emails from accidentally being sent to parents and students imported from historical spreadsheets.
   - **How it works:** All system notifications, login links, and class notices are safely logged to the internal database (`email_log`) and can be reviewed in the **Settings → Delivery Log** tab without dispatching external SMTP traffic.
2. **Bank-Verified Reconciliation Workflow**:
   - **How it works:** Real bank CSV statements or webhooks are reconciled against pending orders. No credit cards or unverified payments are accepted. Hours are credited strictly upon admin bank reconciliation.

> [!IMPORTANT]
> **Privacy Rule:** Never log into any real imported family account during a demo. The initial login for any family forces a password change. Always use the dedicated **Demo Family** credentials detailed below.

---

## 👤 Demo Credentials

| Role | Username / Email | Initial Password | Notes |
| :--- | :--- | :--- | :--- |
| **Test Administrator** | `admin@topgrade.edu` | *(Set in `.env` as `TEST_ADMIN_PASSWORD`)* | Full administrative permissions across all tabs |
| **Demo Parent** | `demo.parent@topgradelearning.com` | `TopGradeDemo2026!` *(or `TEST_DEMO_PARENT_PASSWORD`)* | Parent of Demo Alice & Demo Bob |

---

## 📋 Step-by-Step Demo Walkthrough

Follow these steps in order for a seamless presentation:

### Step 1: Admin Sign-In & First Impression
1. Open your browser and navigate to `https://topgrade-vert.vercel.app/login`.
2. Enter the **Test Administrator** credentials (`admin@topgrade.edu`).
3. Click **Sign In**.
4. **What to highlight:**
   - Instant, secure JWT authentication.
   - Server cold-start protection: If the cloud server was idle, the UI displays *"Waking up the server, one moment..."* and automatically retries within 3 seconds rather than displaying a raw error.

---

### Step 2: Executive Dashboard & Operational Metrics
1. You land on the **Admin Dashboard**.
2. **What to highlight:**
   - **Live Counters:** Displays real active students (~64 students), registered parent accounts (~63 parents), and courses.
   - **Curriculum Distribution:** Visual breakdown of enrollments across Tutoring and Afterschool programs.
   - **Upcoming Classes & Activity Feed:** Real-time visibility into daily educational operations.

---

### Step 3: Admin System & Migration Verification
1. Click **Settings** in the left navigation sidebar.
2. Click the **System check** tab on the sub-navigation bar.
3. **What to highlight:**
   - **Isolated Supabase Host:** Demonstrates that the application is running against the new dedicated database, with an automatic safety block if any legacy host is referenced.
   - **Schema Integrity:** Green verification status across all 12 core tables (`profiles`, `students`, `courses`, `schedules`, `locations`, `attendance`, `token_wallets`, etc.).
   - **Safety Mode Badges:** Visual confirmation that `SIMULATE_EMAILS` is active.
   - **Migration Readiness Counts:** Shows the exact number of parent and student accounts awaiting their initial secure sign-in.

---

### Step 4: Data Quality & "Needs Attention" Audit
1. Click **Needs Attention** in the left sidebar.
2. **What to highlight:**
   - Proactive administrative auditing: Raw historical spreadsheets frequently contain missing data or missing emails.
   - TopGrade CRM automatically categorizes rows with missing parent emails (flagged with placeholder domains) or incomplete dates of birth/grades.
   - One-click admin actions to dispatch secure invite links or update contact information once confirmed by parents.

---

### Step 5: Student Directory & Smart Filtering
1. Click **Students** in the left sidebar.
2. **What to highlight:**
   - Live search by student name, student ID code, or parent phone.
   - Program filters: Toggle between **All Programs**, **Tutoring**, and **Afterschool**.
   - Search for `Demo Alice` and click her card to open the **Student Dossier**:
     - View enrolled subjects (*Demo Math Enrichment*).
     - View token hours wallet (showing 17 hours remaining out of 20 purchased).
     - View complete attendance history.

---

### Step 6: Schedules & Managed Locations
1. Click **Schedule** in the left sidebar.
2. **What to highlight:**
   - Multi-location scheduling supporting both central learning centers and partner school campuses.
   - Locate the slot at **Demo Heritage Elementary School** (Mondays 4:00 PM – 5:30 PM).
   - Demonstrate student roster mapping and classroom capacity limits.

---

### Step 7: Attendance & Daily Roll Call
1. Click **Attendance** in the left sidebar.
2. View the recent session logs.
3. **What to highlight:**
   - Teachers and admins can record attendance by class session.
   - Three sessions have been recorded for Demo Alice (*2026-10-12, 2026-10-14, 2026-10-16*), each seamlessly deducting one class credit from her token balance.

---

### Step 8: Parent Portal Experience & Strict Data Privacy
1. Open a **new Private / Incognito browser window**.
2. Navigate to `https://topgrade-vert.vercel.app/login`.
3. Sign in as `demo.parent@topgradelearning.com`.
4. **What to highlight:**
   - **Mandatory First Sign-In Password Change:** The client sees the forced password update screen ensuring parent accounts are protected from day one.
   - **Family Isolation (Row Level Security):** Once logged in, the Demo Parent sees **ONLY** their two children (*Demo Alice* and *Demo Bob*).
   - The parent can view attendance marks, upcoming sessions, and token balances for their own children, but has zero visibility into any other family's records.

---

## 🛠️ Demo Family Management (Seed & Cleanup)

To create or reset the demo family records, run the following commands in `topgrade-backend/`:

```bash
# Seed the demo family (dry-run preview):
npm run demo:seed

# Seed the demo family (apply to database):
npm run demo:seed -- --apply

# Remove all demo family records cleanly:
npm run demo:remove
```

All demo records use the prefix `Demo ` for easy identification and complete cleanup.

---

## 🔍 Known Gaps & Future Enhancements

1. **Automated Fee Overdue Alerts:** Scheduled for Milestone 2 after fee plan customization is finalized.
2. **One-Click Invoices:** PDF invoice generation is currently available on request; automated monthly invoicing will be rolled out post-demo.
3. **Historical Student Cleanup:** Certain students imported from legacy spreadsheets lack grade, last name, or date of birth; these are tracked on the **Needs Attention** dashboard awaiting manual verification.
