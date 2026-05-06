-- Migration: Associate user ospedale@prontorad.demo with Ospedale Regionale di Bellinzona
-- Date: 2026-05-06
-- Description: Link organization admin user to their hospital

-- Find the organization_id for Ospedale Regionale di Bellinzona
DO $$
DECLARE
  bellinzona_org_id UUID;
  hospital_user_id UUID;
BEGIN
  -- Get the organization ID
  SELECT id INTO bellinzona_org_id
  FROM organizations
  WHERE name = 'Ospedale Regionale di Bellinzona'
  AND country = 'Svizzera'
  LIMIT 1;

  -- Get the user ID for ospedale@prontorad.demo
  SELECT id INTO hospital_user_id
  FROM users
  WHERE email = 'ospedale@prontorad.demo'
  LIMIT 1;

  -- Display current state
  RAISE NOTICE '=== Association Update ===';
  RAISE NOTICE 'Organization: Ospedale Regionale di Bellinzona (ID: %)', bellinzona_org_id;
  RAISE NOTICE 'User: ospedale@prontorad.demo (ID: %)', hospital_user_id;

  -- Update user with organization_id
  IF bellinzona_org_id IS NOT NULL AND hospital_user_id IS NOT NULL THEN
    UPDATE users
    SET 
      organization_id = bellinzona_org_id,
      role = 'org_admin',
      updated_at = NOW()
    WHERE email = 'ospedale@prontorad.demo';

    RAISE NOTICE '✅ User successfully linked to organization';
  ELSE
    IF bellinzona_org_id IS NULL THEN
      RAISE NOTICE '❌ ERROR: Organization "Ospedale Regionale di Bellinzona" not found';
    END IF;
    IF hospital_user_id IS NULL THEN
      RAISE NOTICE '❌ ERROR: User "ospedale@prontorad.demo" not found';
    END IF;
  END IF;

  -- Display final state
  RAISE NOTICE '';
  RAISE NOTICE '=== Final User State ===';
  RAISE NOTICE 'Email: %', (SELECT email FROM users WHERE id = hospital_user_id);
  RAISE NOTICE 'Role: %', (SELECT role FROM users WHERE id = hospital_user_id);
  RAISE NOTICE 'Organization: %', (SELECT name FROM organizations WHERE id = (SELECT organization_id FROM users WHERE id = hospital_user_id));
END $$;
