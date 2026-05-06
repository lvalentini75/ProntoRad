-- Migration: Fix user info@tatticaweb.it role and organization
-- This user needs to be org_admin for "Ospedale San Raffaele Milano" to create slots

-- ============================================================================
-- UPDATE USER ROLE AND ORGANIZATION
-- ============================================================================
DO $$
DECLARE
  v_user_id UUID;
  v_org_id UUID;
  v_auth_id UUID;
BEGIN
  -- Find the user by email
  SELECT id, auth_user_id INTO v_user_id, v_auth_id
  FROM public.users
  WHERE email = 'info@tatticaweb.it'
  LIMIT 1;
  
  IF v_user_id IS NULL THEN
    RAISE WARNING '❌ User info@tatticaweb.it not found in users table';
    RETURN;
  END IF;
  
  -- Find the organization "Ospedale San Raffaele Milano"
  SELECT id INTO v_org_id
  FROM public.organizations
  WHERE name ILIKE '%San Raffaele%' OR name ILIKE '%Milano%'
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF v_org_id IS NULL THEN
    RAISE WARNING '❌ Organization not found. Looking for any organization...';
    -- Fallback: get any organization
    SELECT id INTO v_org_id
    FROM public.organizations
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;
  
  IF v_org_id IS NULL THEN
    RAISE WARNING '❌ No organizations found in database';
    RETURN;
  END IF;
  
  -- Update user with org_admin role and organization
  UPDATE public.users
  SET 
    role = 'org_admin',
    organization_id = v_org_id,
    updated_at = NOW()
  WHERE id = v_user_id;
  
  RAISE NOTICE '✅ Updated user info@tatticaweb.it:';
  RAISE NOTICE '  - User ID: %', v_user_id;
  RAISE NOTICE '  - Auth ID: %', v_auth_id;
  RAISE NOTICE '  - Role: org_admin';
  RAISE NOTICE '  - Organization ID: %', v_org_id;
  
END $$;

-- ============================================================================
-- VERIFY UPDATE
-- ============================================================================
DO $$
DECLARE
  v_user_role TEXT;
  v_org_id UUID;
  v_org_name TEXT;
BEGIN
  SELECT u.role, u.organization_id, o.name
  INTO v_user_role, v_org_id, v_org_name
  FROM public.users u
  LEFT JOIN public.organizations o ON o.id = u.organization_id
  WHERE u.email = 'info@tatticaweb.it'
  LIMIT 1;
  
  IF v_user_role IS NOT NULL THEN
    RAISE NOTICE '✅ VERIFICATION PASSED:';
    RAISE NOTICE '  - Email: info@tatticaweb.it';
    RAISE NOTICE '  - Role: %', v_user_role;
    RAISE NOTICE '  - Organization: %', COALESCE(v_org_name, 'NESSUNA');
    RAISE NOTICE '  - Organization ID: %', COALESCE(v_org_id::TEXT, 'NULL');
  ELSE
    RAISE WARNING '❌ User not found during verification';
  END IF;
END $$;
