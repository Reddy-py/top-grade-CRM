-- ============================================================================
-- TOPGRADE CRM: Test User Accounts Seed Script
-- Creates 5 test users in auth.users and public.profiles for role testing
-- Default Password for all test accounts: TopGrade2026!
-- ============================================================================

-- Helper function to seed an auth user safely
CREATE OR REPLACE FUNCTION public.seed_test_user(
    p_email TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_role TEXT
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID;
    v_encrypted_pw TEXT;
BEGIN
    -- Check if user already exists
    SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();
        -- Cryptographic password hash compatible with pgcrypto / Supabase auth
        v_encrypted_pw := crypt(p_password, gen_salt('bf'));

        INSERT INTO auth.users (
            id,
            instance_id,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            created_at,
            updated_at,
            role,
            aud
        ) VALUES (
            v_user_id,
            '00000000-0000-0000-0000-000000000000',
            p_email,
            v_encrypted_pw,
            NOW(),
            '{"provider":"email","providers":["email"]}',
            jsonb_build_object('full_name', p_full_name, 'role', p_role),
            NOW(),
            NOW(),
            'authenticated',
            'authenticated'
        );
    END IF;

    -- Upsert profile record
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (v_user_id, p_email, p_full_name, p_role)
    ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        updated_at = NOW();

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute Seeding for All 5 System Roles
SELECT public.seed_test_user('admin@topgrade.edu', 'TopGrade2026!', 'Manikanta Admin', 'ADMIN');
SELECT public.seed_test_user('accountant@topgrade.edu', 'TopGrade2026!', 'Priya Sharma (Accountant)', 'ACCOUNTANT');
SELECT public.seed_test_user('teacher@topgrade.edu', 'TopGrade2026!', 'Vikram Teacher', 'TEACHER');
SELECT public.seed_test_user('parent@topgrade.edu', 'TopGrade2026!', 'Suresh Kumar (Parent)', 'PARENT');
SELECT public.seed_test_user('student@topgrade.edu', 'TopGrade2026!', 'Rahul Kumar (Student)', 'STUDENT');

-- Cleanup temporary helper function
DROP FUNCTION public.seed_test_user(TEXT, TEXT, TEXT, TEXT);
