-- Test di accesso ai dati - Verifica che le RLS policies funzionino correttamente
-- Questa migrazione testa l'accesso simulando un utente autenticato

DO $$
DECLARE
    exam_count integer;
    org_count integer;
    tariff_count integer;
    booking_count integer;
    slot_count integer;
    test_user_id uuid;
    test_org_id uuid;
BEGIN
    RAISE NOTICE '═══════════════════════════════════════════';
    RAISE NOTICE '🧪 TEST ACCESSO DATI (senza RLS)';
    RAISE NOTICE '═══════════════════════════════════════════';
    
    -- Test 1: Conta exam_types (dovrebbe essere visibile a tutti)
    SELECT COUNT(*) INTO exam_count FROM exam_types;
    RAISE NOTICE '📊 Exam Types: % record', exam_count;
    
    IF exam_count = 0 THEN
        RAISE WARNING '⚠️  NESSUN EXAM TYPE TROVATO! Inserisci dati di test';
    END IF;
    
    -- Test 2: Conta organizations
    SELECT COUNT(*) INTO org_count FROM organizations;
    RAISE NOTICE '📊 Organizations: % record', org_count;
    
    IF org_count = 0 THEN
        RAISE WARNING '⚠️  NESSUNA ORGANIZATION TROVATA!';
    ELSE
        -- Prende la prima organization per i test
        SELECT id INTO test_org_id FROM organizations LIMIT 1;
        RAISE NOTICE 'ℹ️  Usando organization_id: %', test_org_id;
    END IF;
    
    -- Test 3: Conta tariffs
    SELECT COUNT(*) INTO tariff_count FROM tariffs;
    RAISE NOTICE '📊 Tariffs: % record', tariff_count;
    
    IF tariff_count = 0 THEN
        RAISE WARNING '⚠️  NESSUN TARIFF TROVATO!';
    END IF;
    
    -- Test 4: Conta availability_slots
    SELECT COUNT(*) INTO slot_count FROM availability_slots;
    RAISE NOTICE '📊 Availability Slots: % record', slot_count;
    
    IF slot_count = 0 THEN
        RAISE WARNING '⚠️  NESSUNO SLOT DISPONIBILE!';
    END IF;
    
    -- Test 5: Conta bookings
    SELECT COUNT(*) INTO booking_count FROM bookings;
    RAISE NOTICE '📊 Bookings: % record', booking_count;
    
    -- Test 6: Verifica utente ospedale@prontorad.demo
    SELECT id INTO test_user_id 
    FROM users 
    WHERE email = 'ospedale@prontorad.demo' 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE '✅ Utente ospedale@prontorad.demo trovato: %', test_user_id;
        
        -- Verifica organization dell'utente
        DECLARE
            user_org_id uuid;
            user_role text;
        BEGIN
            SELECT organization_id, role INTO user_org_id, user_role
            FROM users
            WHERE id = test_user_id;
            
            RAISE NOTICE '   - Organization ID: %', COALESCE(user_org_id::text, 'NULL');
            RAISE NOTICE '   - Role: %', COALESCE(user_role, 'NULL');
            
            IF user_org_id IS NULL THEN
                RAISE WARNING '⚠️  Utente NON ha organization_id assegnato!';
            END IF;
            
            IF user_role IS NULL OR user_role NOT IN ('org_admin', 'super_admin') THEN
                RAISE WARNING '⚠️  Utente NON è org_admin o super_admin!';
            END IF;
        END;
    ELSE
        RAISE WARNING '⚠️  Utente ospedale@prontorad.demo NON TROVATO!';
    END IF;
    
    RAISE NOTICE '═══════════════════════════════════════════';
    
    -- Test 7: Verifica policies su exam_types
    DECLARE
        policy_count integer;
        rec record;
    BEGIN
        SELECT COUNT(*) INTO policy_count
        FROM pg_policies 
        WHERE tablename = 'exam_types' AND schemaname = 'public';
        
        RAISE NOTICE '';
        RAISE NOTICE '🔒 RLS POLICIES su exam_types: %', policy_count;
        
        FOR rec IN 
            SELECT policyname, cmd
            FROM pg_policies 
            WHERE tablename = 'exam_types' AND schemaname = 'public'
        LOOP
            RAISE NOTICE '   - % (Command: %)', rec.policyname, rec.cmd;
        END LOOP;
    END;
    
    -- Test 8: Verifica policies su organizations
    DECLARE
        policy_count integer;
        rec record;
    BEGIN
        SELECT COUNT(*) INTO policy_count
        FROM pg_policies 
        WHERE tablename = 'organizations' AND schemaname = 'public';
        
        RAISE NOTICE '';
        RAISE NOTICE '🔒 RLS POLICIES su organizations: %', policy_count;
        
        FOR rec IN 
            SELECT policyname, cmd
            FROM pg_policies 
            WHERE tablename = 'organizations' AND schemaname = 'public'
        LOOP
            RAISE NOTICE '   - % (Command: %)', rec.policyname, rec.cmd;
        END LOOP;
    END;
    
    -- Test 9: Verifica policies su tariffs
    DECLARE
        policy_count integer;
        rec record;
    BEGIN
        SELECT COUNT(*) INTO policy_count
        FROM pg_policies 
        WHERE tablename = 'tariffs' AND schemaname = 'public';
        
        RAISE NOTICE '';
        RAISE NOTICE '🔒 RLS POLICIES su tariffs: %', policy_count;
        
        FOR rec IN 
            SELECT policyname, cmd
            FROM pg_policies 
            WHERE tablename = 'tariffs' AND schemaname = 'public'
        LOOP
            RAISE NOTICE '   - % (Command: %)', rec.policyname, rec.cmd;
        END LOOP;
    END;
    
    -- Test 10: Verifica policies su availability_slots
    DECLARE
        policy_count integer;
        rec record;
    BEGIN
        SELECT COUNT(*) INTO policy_count
        FROM pg_policies 
        WHERE tablename = 'availability_slots' AND schemaname = 'public';
        
        RAISE NOTICE '';
        RAISE NOTICE '🔒 RLS POLICIES su availability_slots: %', policy_count;
        
        FOR rec IN 
            SELECT policyname, cmd
            FROM pg_policies 
            WHERE tablename = 'availability_slots' AND schemaname = 'public'
        LOOP
            RAISE NOTICE '   - % (Command: %)', rec.policyname, rec.cmd;
        END LOOP;
    END;
    
    RAISE NOTICE '═══════════════════════════════════════════';
    RAISE NOTICE '✅ TEST COMPLETATO';
    RAISE NOTICE '═══════════════════════════════════════════';
    
END $$;
