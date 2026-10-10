-- ============================================================================
-- TOPGRADE CRM: login-based access in the database (row-level security)
-- Four logins only: ADMIN (whole access), TEACHER, PARENT, STUDENT (restricted).
--
-- RUN THIS ON A STAGING COPY OF THE DATABASE FIRST.
-- It (1) removes the ACCOUNTANT role, (2) reads each user's role from `profiles`
-- (the old helper trusted user_metadata, which users can edit themselves),
-- (3) drops EVERY existing policy on public tables (including any "allow all" ones)
-- and turns row-level security on for every public table, then (4) adds the policies below.
-- The backend uses the service-role key, which bypasses RLS, so it keeps working.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Remove the ACCOUNTANT role (only four logins)
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE _former_accountants AS
  SELECT id, email FROM public.profiles WHERE role = 'ACCOUNTANT';

-- The profile is disabled (cannot sign in to the app). Delete the login itself in Supabase > Authentication > Users.
UPDATE public.profiles SET role = 'STUDENT', status = 'Disabled' WHERE role = 'ACCOUNTANT';
DELETE FROM public.role_permissions WHERE role_id = 'ACCOUNTANT';
DELETE FROM public.roles WHERE id = 'ACCOUNTANT';

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_four_roles_only;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_four_roles_only CHECK (role IN ('ADMIN', 'TEACHER', 'PARENT', 'STUDENT'));

-- ---------------------------------------------------------------------------
-- 2. Parent link: parent emails saved on the student (a parent login = a parent email)
-- ---------------------------------------------------------------------------
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS parent_emails TEXT[] NOT NULL DEFAULT '{}';
CREATE INDEX IF NOT EXISTS idx_students_parent_emails ON public.students USING GIN (parent_emails);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = 'students' AND column_name = 'parent_email') THEN
    EXECUTE $q$
      UPDATE public.students
         SET parent_emails = ARRAY[lower(trim(parent_email))]
       WHERE coalesce(cardinality(parent_emails), 0) = 0
         AND parent_email IS NOT NULL AND trim(parent_email) <> ''
    $q$;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3. Helper functions. All read the role from `profiles`, never from user_metadata.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.role FROM public.profiles p
  WHERE p.id = auth.uid() AND lower(p.status) = 'active'
  LIMIT 1;
$$;

-- Teacher identity keys: teacher row id, code, user id (lower-cased text)
CREATE OR REPLACE FUNCTION public.my_teacher_keys()
RETURNS TEXT[]
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(array_agg(DISTINCT lower(k)), '{}')
  FROM (
    SELECT t.id::text AS k FROM public.teachers t
      WHERE t.user_id = auth.uid() OR lower(t.email) = lower(auth.jwt() ->> 'email')
    UNION ALL
    SELECT t.teacher_id_code FROM public.teachers t
      WHERE t.user_id = auth.uid() OR lower(t.email) = lower(auth.jwt() ->> 'email')
    UNION ALL
    SELECT auth.uid()::text
  ) x WHERE k IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION public.my_teacher_names()
RETURNS TEXT[]
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(array_agg(DISTINCT lower(t.name)), '{}')
  FROM public.teachers t
  WHERE t.user_id = auth.uid() OR lower(t.email) = lower(auth.jwt() ->> 'email');
$$;

-- Schedule slots this login may see: teacher = own slots; parent/student = slots containing their child.
CREATE OR REPLACE FUNCTION public.my_schedule_ids()
RETURNS SETOF UUID
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE r TEXT := public.get_current_user_role();
BEGIN
  IF r = 'TEACHER' THEN
    RETURN QUERY
      SELECT sc.id FROM public.schedules sc
      WHERE lower(sc.teacher_id) = ANY (public.my_teacher_keys())
         OR lower(sc.teacher_name) = ANY (public.my_teacher_names());
  ELSIF r IN ('PARENT', 'STUDENT') THEN
    RETURN QUERY
      SELECT DISTINCT ss.schedule_id FROM public.schedule_students ss
      JOIN public.students s ON (ss.student_id = s.id::text OR ss.student_code = s.student_id_code)
      WHERE (r = 'STUDENT' AND (s.user_id = auth.uid() OR lower(s.email) = lower(auth.jwt() ->> 'email')))
         OR (r = 'PARENT' AND EXISTS (
              SELECT 1 FROM unnest(s.parent_emails) e WHERE lower(e) = lower(auth.jwt() ->> 'email')));
  END IF;
END $$;

-- Students this login may see.
--   STUDENT: themselves.   PARENT: children whose parent_emails contain the login email.
--   TEACHER: students in their own schedule slots, or assigned to them by name.
CREATE OR REPLACE FUNCTION public.my_student_ids()
RETURNS SETOF UUID
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE r TEXT := public.get_current_user_role();
BEGIN
  IF r = 'STUDENT' THEN
    RETURN QUERY
      SELECT s.id FROM public.students s
      WHERE s.user_id = auth.uid() OR lower(s.email) = lower(auth.jwt() ->> 'email');
  ELSIF r = 'PARENT' THEN
    RETURN QUERY
      SELECT s.id FROM public.students s
      WHERE EXISTS (SELECT 1 FROM unnest(s.parent_emails) e WHERE lower(e) = lower(auth.jwt() ->> 'email'));
  ELSIF r = 'TEACHER' THEN
    RETURN QUERY
      SELECT s.id FROM public.students s
      WHERE lower(s.teacher) = ANY (public.my_teacher_names())
         OR EXISTS (
              SELECT 1 FROM public.schedule_students ss
              WHERE ss.schedule_id IN (SELECT public.my_schedule_ids())
                AND (ss.student_id = s.id::text OR ss.student_code = s.student_id_code));
  END IF;
END $$;

-- student keys as text (ids and codes), used to filter schedule_students rows
CREATE OR REPLACE FUNCTION public.my_student_keys()
RETURNS TEXT[]
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(array_agg(k), '{}') FROM (
    SELECT s.id::text AS k FROM public.students s WHERE s.id IN (SELECT public.my_student_ids())
    UNION
    SELECT s.student_id_code FROM public.students s WHERE s.id IN (SELECT public.my_student_ids())
  ) x WHERE k IS NOT NULL;
$$;

-- Courses this login may see: teacher = courses they teach; parent/student = courses their child is in.
CREATE OR REPLACE FUNCTION public.my_course_visible(c_id UUID, c_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE r TEXT := public.get_current_user_role();
BEGIN
  IF r IS NULL OR r = 'ADMIN' THEN RETURN r = 'ADMIN'; END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.schedules sc
    WHERE sc.id IN (SELECT public.my_schedule_ids())
      AND (sc.course_id = c_id::text OR lower(sc.course_name) = lower(c_name))
  ) OR (r <> 'TEACHER' AND EXISTS (
    SELECT 1 FROM public.students s
    WHERE s.id IN (SELECT public.my_student_ids()) AND lower(s.program) = lower(c_name)
  ));
END $$;

-- ---------------------------------------------------------------------------
-- 4. Row-level security everywhere, old policies removed
-- ---------------------------------------------------------------------------
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public' LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.tablename);
  END LOOP;
END $$;
-- A table with RLS on and no policy is readable only by the backend (service role).

-- ---------------------------------------------------------------------------
-- 5. Policies. Admin = whole access. Everyone else is limited as described.
-- ---------------------------------------------------------------------------
DO $$
DECLARE t TEXT;
BEGIN
  -- Admin: everything, on every table that has a policy below
  FOREACH t IN ARRAY ARRAY[
    'profiles','students','teachers','courses','attendance','fees','parent_students',
    'schedules','schedule_students','student_history','teacher_availability',
    'teacher_course_assignments','admission_requests','de_enrollment_requests'
  ] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format(
        'CREATE POLICY "admin_all" ON public.%I FOR ALL TO authenticated
           USING (public.get_current_user_role() = ''ADMIN'')
           WITH CHECK (public.get_current_user_role() = ''ADMIN'')', t);
    END IF;
  END LOOP;
END $$;

-- profiles: everyone can read ONLY their own row. Nobody but admin can change a role.
CREATE POLICY "own_profile_read" ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid());

-- students: parent = own children, student = themselves, teacher = their students
CREATE POLICY "own_students_read" ON public.students FOR SELECT TO authenticated
  USING (id IN (SELECT public.my_student_ids()));

-- teachers: a teacher reads their own row. Parents and students get a trimmed list through the backend (no phone, email, salary).
CREATE POLICY "teacher_self_read" ON public.teachers FOR SELECT TO authenticated
  USING (public.get_current_user_role() = 'TEACHER'
         AND (user_id = auth.uid() OR lower(email) = lower(auth.jwt() ->> 'email')));

-- courses: only courses the login is part of
CREATE POLICY "own_courses_read" ON public.courses FOR SELECT TO authenticated
  USING (public.my_course_visible(id, name));

-- attendance: parent/student read own child; teacher reads and records for their own students
CREATE POLICY "own_attendance_read" ON public.attendance FOR SELECT TO authenticated
  USING (student_id IN (SELECT public.my_student_ids()));
CREATE POLICY "teacher_attendance_insert" ON public.attendance FOR INSERT TO authenticated
  WITH CHECK (public.get_current_user_role() = 'TEACHER' AND student_id IN (SELECT public.my_student_ids()));
CREATE POLICY "teacher_attendance_update" ON public.attendance FOR UPDATE TO authenticated
  USING (public.get_current_user_role() = 'TEACHER' AND student_id IN (SELECT public.my_student_ids()))
  WITH CHECK (public.get_current_user_role() = 'TEACHER' AND student_id IN (SELECT public.my_student_ids()));

-- fees: parent reads own child's fees. Students and teachers have no fee access. Payments are recorded by the backend only.
CREATE POLICY "parent_fees_read" ON public.fees FOR SELECT TO authenticated
  USING (public.get_current_user_role() = 'PARENT' AND student_id IN (SELECT public.my_student_ids()));

DO $$
BEGIN
  IF to_regclass('public.parent_students') IS NOT NULL THEN
    CREATE POLICY "parent_links_read" ON public.parent_students FOR SELECT TO authenticated
      USING (parent_id = auth.uid());
  END IF;

  IF to_regclass('public.schedules') IS NOT NULL THEN
    CREATE POLICY "own_schedules_read" ON public.schedules FOR SELECT TO authenticated
      USING (id IN (SELECT public.my_schedule_ids()));
  END IF;

  IF to_regclass('public.schedule_students') IS NOT NULL THEN
    -- teacher: whole roster of own slots; parent/student: only their own child's rows
    CREATE POLICY "own_schedule_students_read" ON public.schedule_students FOR SELECT TO authenticated
      USING (
        (public.get_current_user_role() = 'TEACHER' AND schedule_id IN (SELECT public.my_schedule_ids()))
        OR (public.get_current_user_role() IN ('PARENT', 'STUDENT')
            AND (student_id = ANY (public.my_student_keys()) OR student_code = ANY (public.my_student_keys())))
      );
  END IF;

  IF to_regclass('public.teacher_availability') IS NOT NULL THEN
    CREATE POLICY "teacher_availability_own" ON public.teacher_availability FOR ALL TO authenticated
      USING (public.get_current_user_role() = 'TEACHER' AND lower(teacher_id) = ANY (public.my_teacher_keys()))
      WITH CHECK (public.get_current_user_role() = 'TEACHER' AND lower(teacher_id) = ANY (public.my_teacher_keys()));
  END IF;

  IF to_regclass('public.teacher_course_assignments') IS NOT NULL THEN
    CREATE POLICY "teacher_assignments_read" ON public.teacher_course_assignments FOR SELECT TO authenticated
      USING (public.get_current_user_role() = 'TEACHER' AND lower(teacher_id::text) = ANY (public.my_teacher_keys()));
  END IF;

  IF to_regclass('public.de_enrollment_requests') IS NOT NULL THEN
    CREATE POLICY "own_deenrollment_read" ON public.de_enrollment_requests FOR SELECT TO authenticated
      USING (student_id IN (SELECT public.my_student_ids()));
    CREATE POLICY "own_deenrollment_insert" ON public.de_enrollment_requests FOR INSERT TO authenticated
      WITH CHECK (public.get_current_user_role() IN ('PARENT', 'STUDENT')
                  AND student_id IN (SELECT public.my_student_ids())
                  AND status = 'Pending');
  END IF;
  -- student_history, admission_requests: admin only (backend writes with the service role)
END $$;

-- ---------------------------------------------------------------------------
-- 6. Result: accounts that were Accountants. Delete these logins in Supabase > Authentication > Users.
-- ---------------------------------------------------------------------------
SELECT id, email, 'former Accountant: profile disabled, delete this login in Authentication > Users' AS note
FROM _former_accountants;
