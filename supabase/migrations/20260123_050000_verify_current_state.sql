-- MIGRATION DI VERIFICA - Controlla lo stato attuale del database
-- Questa migrazione NON modifica nulla, solo verifica e mostra informazioni

-- Verifica 1: Controlla se la colonna exam_id esiste ancora
DO $$
DECLARE
    exam_id_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'availability_slots' 
        AND column_name = 'exam_id'
        AND table_schema = 'public'
    ) INTO exam_id_exists;
    
    IF exam_id_exists THEN
        RAISE NOTICE '⚠️  TROVATA colonna exam_id in availability_slots - DEVE essere rimossa';
    ELSE
        RAISE NOTICE '✅ Colonna exam_id NON esiste (già rimossa o mai esistita)';
    END IF;
END $$;

-- Verifica 2: Controlla le policies su exam_types
DO $$
DECLARE
    policy_count integer;
    rec record;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies 
    WHERE tablename = 'exam_types' AND schemaname = 'public';
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📋 Policies su exam_types: % trovate', policy_count;
    
    FOR rec IN 
        SELECT policyname, cmd, qual::text as using_clause
        FROM pg_policies 
        WHERE tablename = 'exam_types' AND schemaname = 'public'
    LOOP
        RAISE NOTICE '  - Policy: % (Command: %)', rec.policyname, rec.cmd;
    END LOOP;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- Verifica 3: Conta i record in ciascuna tabella
DO $$
DECLARE
    exam_count integer;
    org_count integer;
    tariff_count integer;
    slot_count integer;
    booking_count integer;
BEGIN
    SELECT COUNT(*) INTO exam_count FROM exam_types;
    SELECT COUNT(*) INTO org_count FROM organizations;
    SELECT COUNT(*) INTO tariff_count FROM tariffs;
    SELECT COUNT(*) INTO slot_count FROM availability_slots;
    SELECT COUNT(*) INTO booking_count FROM bookings;
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📊 CONTEGGIO DATI ATTUALI:';
    RAISE NOTICE '  - Exam Types: %', exam_count;
    RAISE NOTICE '  - Organizations: %', org_count;
    RAISE NOTICE '  - Tariffs: %', tariff_count;
    RAISE NOTICE '  - Availability Slots: %', slot_count;
    RAISE NOTICE '  - Bookings: %', booking_count;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- Verifica 4: Controlla se ci sono slot con exam_type_id NULL
DO $$
DECLARE
    null_count integer;
BEGIN
    SELECT COUNT(*) INTO null_count 
    FROM availability_slots 
    WHERE exam_type_id IS NULL;
    
    IF null_count > 0 THEN
        RAISE WARNING '⚠️  ATTENZIONE: % slot hanno exam_type_id NULL - saranno eliminati!', null_count;
    ELSE
        RAISE NOTICE '✅ Tutti gli slot hanno exam_type_id valido';
    END IF;
END $$;

-- Verifica 5: Controlla la VIEW availability_slots_with_org
DO $$
DECLARE
    view_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'availability_slots_with_org'
        AND table_schema = 'public'
    ) INTO view_exists;
    
    IF view_exists THEN
        RAISE NOTICE '✅ VIEW availability_slots_with_org esiste (sarà ricreata)';
    ELSE
        RAISE NOTICE 'ℹ️  VIEW availability_slots_with_org NON esiste (sarà creata)';
    END IF;
END $$;

-- RIEPILOGO FINALE
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '═══════════════════════════════════════════';
    RAISE NOTICE '✅ VERIFICA COMPLETATA';
    RAISE NOTICE '═══════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📝 COSA FARANNO LE PROSSIME MIGRAZIONI:';
    RAISE NOTICE '';
    RAISE NOTICE '1️⃣  Remove duplicate exam_id (se esiste)';
    RAISE NOTICE '   - Elimina VIEW dipendente';
    RAISE NOTICE '   - Rimuove colonna exam_id';
    RAISE NOTICE '   - Ricrea VIEW con exam_type_id';
    RAISE NOTICE '';
    RAISE NOTICE '2️⃣  Fix exam_types RLS policies';
    RAISE NOTICE '   - Permette a TUTTI di leggere exam_types';
    RAISE NOTICE '   - Solo super_admin può modificare';
    RAISE NOTICE '';
    RAISE NOTICE '3️⃣  Fix organization-related RLS';
    RAISE NOTICE '   - org_admin può gestire i suoi dati';
    RAISE NOTICE '   - Utenti vedono le proprie prenotazioni';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  NESSUN DATO SARÀ PERSO (tranne slot NULL)';
    RAISE NOTICE '═══════════════════════════════════════════';
END $$;
