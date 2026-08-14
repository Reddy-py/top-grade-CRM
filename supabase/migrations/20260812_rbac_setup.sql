-- ============================================================================
-- TOPGRADE CRM: Full Database Setup Script (Tables, RLS & Schema)
-- Run this in your Supabase Dashboard -> SQL Editor
-- ============================================================================

-- 1. Create Roles Table
CREATE TABLE IF NOT EXISTS public.roles (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.roles (id, name, description) VALUES
    ('ADMIN', 'Admin / Management', 'Full operational system control'),
    ('ACCOUNTANT', 'Accountant', 'Financial operations, fees, payments, and receipts'),
    ('TEACHER', 'Teacher', 'Academic management for assigned classes and courses'),
    ('PARENT', 'Parent', 'Access to linked children academic and financial records'),
    ('STUDENT', 'Student', 'Access to personal academic and financial records')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- 2. Create Role Permissions Matrix Table
CREATE TABLE IF NOT EXISTS public.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id TEXT NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    permission TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(role_id, permission)
);

INSERT INTO public.role_permissions (role_id, permission) VALUES
    -- ADMIN Permissions
    ('ADMIN', 'dashboard.view'), ('ADMIN', 'students.view'), ('ADMIN', 'students.create'), ('ADMIN', 'students.edit'), ('ADMIN', 'students.delete'),
    ('ADMIN', 'parents.view'), ('ADMIN', 'parents.create'), ('ADMIN', 'parents.edit'), ('ADMIN', 'parents.delete'), ('ADMIN', 'parents.link_children'),
    ('ADMIN', 'teachers.view'), ('ADMIN', 'teachers.create'), ('ADMIN', 'teachers.edit'), ('ADMIN', 'teachers.delete'),
    ('ADMIN', 'courses.view'), ('ADMIN', 'courses.create'), ('ADMIN', 'courses.edit'), ('ADMIN', 'courses.delete'),
    ('ADMIN', 'classes.view'), ('ADMIN', 'classes.create'), ('ADMIN', 'classes.edit'), ('ADMIN', 'classes.delete'),
    ('ADMIN', 'attendance.view'), ('ADMIN', 'attendance.create'), ('ADMIN', 'attendance.edit'), ('ADMIN', 'attendance.delete'),
    ('ADMIN', 'fees.view'), ('ADMIN', 'fees.create'), ('ADMIN', 'fees.edit'), ('ADMIN', 'fees.delete'), ('ADMIN', 'fees.pay'),
    ('ADMIN', 'payments.view'), ('ADMIN', 'payments.create'), ('ADMIN', 'payments.edit'), ('ADMIN', 'payments.delete'),
    ('ADMIN', 'receipts.view'), ('ADMIN', 'receipts.create'), ('ADMIN', 'receipts.download'),
    ('ADMIN', 'reports.view'), ('ADMIN', 'users.view'), ('ADMIN', 'users.create'), ('ADMIN', 'users.edit'), ('ADMIN', 'users.disable'),
    ('ADMIN', 'roles.view'), ('ADMIN', 'roles.manage'), ('ADMIN', 'settings.view'), ('ADMIN', 'settings.edit'), ('ADMIN', 'settings.manage'),

    -- ACCOUNTANT Permissions
    ('ACCOUNTANT', 'dashboard.view'), ('ACCOUNTANT', 'students.view'),
    ('ACCOUNTANT', 'fees.view'), ('ACCOUNTANT', 'fees.create'), ('ACCOUNTANT', 'fees.edit'), ('ACCOUNTANT', 'fees.pay'),
    ('ACCOUNTANT', 'payments.view'), ('ACCOUNTANT', 'payments.create'), ('ACCOUNTANT', 'payments.edit'),
    ('ACCOUNTANT', 'receipts.view'), ('ACCOUNTANT', 'receipts.create'), ('ACCOUNTANT', 'receipts.download'),
    ('ACCOUNTANT', 'reports.view'), ('ACCOUNTANT', 'attendance.view'), ('ACCOUNTANT', 'settings.view'),

    -- TEACHER Permissions
    ('TEACHER', 'dashboard.view'), ('TEACHER', 'students.view'), ('TEACHER', 'teachers.view'),
    ('TEACHER', 'courses.view'), ('TEACHER', 'classes.view'),
    ('TEACHER', 'attendance.view'), ('TEACHER', 'attendance.create'), ('TEACHER', 'attendance.edit'),
    ('TEACHER', 'reports.view'), ('TEACHER', 'settings.view'),

    -- PARENT Permissions
    ('PARENT', 'dashboard.view'), ('PARENT', 'students.view'), ('PARENT', 'courses.view'),
    ('PARENT', 'classes.view'), ('PARENT', 'attendance.view'),
    ('PARENT', 'fees.view'), ('PARENT', 'fees.pay'), ('PARENT', 'payments.view'),
    ('PARENT', 'receipts.view'), ('PARENT', 'receipts.download'), ('PARENT', 'reports.view'), ('PARENT', 'settings.view'),

    -- STUDENT Permissions
    ('STUDENT', 'dashboard.view'), ('STUDENT', 'students.view'), ('STUDENT', 'courses.view'),
    ('STUDENT', 'classes.view'), ('STUDENT', 'attendance.view'),
    ('STUDENT', 'fees.view'), ('STUDENT', 'fees.pay'), ('STUDENT', 'payments.view'),
    ('STUDENT', 'receipts.view'), ('STUDENT', 'receipts.download'), ('STUDENT', 'reports.view'), ('STUDENT', 'settings.view')
ON CONFLICT (role_id, permission) DO NOTHING;

-- 3. Create User Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    phone TEXT,
    role TEXT NOT NULL DEFAULT 'STUDENT' REFERENCES public.roles(id),
    status TEXT NOT NULL DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create Students Table
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    student_id_code TEXT UNIQUE,
    name TEXT NOT NULL,
    gender TEXT,
    dob DATE,
    age INT,
    nationality TEXT,
    address TEXT,
    alternate_address TEXT,
    medical_notes TEXT,
    phone TEXT,
    email TEXT,
    
    father_name TEXT,
    mother_name TEXT,
    guardian TEXT,
    father_phone TEXT,
    mother_phone TEXT,
    govt_id_url TEXT,

    program TEXT,
    teacher TEXT,
    pricing_type TEXT DEFAULT 'Total Amount',
    purchased_hours NUMERIC DEFAULT 0,
    payment_method TEXT,
    cheque_image_url TEXT,
    discount TEXT,
    discount_approved BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Create Teachers Table
CREATE TABLE IF NOT EXISTS public.teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    teacher_id_code TEXT UNIQUE,
    name TEXT NOT NULL,
    dob DATE,
    age INT,
    qualification TEXT,
    qualification_certificate_url TEXT,
    resume_url TEXT,
    photo_url TEXT,
    phone TEXT,
    email TEXT,
    specialization TEXT,
    experience TEXT,
    joining_date DATE,
    salary TEXT,
    availability_days JSONB,
    availability_slots JSONB,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Create Courses Table
CREATE TABLE IF NOT EXISTS public.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_code TEXT UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    age_group TEXT,
    duration TEXT,
    fee NUMERIC DEFAULT 0,
    max_students INT DEFAULT 15,
    required_teacher_skills TEXT,
    course_material TEXT,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Create Teacher Course Assignments Table (Accept / Decline Workflow)
CREATE TABLE IF NOT EXISTS public.teacher_course_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID REFERENCES public.teachers(id) ON DELETE CASCADE,
    teacher_name TEXT NOT NULL,
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
    course_name TEXT NOT NULL,
    status TEXT DEFAULT 'Pending', -- Pending, Accepted, Declined
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ
);

-- 8. Create Attendance Table
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    status TEXT NOT NULL, -- Present, Absent, Late, Excused
    date DATE DEFAULT CURRENT_DATE,
    remarks TEXT,
    marked_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Create Fees Table
CREATE TABLE IF NOT EXISTS public.fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    fee_type TEXT NOT NULL,
    amount_paid NUMERIC DEFAULT 0,
    payment_date TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'Completed',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Create Parent Students Mapping Table
CREATE TABLE IF NOT EXISTS public.parent_students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    relationship TEXT DEFAULT 'Parent',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(parent_id, student_id)
);

-- 11. Admission Requests & De-enrollment Tables
CREATE TABLE IF NOT EXISTS public.admission_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    course_interested TEXT,
    status TEXT DEFAULT 'Pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.de_enrollment_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    course_name TEXT NOT NULL,
    student_photo_url TEXT,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'Pending',
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    approved_at TIMESTAMPTZ
);

-- 12. Enable Row-Level Security (RLS) on All Core Tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;

-- 13. Non-Recursive Role Helper Function
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (current_setting('request.jwt.claims', true)::json->'user_metadata'->>'role'),
    'STUDENT'
  );
$$;

-- 14. Non-Recursive RLS Policies
DROP POLICY IF EXISTS "Admin full access to profiles" ON public.profiles;
CREATE POLICY "Admin full access to profiles" ON public.profiles FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admin full access to students" ON public.students;
CREATE POLICY "Admin full access to students" ON public.students FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Accountants can view students" ON public.students;
CREATE POLICY "Accountants can view students" ON public.students FOR SELECT USING (public.get_current_user_role() = 'ACCOUNTANT');

DROP POLICY IF EXISTS "Students can view own record" ON public.students;
CREATE POLICY "Students can view own record" ON public.students FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin full access to courses" ON public.courses;
CREATE POLICY "Admin full access to courses" ON public.courses FOR ALL USING (public.get_current_user_role() = 'ADMIN');

DROP POLICY IF EXISTS "Authenticated users can view courses" ON public.courses;
CREATE POLICY "Authenticated users can view courses" ON public.courses FOR SELECT USING (auth.role() = 'authenticated');
