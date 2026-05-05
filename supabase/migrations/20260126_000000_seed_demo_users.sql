-- =====================================================
-- ProntoRad - Demo Users Seed Script
-- =====================================================
-- Questo script crea gli utenti demo per il sistema:
-- 1. Super Admin (admin@prontorad.demo)
-- 2. Org Admin Ospedale (ospedale@prontorad.demo)
-- 3. Org Admin Istituto (istituto@prontorad.demo)
-- 4. End User (user@prontorad.demo)
--
-- Password per tutti: password123
-- =====================================================

DO $$
DECLARE
  -- Organization IDs
  org_hospital_id uuid;
  org_institute_id uuid;
  
  -- Auth user IDs
  admin_auth_id uuid;
  hospital_auth_id uuid;
  institute_auth_id uuid;
  user_auth_id uuid;
  
  -- Profile user IDs
  admin_user_id uuid;
  hospital_user_id uuid;
  institute_user_id uuid;
  enduser_user_id uuid;
BEGIN
  
  -- =====================================================
  -- STEP 1: Crea organizzazioni demo
  -- =====================================================
  
  -- Cerca Ospedale San Raffaele esistente
  SELECT id INTO org_hospital_id FROM organizations WHERE email = 'info@hsr.it' LIMIT 1;
  
  -- Se non esiste, crealo
  IF org_hospital_id IS NULL THEN
    INSERT INTO organizations (
      id,
      name,
      org_type,
      address,
      city,
      province,
      region,
      phone,
      email,
      website,
      vat_number,
      latitude,
      longitude,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      'Ospedale San Raffaele Milano',
      'hospital',
      'Via Olgettina, 60',
      'Milano',
      'MI',
      'Lombardia',
      '+39 02 26431',
      'info@hsr.it',
      'https://www.hsr.it',
      'IT12345678901',
      45.4978,
      9.2612,
      now(),
      now()
    )
    RETURNING id INTO org_hospital_id;
  ELSE
    -- Aggiorna se esiste
    UPDATE organizations SET
      name = 'Ospedale San Raffaele Milano',
      updated_at = now()
    WHERE id = org_hospital_id;
  END IF;
  
  -- Cerca Istituto Diagnostico Italiano esistente
  SELECT id INTO org_institute_id FROM organizations WHERE email = 'info@idi.it' LIMIT 1;
  
  -- Se non esiste, crealo
  IF org_institute_id IS NULL THEN
    INSERT INTO organizations (
      id,
      name,
      org_type,
      address,
      city,
      province,
      region,
      phone,
      email,
      website,
      vat_number,
      latitude,
      longitude,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      'Istituto Diagnostico Italiano',
      'institute',
      'Via Sant''Ambrogio, 5',
      'Milano',
      'MI',
      'Lombardia',
      '+39 02 55181',
      'info@idi.it',
      'https://www.idi.it',
      'IT98765432109',
      45.4667,
      9.1833,
      now(),
      now()
    )
    RETURNING id INTO org_institute_id;
  ELSE
    -- Aggiorna se esiste
    UPDATE organizations SET
      name = 'Istituto Diagnostico Italiano',
      updated_at = now()
    WHERE id = org_institute_id;
  END IF;
  
  -- =====================================================
  -- STEP 2: Crea utenti in auth.users (Supabase Auth)
  -- =====================================================
  
  -- 1. Super Admin
  SELECT id INTO admin_auth_id FROM auth.users WHERE email = 'admin@prontorad.demo' LIMIT 1;
  
  IF admin_auth_id IS NULL THEN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      aud,
      role,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token
    ) VALUES (
      gen_random_uuid(),
      '00000000-0000-0000-0000-000000000000',
      'admin@prontorad.demo',
      crypt('password123', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"first_name":"Admin","last_name":"Sistema"}',
      'authenticated',
      'authenticated',
      now(),
      now(),
      '',
      ''
    )
    RETURNING id INTO admin_auth_id;
  ELSE
    UPDATE auth.users SET
      encrypted_password = crypt('password123', gen_salt('bf')),
      updated_at = now()
    WHERE id = admin_auth_id;
  END IF;

  -- 2. Org Admin Ospedale
  SELECT id INTO hospital_auth_id FROM auth.users WHERE email = 'ospedale@prontorad.demo' LIMIT 1;
  
  IF hospital_auth_id IS NULL THEN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      aud,
      role,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token
    ) VALUES (
      gen_random_uuid(),
      '00000000-0000-0000-0000-000000000000',
      'ospedale@prontorad.demo',
      crypt('password123', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"first_name":"Mario","last_name":"Rossi"}',
      'authenticated',
      'authenticated',
      now(),
      now(),
      '',
      ''
    )
    RETURNING id INTO hospital_auth_id;
  ELSE
    UPDATE auth.users SET
      encrypted_password = crypt('password123', gen_salt('bf')),
      updated_at = now()
    WHERE id = hospital_auth_id;
  END IF;

  -- 3. Org Admin Istituto
  SELECT id INTO institute_auth_id FROM auth.users WHERE email = 'istituto@prontorad.demo' LIMIT 1;
  
  IF institute_auth_id IS NULL THEN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      aud,
      role,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token
    ) VALUES (
      gen_random_uuid(),
      '00000000-0000-0000-0000-000000000000',
      'istituto@prontorad.demo',
      crypt('password123', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"first_name":"Laura","last_name":"Bianchi"}',
      'authenticated',
      'authenticated',
      now(),
      now(),
      '',
      ''
    )
    RETURNING id INTO institute_auth_id;
  ELSE
    UPDATE auth.users SET
      encrypted_password = crypt('password123', gen_salt('bf')),
      updated_at = now()
    WHERE id = institute_auth_id;
  END IF;

  -- 4. End User
  SELECT id INTO user_auth_id FROM auth.users WHERE email = 'user@prontorad.demo' LIMIT 1;
  
  IF user_auth_id IS NULL THEN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      aud,
      role,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token
    ) VALUES (
      gen_random_uuid(),
      '00000000-0000-0000-0000-000000000000',
      'user@prontorad.demo',
      crypt('password123', gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      '{"first_name":"Luca","last_name":"Verdi"}',
      'authenticated',
      'authenticated',
      now(),
      now(),
      '',
      ''
    )
    RETURNING id INTO user_auth_id;
  ELSE
    UPDATE auth.users SET
      encrypted_password = crypt('password123', gen_salt('bf')),
      updated_at = now()
    WHERE id = user_auth_id;
  END IF;

  -- =====================================================
  -- STEP 3: Crea profili in users table
  -- =====================================================

  -- Super Admin Profile
  INSERT INTO users (
    id,
    first_name,
    last_name,
    email,
    phone_number,
    auth_user_id,
    role,
    organization_id,
    fiscal_code,
    date_of_birth,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    'Admin',
    'Sistema',
    'admin@prontorad.demo',
    '+39 333 1234567',
    admin_auth_id,
    'super_admin',
    NULL,
    'ADMSIS85M01H501Z',
    '1985-08-01',
    now(),
    now()
  )
  ON CONFLICT (email) DO UPDATE SET
    auth_user_id = EXCLUDED.auth_user_id,
    role = 'super_admin',
    updated_at = now()
  RETURNING id INTO admin_user_id;
  
  -- Org Admin Ospedale Profile
  INSERT INTO users (
    id,
    first_name,
    last_name,
    email,
    phone_number,
    auth_user_id,
    role,
    organization_id,
    fiscal_code,
    date_of_birth,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    'Mario',
    'Rossi',
    'ospedale@prontorad.demo',
    '+39 333 9876543',
    hospital_auth_id,
    'org_admin',
    org_hospital_id,
    'RSSMRA75D15F205X',
    '1975-04-15',
    now(),
    now()
  )
  ON CONFLICT (email) DO UPDATE SET
    auth_user_id = EXCLUDED.auth_user_id,
    role = 'org_admin',
    organization_id = org_hospital_id,
    updated_at = now()
  RETURNING id INTO hospital_user_id;
  
  -- Org Admin Istituto Profile
  INSERT INTO users (
    id,
    first_name,
    last_name,
    email,
    phone_number,
    auth_user_id,
    role,
    organization_id,
    fiscal_code,
    date_of_birth,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    'Laura',
    'Bianchi',
    'istituto@prontorad.demo',
    '+39 333 5551234',
    institute_auth_id,
    'org_admin',
    org_institute_id,
    'BNCLRA80H50F205Y',
    '1980-06-10',
    now(),
    now()
  )
  ON CONFLICT (email) DO UPDATE SET
    auth_user_id = EXCLUDED.auth_user_id,
    role = 'org_admin',
    organization_id = org_institute_id,
    updated_at = now()
  RETURNING id INTO institute_user_id;
  
  -- End User Profile
  INSERT INTO users (
    id,
    first_name,
    last_name,
    email,
    phone_number,
    auth_user_id,
    role,
    organization_id,
    fiscal_code,
    date_of_birth,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    'Luca',
    'Verdi',
    'user@prontorad.demo',
    '+39 333 7778888',
    user_auth_id,
    'end_user',
    NULL,
    'VRDLCU90A01F205W',
    '1990-01-01',
    now(),
    now()
  )
  ON CONFLICT (email) DO UPDATE SET
    auth_user_id = EXCLUDED.auth_user_id,
    role = 'end_user',
    updated_at = now()
  RETURNING id INTO enduser_user_id;
  
  -- =====================================================
  -- STEP 4: Output risultati
  -- =====================================================
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ ========================================';
  RAISE NOTICE '✅ Utenti demo creati con successo!';
  RAISE NOTICE '✅ ========================================';
  RAISE NOTICE '';
  RAISE NOTICE '🏥 Organizzazioni:';
  RAISE NOTICE '   - Ospedale San Raffaele Milano (ID: %)', org_hospital_id;
  RAISE NOTICE '   - Istituto Diagnostico Italiano (ID: %)', org_institute_id;
  RAISE NOTICE '';
  RAISE NOTICE '👥 Utenti:';
  RAISE NOTICE '   1. admin@prontorad.demo (super_admin)';
  RAISE NOTICE '      Auth ID: %', admin_auth_id;
  RAISE NOTICE '      User ID: %', admin_user_id;
  RAISE NOTICE '';
  RAISE NOTICE '   2. ospedale@prontorad.demo (org_admin - Ospedale)';
  RAISE NOTICE '      Auth ID: %', hospital_auth_id;
  RAISE NOTICE '      User ID: %', hospital_user_id;
  RAISE NOTICE '';
  RAISE NOTICE '   3. istituto@prontorad.demo (org_admin - Istituto)';
  RAISE NOTICE '      Auth ID: %', institute_auth_id;
  RAISE NOTICE '      User ID: %', institute_user_id;
  RAISE NOTICE '';
  RAISE NOTICE '   4. user@prontorad.demo (end_user)';
  RAISE NOTICE '      Auth ID: %', user_auth_id;
  RAISE NOTICE '      User ID: %', enduser_user_id;
  RAISE NOTICE '';
  RAISE NOTICE '🔑 Password per tutti: password123';
  RAISE NOTICE '';
  RAISE NOTICE '✅ ========================================';
  
END $$;
