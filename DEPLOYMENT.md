# TopGrade CRM — Production Deployment Runbook & Operational Guide

This document provides complete setup, environment configuration, database seeding, webhook integration, and production build instructions for **TopGrade CRM**.

---

## 🏛️ System Architecture Overview

TopGrade CRM is a strictly internal, role-based Institution CRM consisting of:
1. **Frontend Client (`topgrade`)**: Vite + React 18 + TypeScript + TailwindCSS.
2. **Backend API Service (`topgrade-backend`)**: Node.js + Express + TypeScript.
3. **Database & Auth (`Supabase`)**: PostgreSQL database + Row Level Security (RLS) + JWT authentication.
4. **Email & Alert Engine (`Nodemailer`)**: Automated Gmail SMTP engine for admission alerts, payment receipts, and campaign broadcasts.

---

## 🔑 1. Environment Configuration Matrix

### Backend Configuration (`topgrade-backend/.env`)

```env
PORT=5000
SUPABASE_URL=https://your-supabase-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
SUPABASE_JWT_SECRET=your-supabase-jwt-secret-key
GMAIL_USER=sivareddy683970@gmail.com
GMAIL_APP_PASSWORD=your-gmail-16-char-app-password
```

### Frontend Configuration (`topgrade/.env`)

```env
VITE_SUPABASE_URL=https://your-supabase-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-key
VITE_API_BASE_URL=http://localhost:5000
```

---

## 👥 2. Role-Based Accounts Matrix (Seed Fixtures)

TopGrade CRM provides 5 default role accounts for testing and verification:

| Role | Email Credential | Default Password | Primary Portal & Capabilities |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin@topgrade.edu` | `TopGrade2026!` | Full CRM Control, Omnichannel Enquiries Hub, Admin Takeover, Campaign Dispatcher. |
| **Accountant** | `accountant@topgrade.edu` | `TopGrade2026!` | Fee Ledgers, Cheque Scanning Metadata, Line-Item Promotional Discounts, Payment Receipts. |
| **Teacher** | `teacher@topgrade.edu` | `TopGrade2026!` | Assigned Course Tracks, Weekly Capacity Progress Bar, Google Drive Link & Photo Release Waiver. |
| **Parent** | `parent@topgrade.edu` | `TopGrade2026!` | Multi-Child Account Switcher (Rahul & Ananya), Presence Rate %, Fee Receipts, Reschedule Trigger, 3 Digital Waivers Modal. |
| **Student** | `student@topgrade.edu` | `TopGrade2026!` | Personal Course Schedule, Dynamic Age (DOB-calculated), Attendance Logs, Verified Media Status. |

---

## 📥 3. Omnichannel Lead Ingestion API Specification

External marketing platforms (WhatsApp Business, Instagram Ads, Facebook Lead Ads, YouTube campaigns, and Client Websites) ingest leads directly into the Admin Enquiries Hub via public webhook.

### Endpoint: `POST /api/leads/webhook`

- **Content-Type**: `application/json`
- **Supported `source` tags**: `whatsapp`, `instagram`, `facebook`, `youtube`, `external_website`, `other`.

#### Sample cURL Request (Facebook Lead Ad):

```bash
curl -X POST http://localhost:5000/api/leads/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "source": "facebook",
    "student_name": "Vikram Malhotra",
    "father_name": "Sanjay Malhotra",
    "mother_name": "Anita Malhotra",
    "contact_number": "+919876543210",
    "email": "vikram.m@gmail.com",
    "parent_email": "sanjay.m@gmail.com",
    "academic_grade": "Secondary (Grade 9)",
    "message": "Enquiring for Coding & Software Development track starting next month via Facebook Lead Ad.",
    "campaign_id": "FB-STEM-SPRING-2026"
  }'
```

#### Successful Webhook Response (`201 Created`):

```json
{
  "success": true,
  "message": "Omnichannel lead successfully ingested and admin/parent alerts dispatched!",
  "data": {
    "id": "lead-1786617200000",
    "source": "facebook",
    "student_name": "Vikram Malhotra",
    "status": "Pending",
    "created_at": "2026-08-15T16:30:00.000Z"
  }
}
```

---

## ⚙️ 4. System Health Check & Database Seeding

- **Operational System Info**: `GET http://localhost:5000/api/crm-info`
- **Trigger Database Seed Script**: `GET http://localhost:5000/api/seed`

---

## 🛠️ 5. Production Build & Startup Commands

### Build Backend Service (`topgrade-backend`)

```bash
cd topgrade-backend
npm run build
npm start
```

### Build Frontend Web Application (`topgrade`)

```bash
cd topgrade
npm run build
npm run preview
```
