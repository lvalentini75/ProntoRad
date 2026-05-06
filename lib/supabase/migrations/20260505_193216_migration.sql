-- ============================================================================
-- Migration: DIAGNOSTIC & FIX for ospedale@prontorad.demo user
-- Date: 2026-05-05
-- Problem: Slots not being created - RLS blocking INSERT
-- Root cause: User may not have correct role or organization_id
-- ============================================================================

-- STEP 1: Print current state of ospedale@prontorad.demo
-- ============================================================================
DO $$
DECLARE
  v_user RECORD;
  v_org RECORD;
  v_auth_user_id UUID;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🔍 DIAGNOSI UTENTE ospedale@prontorad.demo';
  RAISE NOTICE '============================================================';
  
  -- Find user in users table
  SELECT * INTO v_user FROM users WHERE email = 'ospedale@prontorad.demo';
  
  IF v_user IS NULL THEN
    RAISE NOTICE '❌ UTENTE NON TROVATO nella tabella users!';
  ELSE
    RAISE NOTICE '✅ UTENTE TROVATO:';
    RAISE NOTICE '   - ID: %', v_user.id;
    RAISE NOTICE '   - Email: %', v_user.email;
    RAISE NOTICE '   - auth_user_id: %', v_user.auth_user_id;
    RAISE NOTICE '   - role: %', v_user.role;
    RAISE NOTICE '   - organization_id: %', v_user.organization_id;
    
    -- Check organization
    IF v_user.organization_id IS NULL THEN
      RAISE NOTICE '❌ ORGANIZATION_ID è NULL!';
    ELSE
      SELECT * INTO v_org FROM organizations WHERE id = v_user.organization_id;
      IF v_org IS NULL THEN
        RAISE NOTICE '❌ Organizzazione con ID % NON ESISTE!', v_user.organization_id;
      ELSE
        RAISE NOTICE '✅ Organizzazione: % (ID: %)', v_org.name, v_org.id;
      END IF;
    END IF;
    
    -- Check role
    IF v_user.role = 'org_admin' OR v_user.role = 'super_admin' THEN
      RAISE NOTICE '✅ Ruolo corretto: %', v_user.role;
    ELSE
      RAISE NOTICE '❌ Ruolo NON corretto: % (dovrebbe essere org_admin o super_admin)', v_user.role;
    END IF;
  END IF;
  
  RAISE NOTICE '';
END $$;

-- STEP 2: Find the organization "Ospedale San Raffaele Milano" and get its ID
-- ============================================================================
DO $$
DECLARE
  v_org_id UUID;
  v_org_name TEXT;
BEGIN
  -- Try to find organization containing "San Raffaele" or "Ospedale"
  SELECT id, name INTO v_org_id, v_org_name 
  FROM organizations 
  WHERE LOWER(name) LIKE '%san raffaele%' 
     OR LOWER(name) LIKE '%ospedale%'
  LIMIT 1;
  
  IF v_org_id IS NULL THEN
    -- Get first organization as fallback
    SELECT id, name INTO v_org_id, v_org_name FROM organizations LIMIT 1;
  END IF;
  
  IF v_org_id IS NOT NULL THEN
    RAISE NOTICE '🏥 Organizzazione target: % (ID: %)', v_org_name, v_org_id;
    
    -- Now update the user
    UPDATE users 
    SET 
      role = 'org_admin',
      organization_id = v_org_id,
      updated_at = NOW()
    WHERE email = 'ospedale@prontorad.demo';
    
    IF FOUND THEN
      RAISE NOTICE '✅ Utente ospedale@prontorad.demo aggiornato con successo!';
      RAISE NOTICE '   - role: org_admin';
      RAISE NOTICE '   - organization_id: %', v_org_id;
    ELSE
      RAISE NOTICE '⚠️ Utente non trovato o già aggiornato';
    END IF;
  ELSE
    RAISE NOTICE '❌ Nessuna organizzazione trovata nel database!';
  END IF;
END $$;

-- STEP 3: Also fix any user with email containing "ospedale" or "hospital"
-- ============================================================================
DO $$
DECLARE
  v_org_id UUID;
  v_updated INT := 0;
BEGIN
  -- Get first organization
  SELECT id INTO v_org_id FROM organizations LIMIT 1;
  
  IF v_org_id IS NOT NULL THEN
    -- Update users with hospital-like emails that don't have org_admin role
    UPDATE users 
    SET 
      role = 'org_admin',
      organization_id = COALESCE(organization_id, v_org_id),
      updated_at = NOW()
    WHERE (
      LOWER(email) LIKE '%ospedale%' 
      OR LOWER(email) LIKE '%hospital%'
      OR LOWER(email) LIKE '%prontorad.demo%'
    )
    AND (role != 'org_admin' OR organization_id IS NULL);
    
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    
    IF v_updated > 0 THEN
      RAISE NOTICE '✅ Aggiornati % utenti "ospedale/hospital"', v_updated;
    END IF;
  END IF;
END $$;

-- STEP 4: Verify final state
-- ============================================================================
DO $$
DECLARE
  v_user RECORD;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '📋 STATO FINALE UTENTI ADMIN:';
  RAISE NOTICE '============================================================';
  
  FOR v_user IN
    SELECT u.email, u.role, u.organization_id, o.name as org_name
    FROM users u
    LEFT JOIN organizations o ON o.id = u.organization_id
    WHERE u.role IN ('org_admin', 'super_admin')
    ORDER BY u.email
  LOOP
    RAISE NOTICE '   %: % @ %', v_user.email, v_user.role, COALESCE(v_user.org_name, 'NESSUNA ORG');
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '✅ MIGRAZIONE COMPLETATA';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️ AZIONE RICHIESTA:';
  RAISE NOTICE '   1. Fai LOGOUT dalla dashboard';
  RAISE NOTICE '   2. Fai HOT RESTART dell''app';
  RAISE NOTICE '   3. Effettua nuovamente il LOGIN con ospedale@prontorad.demo';
  RAISE NOTICE '   4. Prova a creare gli slot';
  RAISE NOTICE '============================================================';
END $$;
