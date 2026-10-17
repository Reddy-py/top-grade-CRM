-- ============================================================================
-- Migration: 20261019_email_templates_and_automation.sql
-- Goal:
-- 1. Table email_templates for all 12 events with editable body, subject, audience, enabled toggle.
-- 2. Enhance email_log with retry_count, next_retry_at, body_preview, metadata, and RLS privacy.
-- 3. Table email_unsubscribes for CAN-SPAM compliant one-click unsubscribe links.
-- 4. Table student_monthly_notes for teacher monthly progress notes per student per course.
-- Safe to run multiple times (idempotent).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Table: email_templates
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.email_templates (
    key TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    audience TEXT NOT NULL, -- 'PARENTS', 'STUDENTS', 'STUDENT_ELSE_PARENT', 'TEACHERS', 'ADMIN', 'ALL'
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    updated_by TEXT DEFAULT 'system',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Seed default templates for all 12 events
INSERT INTO public.email_templates (key, name, audience, subject, body, enabled)
VALUES
(
    'NEW_STUDENT_PARENT_SET_PASSWORD',
    '1a. New Student: Parent Account Creation',
    'PARENTS',
    'Welcome to Top Grade Learning: Set Up Your Parent Portal Password',
    'Dear {{parent_name}},<br><br>Welcome to <strong>{{institute_name}}</strong>! We have created your official Parent Portal account for <strong>{{student_name}}</strong> (Student Code: <code>{{student_code}}</code>).<br><br>Please use the secure link below to set your password. This link is single-use and will expire:<br><p><a href="{{action_url}}" style="display:inline-block;padding:10px 20px;background:#004ac6;color:#ffffff;text-decoration:none;border-radius:6px;font-weight:bold;">Set Your Password &rarr;</a></p><br>Login Email: <code>{{email}}</code><br><br>Through the Parent Portal, you can track daily attendance, view class schedules, monitor enrolled courses, and manage academic progress.<br><br>Warm regards,<br>{{institute_name}} Administration',
    true
),
(
    'NEW_STUDENT_STUDENT_SET_PASSWORD',
    '1b. New Student: Student Account Creation',
    'STUDENTS',
    'Welcome to Top Grade Learning: Set Up Your Student Portal Password',
    'Dear {{student_name}},<br><br>Welcome to <strong>{{institute_name}}</strong>! Your student portal account has been created.<br><br>Please choose your password using this secure link:<br><p><a href="{{action_url}}" style="display:inline-block;padding:10px 20px;background:#004ac6;color:#ffffff;text-decoration:none;border-radius:6px;font-weight:bold;">Set Your Student Password &rarr;</a></p><br>Student Code: <code>{{student_code}}</code><br>Login Email: <code>{{email}}</code><br><br>Best wishes for your academic journey,<br>{{institute_name}}',
    true
),
(
    'NEW_STUDENT_REGISTRATION_SUMMARY',
    '1c. New Student: Registration Summary',
    'STUDENT_ELSE_PARENT',
    'Registration Confirmation: {{student_name}} ({{student_code}})',
    'Dear {{recipient_name}},<br><br>We are pleased to confirm that <strong>{{student_name}}</strong> has been successfully registered at <strong>{{institute_name}}</strong>.<br><br><strong>Registration Details:</strong><br>&bull; Student Code: <code>{{student_code}}</code><br>&bull; School: {{school}}<br>&bull; Grade: {{grade}}<br>&bull; Program: {{program}}<br>&bull; Enrolled Courses: {{courses}}<br><br>If you need any adjustments or have questions, please reply to this email.<br><br>Warm regards,<br>{{institute_name}} Team',
    true
),
(
    'NEW_STUDENT_ADMIN_ALERT',
    '1d. New Student: Admin Summary Notification',
    'ADMIN',
    'New Student Registered: {{student_name}} ({{student_code}})',
    'Hello Admin,<br><br>A new student profile has been created:<br><br>&bull; Name: <strong>{{student_name}}</strong><br>&bull; Code: <code>{{student_code}}</code><br>&bull; School: {{school}}<br>&bull; Grade: {{grade}}<br>&bull; Program Type: {{program_type}}<br>&bull; Parent Emails: {{parent_emails}}<br>&bull; Student Email: {{student_email}}<br>&bull; Enrolled Courses: {{courses}}<br>&bull; Registered At: {{created_at}}<br><br>Review the full profile in the Administrative Portal.',
    true
),
(
    'STUDENT_DETAILS_UPDATED',
    '2. Student Details Updated',
    'STUDENT_ELSE_PARENT',
    'Profile Update Notice: {{student_name}}',
    'Dear {{recipient_name}},<br><br>This is an automated notification that the academic profile for <strong>{{student_name}}</strong> ({{student_code}}) at <strong>{{institute_name}}</strong> was recently updated.<br><br><strong>Changes recorded:</strong><br>{{changes_list}}<br><br>If you did not request or expect these changes, please contact the institute office immediately.<br><br>Warm regards,<br>{{institute_name}}',
    true
),
(
    'CLASS_SCHEDULE_EVENT',
    '3. Class Created, Rescheduled, or Cancelled',
    'STUDENT_ELSE_PARENT',
    'Class Update: {{course_name}} &mdash; {{action_type}}',
    'Dear {{recipient_name}},<br><br>There is an update to your scheduled class for <strong>{{course_name}}</strong> at <strong>{{institute_name}}</strong>.<br><br><strong>Event:</strong> {{action_type}}<br>&bull; Course: {{course_name}}<br>&bull; Day: {{day_of_week}}<br>&bull; Time Slot: {{time_slot}}<br>&bull; Classroom / Room: {{room}}<br>&bull; Location: {{location_name}} ({{location_address}})<br>&bull; Faculty Instructor: {{teacher_name}}<br><br>{{additional_notes}}<br><br>Please verify your updated schedule in the portal.<br><br>Warm regards,<br>{{institute_name}} Academic Operations',
    true
),
(
    'CLASS_REMINDER_24H',
    '4a. Class Reminder (24 Hours Prior)',
    'STUDENT_ELSE_PARENT',
    'Reminder: {{course_name}} Tomorrow at {{start_time}}',
    'Hello {{recipient_name}},<br><br>This is a friendly reminder that <strong>{{student_name}}</strong> has a scheduled class tomorrow:<br><br>&bull; Course: <strong>{{course_name}}</strong><br>&bull; Date: Tomorrow, {{class_date}}<br>&bull; Time: {{start_time}} - {{end_time}}<br>&bull; Location: {{location_name}} ({{location_address}})<br>&bull; Room: {{room}}<br>&bull; Instructor: {{teacher_name}}<br><br>Please ensure prompt arrival 5&ndash;10 minutes before session start.<br><br>Warm regards,<br>{{institute_name}}',
    true
),
(
    'TEACHER_DAILY_AGENDA',
    '4b. Teacher Daily Class Agenda (Morning)',
    'TEACHERS',
    'Today''s Teaching Schedule: {{today_date}} ({{classes_count}} Classes)',
    'Good morning {{teacher_name}},<br><br>Here is your teaching schedule for today, <strong>{{today_date}}</strong>:<br><br>{{classes_summary}}<br><br>Please remember to mark attendance roll-call promptly at the conclusion of each session in your Faculty Portal.<br><br>Have a wonderful teaching day!<br>{{institute_name}}',
    true
),
(
    'ATTENDANCE_DAILY_SUMMARY',
    '5a. Daily Attendance Roll-Call Notice',
    'PARENTS',
    'Attendance Notice: {{student_name}} &mdash; {{status}} ({{course_name}})',
    'Dear {{parent_name}},<br><br>This is your daily attendance update for <strong>{{student_name}}</strong>:<br><br>&bull; Session: <strong>{{course_name}}</strong><br>&bull; Date: {{attendance_date}}<br>&bull; Status: <strong>{{status}}</strong><br>&bull; Faculty: {{teacher_name}}<br>{{remarks_block}}<br>Overall Attendance in this course: <strong>{{attendance_percent}}%</strong>.<br><br>View full attendance records anytime in the Parent Portal.<br><br>Warm regards,<br>{{institute_name}}',
    true
),
(
    'ATTENDANCE_MONTHLY_SUMMARY',
    '5b. Monthly Attendance Report',
    'PARENTS',
    'Monthly Attendance Report: {{student_name}} ({{month_name}})',
    'Dear {{parent_name}},<br><br>Here is the monthly attendance summary for <strong>{{student_name}}</strong> for <strong>{{month_name}}</strong>:<br><br>&bull; Course: {{course_name}}<br>&bull; Total Conducted Classes: {{total_conducted}}<br>&bull; Classes Attended: {{total_attended}}<br>&bull; Monthly Attendance Rate: <strong>{{attendance_percent}}%</strong><br>&bull; Evaluation: {{attendance_evaluation}}<br><br>Thank you for partnering with us in your child''s academic progress.<br><br>Warm regards,<br>{{institute_name}}',
    true
),
(
    'LOW_HOURS_ALERT',
    '6. Low Hours or Hours Owed Notice',
    'PARENTS',
    'Important Notice: Class Hours Update for {{student_name}} ({{course_name}})',
    'Dear {{parent_name}},<br><br>This is an automated balance notice regarding <strong>{{student_name}}</strong> in <strong>{{course_name}}</strong>:<br><br><strong>Current Balance: {{hours_balance}} class hours remaining</strong><br><br>{{balance_message}}<br><br>Please sign in to the portal or contact the institute office to replenish class hours.<br><br>Warm regards,<br>{{institute_name}} Academic Accounts',
    true
),
(
    'PACKAGE_EXPIRY_NOTICE',
    '7. Course Package Expiry / Expired Notice',
    'PARENTS',
    'Course Package Notice: {{student_name}} &mdash; {{course_name}} ({{expiry_status}})',
    'Dear {{parent_name}},<br><br>This notice concerns the course package enrollment for <strong>{{student_name}}</strong> in <strong>{{course_name}}</strong>:<br><br>&bull; Plan: {{plan}}<br>&bull; Package Expiry Date: <strong>{{expires_on}}</strong><br>&bull; Status: <strong>{{expiry_status}}</strong><br>&bull; Remaining Unused Hours: {{unused_hours}} hours<br><br>{{action_guidance}}<br><br>Warm regards,<br>{{institute_name}} Enrollment Services',
    true
),
(
    'STUDENT_BIRTHDAY_GREETING',
    '8a. Student Birthday Greeting',
    'STUDENT_ELSE_PARENT',
    '🎂 Happy Birthday, {{student_name}}! Warmest Wishes from Top Grade Learning',
    '<div style="text-align:center;padding:20px 0;"><span style="font-size:40px;">🎂 🎈 🎁</span><h2 style="color:#004ac6;margin:10px 0;">Happy Birthday, {{student_name}}!</h2></div>Dear {{recipient_name}},<br><br>On this special day, your teachers and the entire leadership team at <strong>{{institute_name}}</strong> wish you a fantastic birthday!<br><br>May your upcoming year be filled with exciting learning milestones, creativity, and great success in all your academic endeavors.<br><br>Enjoy your celebration!<br><br>Warmest regards,<br>{{institute_name}} Family',
    true
),
(
    'TEACHER_BIRTHDAY_GREETING',
    '8b. Teacher Birthday Greeting',
    'TEACHERS',
    '🎉 Happy Birthday, {{teacher_name}}! From Top Grade Learning',
    '<div style="text-align:center;padding:20px 0;"><span style="font-size:40px;">🌟 🎂 🎓</span><h2 style="color:#004ac6;margin:10px 0;">Happy Birthday, {{teacher_name}}!</h2></div>Dear {{teacher_name}},<br><br>On behalf of the entire administration, staff, and students at <strong>{{institute_name}}</strong>, we want to wish you a very happy birthday!<br><br>Thank you for your tireless dedication, passion for teaching, and the wonderful mentorship you provide to every student.<br><br>With deep gratitude and appreciation,<br>{{institute_name}} Leadership',
    true
),
(
    'TEACHER_ASSIGNMENT_EVENT',
    '9. Teacher Assignment, Claim or Schedule Change',
    'TEACHERS',
    'Faculty Assignment: {{course_name}} &mdash; {{event_type}}',
    'Dear {{teacher_name}},<br><br>An update has been made to your faculty teaching schedule:<br><br>&bull; Event: <strong>{{event_type}}</strong><br>&bull; Course: {{course_name}}<br>&bull; Day & Time: Every {{day_of_week}}, {{time_slot}}<br>&bull; Location: {{location_name}} ({{location_address}})<br>&bull; Room: {{room}}<br>&bull; Enrolled Students: {{enrolled_count}} students<br><br>Please check your Faculty Schedule Hub for full details.<br><br>Warm regards,<br>{{institute_name}} Faculty Office',
    true
),
(
    'MONTHLY_PROGRESS_REPORT',
    '10. Monthly Student Academic Progress Update',
    'PARENTS',
    'Monthly Academic Progress Report: {{student_name}} ({{month_name}})',
    'Dear {{parent_name}},<br><br>We are pleased to share the monthly progress update for <strong>{{student_name}}</strong> for <strong>{{month_name}}</strong> at <strong>{{institute_name}}</strong>:<br><br><strong>Course: {{course_name}}</strong><br>&bull; Attendance Rate: <strong>{{attendance_percent}}%</strong><br>&bull; Class Hours Used This Month: {{hours_used}} hours<br>&bull; Remaining Available Hours: <strong>{{hours_left}} hours</strong><br><br><strong>Instructor Progress Remarks:</strong><br><div style="background:#f8fafc;border-left:4px solid #004ac6;padding:12px 16px;margin:12px 0;font-style:italic;">"{{teacher_notes}}"</div><br>Faculty Instructor: {{teacher_name}}<br><br>Thank you for partnering with us in {{student_name}}''s educational excellence!<br><br>Warm regards,<br>{{institute_name}} Academic Directorate',
    true
),
(
    'GENERAL_ANNOUNCEMENT',
    '11. Institutional Announcement Broadcast',
    'ALL',
    'Announcement from Top Grade Learning: {{announcement_title}}',
    'Dear {{recipient_name}},<br><br>Please find an official announcement from <strong>{{institute_name}}</strong>:<br><br><div style="background:#ffffff;padding:18px;border:1px solid #e2e8f0;border-radius:10px;margin:15px 0;line-height:1.7;">{{announcement_body}}</div><br>For any questions or support, please reply to this email or reach us at {{support_email}}.<br><br>Warm regards,<br>{{institute_name}} Administration',
    true
),
(
    'ADMIN_DAILY_DIGEST',
    '12. Administrator Morning Daily Digest (8:00 AM)',
    'ADMIN',
    'TopGrade Daily Operations Digest &mdash; {{digest_date}}',
    'Good morning Admin,<br><br>Here is your daily operational summary for <strong>{{digest_date}}</strong> at <strong>{{institute_name}}</strong>:<br><br><strong>1. New Student Registrations (Last 24h):</strong><br>{{new_students_summary}}<br><br><strong>2. Yesterday''s Absences:</strong><br>{{absences_summary}}<br><br><strong>3. Low Quota & Hours Owed Accounts:</strong><br>{{low_hours_summary}}<br><br><strong>4. Packages Expiring (Next 7 Days) / Expired:</strong><br>{{packages_summary}}<br><br><strong>5. Failed Email Deliveries:</strong><br>{{failed_emails_summary}}<br><br>Have a productive day overseeing operations!<br>{{institute_name}} Automated Engine',
    true
)
ON CONFLICT (key) DO NOTHING;

-- Enable RLS on email_templates
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all_email_templates" ON public.email_templates;
CREATE POLICY "admin_all_email_templates" ON public.email_templates
    FOR ALL USING (public.get_current_user_role() = 'ADMIN');

-- ---------------------------------------------------------------------------
-- 2. Enhance email_log with retry tracking, body snippet, metadata, and role privacy
-- ---------------------------------------------------------------------------
ALTER TABLE public.email_log ADD COLUMN IF NOT EXISTS retry_count INT NOT NULL DEFAULT 0;
ALTER TABLE public.email_log ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE public.email_log ADD COLUMN IF NOT EXISTS body_preview TEXT DEFAULT '';
ALTER TABLE public.email_log ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Indices for retry scanner and performance
CREATE INDEX IF NOT EXISTS idx_email_log_status ON public.email_log(status);
CREATE INDEX IF NOT EXISTS idx_email_log_retries ON public.email_log(status, retry_count, next_retry_at) WHERE status = 'failed';

-- RLS Privacy: Nobody can read another family's emails in the log.
-- Admin can view all. Students, parents, teachers see ONLY rows where their own email is in recipients.
ALTER TABLE public.email_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all_email_log" ON public.email_log;
CREATE POLICY "admin_all_email_log" ON public.email_log
    FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "users_read_own_email_logs" ON public.email_log;
CREATE POLICY "users_read_own_email_logs" ON public.email_log
    FOR SELECT USING (
        auth.role() = 'authenticated'
        AND lower(COALESCE(auth.jwt() ->> 'email', '')) = ANY (
            SELECT lower(r) FROM unnest(email_log.recipients) AS r
        )
    );

-- ---------------------------------------------------------------------------
-- 3. Table: email_unsubscribes (CAN-SPAM compliance)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.email_unsubscribes (
    id TEXT PRIMARY KEY DEFAULT ('unsub-' || floor(extract(epoch from now()) * 1000)::bigint || '-' || substr(md5(random()::text), 1, 6)),
    email TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL DEFAULT 'ANNOUNCEMENTS',
    unsubscribed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT unique_email_category UNIQUE (email, category)
);

CREATE INDEX IF NOT EXISTS idx_email_unsubscribes_email ON public.email_unsubscribes(email);
CREATE INDEX IF NOT EXISTS idx_email_unsubscribes_token ON public.email_unsubscribes(token);

ALTER TABLE public.email_unsubscribes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all_unsubscribes" ON public.email_unsubscribes;
CREATE POLICY "admin_all_unsubscribes" ON public.email_unsubscribes
    FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "public_read_by_token" ON public.email_unsubscribes;
CREATE POLICY "public_read_by_token" ON public.email_unsubscribes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_insert_update_unsubscribes" ON public.email_unsubscribes;
CREATE POLICY "public_insert_update_unsubscribes" ON public.email_unsubscribes
    FOR INSERT WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 4. Table: student_monthly_notes (Teacher monthly progress notes per student)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_monthly_notes (
    id TEXT PRIMARY KEY DEFAULT ('note-' || floor(extract(epoch from now()) * 1000)::bigint || '-' || substr(md5(random()::text), 1, 6)),
    student_id TEXT NOT NULL,
    course_id TEXT NOT NULL,
    month TEXT NOT NULL, -- e.g. '2026-10'
    teacher_id TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    CONSTRAINT unique_student_course_month UNIQUE (student_id, course_id, month)
);

CREATE INDEX IF NOT EXISTS idx_student_monthly_notes_student ON public.student_monthly_notes(student_id);
CREATE INDEX IF NOT EXISTS idx_student_monthly_notes_course ON public.student_monthly_notes(course_id);
CREATE INDEX IF NOT EXISTS idx_student_monthly_notes_month ON public.student_monthly_notes(month);

ALTER TABLE public.student_monthly_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_all_student_monthly_notes" ON public.student_monthly_notes;
CREATE POLICY "admin_all_student_monthly_notes" ON public.student_monthly_notes
    FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "teachers_manage_student_monthly_notes" ON public.student_monthly_notes;
CREATE POLICY "teachers_manage_student_monthly_notes" ON public.student_monthly_notes
    FOR ALL USING (
        public.get_current_user_role() = 'TEACHER'
        AND EXISTS (
            SELECT 1 FROM public.teachers t
            WHERE (t.user_id = auth.uid() OR lower(t.email) = lower(auth.jwt() ->> 'email'))
              AND (t.id::text = student_monthly_notes.teacher_id OR t.teacher_id_code = student_monthly_notes.teacher_id)
        )
    );

DROP POLICY IF EXISTS "students_parents_view_own_monthly_notes" ON public.student_monthly_notes;
CREATE POLICY "students_parents_view_own_monthly_notes" ON public.student_monthly_notes
    FOR SELECT USING (
        (public.get_current_user_role() = 'STUDENT' AND EXISTS (
            SELECT 1 FROM public.students s
            WHERE (s.user_id = auth.uid() OR lower(s.email) = lower(auth.jwt() ->> 'email'))
              AND (s.id::text = student_monthly_notes.student_id OR s.student_id_code = student_monthly_notes.student_id)
        ))
        OR
        (public.get_current_user_role() = 'PARENT' AND EXISTS (
            SELECT 1 FROM public.students s
            WHERE lower(auth.jwt() ->> 'email') = ANY(s.parent_emails)
              AND (s.id::text = student_monthly_notes.student_id OR s.student_id_code = student_monthly_notes.student_id)
        ))
    );
