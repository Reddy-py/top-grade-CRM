-- Migration: Add exam_date and student_address to students table
ALTER TABLE students ADD COLUMN IF NOT EXISTS exam_date DATE;
ALTER TABLE students ADD COLUMN IF NOT EXISTS student_address TEXT;
ALTER TABLE students ADD COLUMN IF NOT EXISTS alternate_address TEXT;
ALTER TABLE students ADD COLUMN IF NOT EXISTS purchased_hours NUMERIC DEFAULT 0;

-- Comments for documentation
COMMENT ON COLUMN students.exam_date IS 'Scheduled examination date for the student';
COMMENT ON COLUMN students.student_address IS 'Dedicated residential address for the student';
COMMENT ON COLUMN students.alternate_address IS 'Alternate living or secondary address for student';
COMMENT ON COLUMN students.purchased_hours IS 'Total tuition hours purchased in student package';
