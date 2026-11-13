# TOPGRADE CRM: DATA FLOW & ARCHITECTURE INVENTORY
**Document Version:** 1.0.0 (TASK 19 - Part A)  
**Date:** 2026-11-14  
**Target Environment:** Local Stack / Synthetic Data Only (`America/Chicago` CT)  

---

## 1. Table Inventory & Source-of-Truth Consolidation

### 1.1 Table Usage Counts Across Codebase

A complete static scan of the codebase (`topgrade-backend/src` and `topgrade/src`) was executed to identify all database table references:

| Conceptual Domain | Table Name | Backend References | Backend Files | Frontend References | Frontend Files | Canonical Status |
|---|---|---|---|---|---|---|
| **Schedule Slots** | `schedule_slots` | 43 | 11 | 1 | 1 | **PRIMARY (Keep)** |
| | `schedules` | 121 | 34 | 80 | 18 | *DEPRECATED (Migrate & Drop)* |
| **Enrollments / Bookings** | `student_enrollments` | 57 | 17 | 1 | 1 | **PRIMARY (Keep)** |
| | `schedule_students` | 50 | 14 | 1 | 1 | *DEPRECATED (Migrate & Drop)* |
| | `bookings` | 38 | 9 | 5 | 4 | *DEPRECATED (Merge into enrollments)* |
| **Hours / Wallets** | `token_wallets` | 27 | 15 | 0 | 0 | **PRIMARY (Keep)** |
| | `hour_wallets` | 2 | 1 | 1 | 1 | *DEPRECATED (Phantom/Unused)* |
| **Hours / Ledger** | `token_ledger` | 36 | 11 | 0 | 0 | **PRIMARY (Keep)** |
| | `hour_ledger` | 1 | 1 | 0 | 0 | *DEPRECATED (Phantom/Unused)* |
| **Attendance** | `attendance` | 267 | 42 | 124 | 26 | **PRIMARY (Keep)** |
| **Announcements** | `announcements` | 18 | 9 | 6 | 4 | **PRIMARY (Keep)** |
| | `announcement_deliveries` | 4 | 2 | 0 | 0 | **PRIMARY (Keep - audit child)** |
| **Emails & Notifications** | `email_log` | 49 | 14 | 3 | 1 | **PRIMARY (Keep)** |
| | `email_logs` | 2 | 2 | 0 | 0 | *DEPRECATED (Typo alias)* |

---

### 1.2 Conceptual Duplicates & Selection of Single Source of Truth

#### 1. Schedule Slots: `schedule_slots` vs `schedules`
- **Issue:** Legacy code defined `schedules` (storing strings like `day_of_week: 'Monday'`, `time_slot: '10:00 AM - 11:30 AM'`). Task 18 introduced `schedule_slots` with real UTC timestamp ranges (`start_at`, `end_at`), `duration_hours` (1 to 4 whole hours), `max_students`, and exclusion constraints (`no_teacher_slot_overlap`).
- **Decision:** Select **`schedule_slots`** as the single source of truth for schedule definitions. All `schedules` read/write paths are consolidated into `schedule_slots`.

#### 2. Student Enrollments: `student_enrollments` vs `schedule_students` vs `bookings`
- **Issue:** 
  - `student_enrollments` stores high-level course/plan enrollments (`student_id`, `course_id`, `status: ACTIVE | PAUSED_NO_HOURS | ENDED`, `plan: PACKAGE | HOURS`).
  - `schedule_students` mapped a student to a schedule slot id.
  - `bookings` mapped `student_id` to `slot_id` with `tokens_reserved`.
- **Decision:** Consolidate into a unified enrollment relation. **`student_enrollments`** links student to course and slot, tracking status (`ACTIVE`, `PAUSED_NO_HOURS`, `ENDED`), enrollment date, and paused timestamp. `schedule_students` and `bookings` tables are merged and dropped.

#### 3. Student Hours: `token_wallets` & `token_ledger` vs `hour_wallets` & `hour_ledger`
- **Issue:** `hour_wallets` and `hour_ledger` were referenced only in student deletion scripts and never had SQL migration definitions. In contrast, `token_wallets` and `token_ledger` are fully implemented in migrations, backed by transactional RPC functions (`token_apply`, `get_available_tokens`), and enforce strict append-only double-entry accounting (1 token = 1 hour).
- **Decision:** Standardize on **`token_wallets`** and **`token_ledger`**. Remove all dangling references to `hour_wallets` and `hour_ledger`.

#### 4. Attendance: `attendance`
- **Single Source:** `attendance` is already the universal table across backend and frontend, written strictly via `markAttendance` / `mark_attendance`.

---

## 2. Module Data Flow Matrix (Read/Write, Endpoints, and 4-Role UI)

| Module | Reads From | Writes To | Backend Endpoints | Admin Screen | Teacher Screen | Parent Screen | Student Screen |
|---|---|---|---|---|---|---|---|
| **Courses** | `courses`, `course_packages` | `courses`, `course_packages` | `GET /api/courses`, `POST /api/courses/create`, `PUT /api/courses/update/:id`, `PATCH /api/courses/archive/:id` | Full catalog, Add/Edit/Archive modal, Fee structure, read-only slot/capacity view | Read-only catalog of active & assigned courses | Catalog view (pricing display only, payments on hold) | Enrolled and available courses catalog |
| **Schedule** | `schedule_slots`, `courses`, `teachers`, `locations` | `schedule_slots`, `teacher_slot_claims` | `GET /api/schedules/list`, `POST /api/schedules/create`, `PUT /api/schedules/edit/:id`, `DELETE /api/schedules/:id`, `POST /api/schedules/:id/claim` | Grid & Calendar view, Add/Edit Slot modal (whole hours 1–4, collision check), Claim review | Timetable of assigned classes, Open slots claim list | Schedule timetable for enrolled children | Personal weekly timetable |
| **Enrollment** | `student_enrollments`, `schedule_slots`, `token_wallets` | `student_enrollments`, `schedule_slots` | `POST /api/schedules/book`, `POST /api/schedules/:id/enroll-students`, `POST /api/schedules/cancel-booking` | Slot student roster, Enroll drawer (grade check, hour balance check), Needs hours list | Live session roll (ACTIVE students only) | Children enrollments list, Request enrollment | Self enrolled classes and status |
| **Attendance** | `attendance`, `schedule_slots`, `students` | `attendance`, `token_ledger` | `POST /api/attendance/mark`, `GET /api/attendance/session/:slotId/:date`, `GET /api/attendance/student/:id` | Attendance dashboard, audit corrections, history reports | Daily attendance roll (Present/Absent/Late/Excused) | Real-time children attendance timeline | Personal attendance record |
| **Hours** | `token_wallets`, `token_ledger` | `token_wallets`, `token_ledger` | `GET /api/tokens/student/:id/balance`, `GET /api/tokens/student/:id/ledger`, `POST /api/tokens/grant` | Wallets overview, Manual credit modal, Ledger reconciliation check | Session roster remaining hours badge | Children wallet balance per course & ledger | Self balance per course & recent transactions |
| **Students** | `students`, `student_dossiers`, `profiles` | `students`, `student_dossiers`, `profiles` | `GET /api/students/list`, `GET /api/students/:id`, `POST /api/students/create`, `PUT /api/students/update/:id`, `DELETE /api/students/:id` | Students directory, Dossier modal, Add/Edit/Archive (type-to-confirm) | Students directory in assigned classes | My Children dossiers | My Profile (read-only) |
| **Teachers** | `teachers`, `teacher_availability`, `profiles` | `teachers`, `teacher_availability`, `profiles` | `GET /api/teachers/list`, `POST /api/teachers/create`, `PUT /api/teachers/update/:id`, `DELETE /api/teachers/:id` | Teachers directory, Add/Edit/Archive, Availability manager | Teacher profile, availability editor | Read-only teacher names & subjects | Teacher contact info for courses |
| **Dashboards** | Aggregates from slots, attendance, wallets, students | None (Read-only) | `GET /api/dashboard/summary`, `GET /api/dashboard/teacher`, `GET /api/dashboard/parent`, `GET /api/dashboard/student` | Honest zero metrics, total students/teachers, low balance alerts | Today's schedule, quick-mark roll, open slots | Enrolled kids, next session, wallet balances | Next class card, hours remaining |
| **Reports** | `attendance`, `token_ledger`, `schedule_slots`, `courses` | None (Read-only) | `GET /api/reports/attendance`, `GET /api/reports/hours-utilization` | Multi-filter reports, attendance rate, hours ledger audit | Class attendance history | Child attendance history | Self attendance record |
| **Announcements**| `announcements`, `announcement_deliveries`, `settings` | `announcements`, `announcement_deliveries`, `email_log` | `GET /api/announcements`, `POST /api/announcements/create`, `POST /api/announcements/send-test` | Composer with address banner check, audience filter, delivery log | Notification bell & announcements banner | Notification bell & announcements banner | Notification bell & announcements banner |
| **Emails** | `email_log`, `settings` | `email_log` | `GET /api/email-logs`, `POST /api/email-logs/retry/:id`, `GET /api/email-logs/diagnostics` | Delivery audit log (sent, failed, queued), email diagnostics panel | None | None | None |
| **History** | `student_history`, `audit_logs`, `token_ledger` | `student_history`, `audit_logs` | `GET /api/history/student/:id`, `GET /api/history/system` | Full student activity audit log, system audit log | Class activity log | Child event timeline | Self activity timeline |

---

## 3. Server-Side Caches and Frontend Mount-Only Data Loads

### 3.1 Backend In-Memory Caches & Timers (To Be Removed / Handled in Part B)

1. **`studentService.ts`**:
   - `inMemoryStudentStore`: Array storing full student objects in RAM.
   - `lastSupabaseStudentFetch`: Timestamp checking 30s TTL.
   - `cachedStudentScheduleInfo`: Map of student ID to sets of courses, categories, teachers, weekdays.
   - `cachedCourseCategoryMap`, `cachedWalletMap`, `cachedAttendanceCountMap`: Aux Maps.
   - *Action in Part B:* Eliminate all in-memory arrays and maps; read directly from Supabase on every request.

2. **`scheduleDataService.ts`**:
   - `inMemorySchedules = new Map<string, ScheduleSlot>()`: Memory map fallback.
   - `inMemoryReschedules`: Record tracking reschedule counts.
   - *Action in Part B:* Remove in-memory fallback; execute all queries directly against `schedule_slots`.

3. **`enrollments.ts`**:
   - `inMemoryJoinRequests = new Map<string, any>()`: In-memory join requests.
   - *Action in Part B:* Persist join requests to Supabase or replace with transactional enrollment.

4. **`monthlyNotes.ts`**:
   - `inMemoryNotes = new Map<string, ...>()`: In-memory teacher notes.
   - *Action in Part B:* Persist to database table or dossier notes.

5. **`instituteSettingsService.ts` (Keep as Allowed Exception)**:
   - Institute settings cache (`cachedSettings`) with 60-second TTL.
   - *Action in Part B:* Invalidate cache immediately on every `PUT /api/settings` update so updates reflect with zero latency.

---

### 3.2 Frontend Mount-Only Single Loads (To Be Replaced with `useLiveQuery` in Part D)

1. `topgrade/src/pages/Dashboard/Dashboard.tsx` (`useEffect(() => { loadDashboardData(); }, [])`)
2. `topgrade/src/pages/Dashboard/TeacherDashboard.tsx` (`useEffect(() => { loadTeacherData(); }, [])`)
3. `topgrade/src/pages/Dashboard/ParentDashboard.tsx` (`useEffect(() => { loadParentData(); }, [])`)
4. `topgrade/src/pages/Dashboard/StudentDashboard.tsx` (`useEffect(() => { loadStudentData(); }, [])`)
5. `topgrade/src/pages/Courses/Courses.tsx` (`useEffect(() => { loadAllData(); }, [])`)
6. `topgrade/src/pages/Schedule/Schedule.tsx` (`useEffect(() => { loadSlots(); }, [])`)
7. `topgrade/src/pages/Attendance/Attendance.tsx` & `DailyClassAttendanceView.tsx` (`useEffect(() => { loadRoll(); }, [])`)
8. `topgrade/src/pages/Fees/Fees.tsx` & `TokenPaymentsPanel.tsx` (`useEffect(() => { loadWallets(); }, [])`)
9. `topgrade/src/pages/Alerts/Alerts.tsx` (`useEffect(() => { loadAnnouncements(); }, [])`)
10. `topgrade/src/pages/History/History.tsx` (`useEffect(() => { loadTimeline(); }, [])`)

---

## 4. Comprehensive Email Pipeline Catalog

Every email dispatched in the application passes through `dispatchMultiChannelNotification` and is claimed idempotently in `email_log`:

| Event Kind | Trigger Condition | Intended Recipients | Email Subject & Template Summary | Unsubscribe / Address Required |
|---|---|---|---|---|
| `ACCOUNT_INVITATION` | Admin creates user or triggers invite | Student / Parent / Teacher | "Welcome to TopGrade Learning" - login link and credentials | No (Transactional) |
| `PASSWORD_RESET` | User requests reset or admin triggers reset | User email | "Reset Your TopGrade Password" - secure reset link | No (Transactional) |
| `CLASS_SCHEDULE` | Student enrolled in a schedule slot | Student & Parent | "Class Schedule Confirmed: {Course}" - weekday, time CT, room, teacher | Yes |
| `SLOT_UPDATED` | Admin modifies slot weekday, time, or duration | Enrolled Students & Parents | "Important Schedule Update: {Course}" - old vs new time | Yes |
| `SLOT_CANCELLED` | Admin cancels slot or individual session | Enrolled Students & Parents | "Class Cancelled: {Course}" - date, 0 hours deducted | Yes |
| `ATTENDANCE_ALERT` | Teacher marks student attendance | Parent | "Attendance Update: {Student} marked {Status}" - session date, time | Yes |
| `HOURS_EXHAUSTED` | Student balance falls below class duration (`PAUSED_NO_HOURS`) | Parent & Student | "Notice: Course Hours Used Up for {Course}" - instructions to add hours | Yes |
| `HOURS_CREDITED` | Admin credits hours to course wallet | Parent & Student | "Hours Credited: {Course}" - credited amount, new balance | Yes |
| `LOW_BALANCE_WARNING` | Balance is low (<= threshold) | Parent & Student | "Low Hours Balance: {Course}" - remaining class sessions | Yes |
| `ANNOUNCEMENT_BROADCAST` | Admin publishes announcement | Targeted audience (Roles / Courses) | "{Title}" - Body text, physical postal address in footer, unsubscribe link | **MANDATORY** |
| `TEACHER_CLAIM_NOTIFY`| Teacher claims open slot | Admin | "Teacher Claim: {Teacher} claimed slot {Course}" | No (Internal) |
| `BIRTHDAY_WISHES` | Scheduled daily cron at 09:00 CT | Student & Parent | "Happy Birthday from TopGrade Learning!" | Yes |
| `PAYMENT_RECEIPT` | Payment recorded (Zelle/Stripe/Cash) | Payer email | "Payment Receipt #{OrderNumber}" - attached PDF receipt | No (Transactional) |
