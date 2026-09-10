-- Migration: Weekly Schedule Engine, Faculty-Course Mapping, Daily Attendance & Student History
-- Date: 2026-09-10

-- 1. Schedules Table
CREATE TABLE IF NOT EXISTS schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id VARCHAR(100) NOT NULL,
    course_name VARCHAR(255) NOT NULL,
    teacher_id VARCHAR(100) NOT NULL,
    teacher_name VARCHAR(255) NOT NULL,
    day_of_week VARCHAR(20) NOT NULL,
    start_time VARCHAR(20) NOT NULL,
    end_time VARCHAR(20) NOT NULL,
    time_slot VARCHAR(50) NOT NULL,
    room VARCHAR(100) DEFAULT 'Room 101',
    location VARCHAR(255) DEFAULT 'Main Campus',
    max_capacity INT DEFAULT 15,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Schedule Students Mapping Table
CREATE TABLE IF NOT EXISTS schedule_students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
    student_id VARCHAR(100) NOT NULL,
    student_name VARCHAR(255) NOT NULL,
    student_code VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_schedule_student UNIQUE (schedule_id, student_id)
);

-- 3. Teacher Availability Table
CREATE TABLE IF NOT EXISTS teacher_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id VARCHAR(100) NOT NULL,
    day_of_week VARCHAR(20) NOT NULL,
    available_from VARCHAR(20) NOT NULL DEFAULT '09:00',
    available_to VARCHAR(20) NOT NULL DEFAULT '19:00',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Student History Ledger Table
CREATE TABLE IF NOT EXISTS student_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id VARCHAR(100) NOT NULL,
    student_name VARCHAR(255),
    event_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    actor VARCHAR(100) DEFAULT 'System',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Indexes for Fast Lookups
CREATE INDEX IF NOT EXISTS idx_schedules_day_time ON schedules(day_of_week, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_schedules_teacher ON schedules(teacher_id);
CREATE INDEX IF NOT EXISTS idx_schedules_course ON schedules(course_id);
CREATE INDEX IF NOT EXISTS idx_schedule_students_sched ON schedule_students(schedule_id);
CREATE INDEX IF NOT EXISTS idx_schedule_students_stud ON schedule_students(student_id);
CREATE INDEX IF NOT EXISTS idx_student_history_student ON student_history(student_id);
CREATE INDEX IF NOT EXISTS idx_teacher_availability_tchr ON teacher_availability(teacher_id);
