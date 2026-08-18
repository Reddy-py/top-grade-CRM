-- PostgreSQL Native DDL Architecture for TopGrade Student Management System

-- 1. Create Enums
CREATE TYPE user_role AS ENUM ('ADMIN', 'TEACHER', 'PARENT', 'STUDENT', 'ACCOUNTANT');
CREATE TYPE student_status AS ENUM ('LEAD_INQUIRY', 'ACTIVE', 'INACTIVE_ARCHIVED');
CREATE TYPE enrollment_status AS ENUM ('FORM_SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'ACTIVATED', 'DE_ENROLLED');
CREATE TYPE payment_method AS ENUM ('CREDIT_CARD', 'CASH', 'BANK_TRANSFER', 'CHEQUE');
CREATE TYPE reschedule_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED_NOTICE_WINDOW', 'REJECTED_CAP_EXCEEDED');
CREATE TYPE media_approval_status AS ENUM ('PENDING_CLEARANCE', 'APPROVED', 'REJECTED');
CREATE TYPE ledger_entry_type AS ENUM ('DEBIT', 'CREDIT');

-- 2. Core Tables
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'STUDENT',
    full_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_code VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    primary_mobile VARCHAR(50) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    dob DATE NOT NULL,
    residential_address TEXT NOT NULL,
    status student_status NOT NULL DEFAULT 'LEAD_INQUIRY',
    parent_id UUID REFERENCES users(id) ON DELETE SET NULL,
    enrolled_tenure_months INT DEFAULT 0,
    offboarding_date DATE,
    offboarding_reason TEXT,
    profile_image_url TEXT,
    media_approval_status media_approval_status DEFAULT 'PENDING_CLEARANCE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(50) NOT NULL,
    student_name VARCHAR(255) NOT NULL,
    parent_name VARCHAR(255),
    contact_number VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    academic_grade VARCHAR(100) NOT NULL,
    message TEXT,
    is_converted BOOLEAN DEFAULT FALSE,
    converted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID UNIQUE REFERENCES leads(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE SET NULL,
    academic_grade VARCHAR(100) NOT NULL,
    status enrollment_status NOT NULL DEFAULT 'FORM_SUBMITTED',
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    activated_at TIMESTAMP WITH TIME ZONE,
    review_notes TEXT,
    financial_waiver BOOLEAN DEFAULT FALSE,
    transport_waiver BOOLEAN DEFAULT FALSE,
    media_waiver BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS teachers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    qualification VARCHAR(255) NOT NULL,
    hourly_rate DECIMAL(10, 2) NOT NULL,
    weekly_max_sessions INT DEFAULT 20,
    weekly_assigned_sessions INT DEFAULT 0,
    gdrive_folder_submitted BOOLEAN DEFAULT FALSE,
    gdrive_folder_url TEXT,
    photo_waiver_signed BOOLEAN DEFAULT FALSE,
    photo_waiver_signed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS grades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grade_id UUID REFERENCES grades(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS class_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES teachers(id) ON DELETE CASCADE,
    session_name VARCHAR(255) NOT NULL,
    scheduled_start TIMESTAMP WITH TIME ZONE NOT NULL,
    scheduled_end TIMESTAMP WITH TIME ZONE NOT NULL,
    room_number VARCHAR(50),
    max_capacity INT DEFAULT 15
);

CREATE TABLE IF NOT EXISTS attendance_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_session_id UUID REFERENCES class_sessions(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_session_student UNIQUE (class_session_id, student_id)
);

CREATE TABLE IF NOT EXISTS reschedule_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    class_session_id UUID REFERENCES class_sessions(id) ON DELETE CASCADE,
    requested_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    new_requested_time VARCHAR(255) NOT NULL,
    reason TEXT NOT NULL,
    notice_window_hours DECIMAL(6, 2) NOT NULL,
    term_attempt_count INT NOT NULL,
    status reschedule_status NOT NULL DEFAULT 'PENDING',
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number VARCHAR(100) UNIQUE NOT NULL,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    total_amount DECIMAL(10, 2) NOT NULL,
    discount_amount DECIMAL(10, 2) DEFAULT 0.00,
    net_payable DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'UNPAID',
    due_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payment_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_number VARCHAR(100) UNIQUE NOT NULL,
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    amount_paid DECIMAL(10, 2) NOT NULL,
    payment_method payment_method NOT NULL,
    cheque_number VARCHAR(100),
    bank_name VARCHAR(255),
    clearance_ref VARCHAR(100),
    cheque_image_url TEXT,
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    entry_type ledger_entry_type NOT NULL,
    account_head VARCHAR(100) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    balance_after DECIMAL(10, 2) NOT NULL,
    description TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Indexes for Query Performance
CREATE INDEX idx_students_status ON students(status);
CREATE INDEX idx_students_email ON students(email);
CREATE INDEX idx_enrollments_status ON enrollments(status);
CREATE INDEX idx_reschedule_student ON reschedule_requests(student_id);
CREATE INDEX idx_invoices_student ON invoices(student_id);
