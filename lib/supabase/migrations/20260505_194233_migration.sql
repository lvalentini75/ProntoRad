-- =====================================================
-- MIGRAZIONE: Ripristino ruoli utenti
-- =====================================================
-- 1. info@tatticaweb.it → end_user (utente normale)
-- 2. admin@prontorad.demo → super_admin (gestisce tutta la piattaforma)
-- =====================================================

-- STEP 1: Riporta info@tatticaweb.it a utente normale
UPDATE users
SET 
    role = 'end_user',
    organization_id = NULL,
    updated_at = NOW()
WHERE email = 'info@tatticaweb.it';

-- STEP 2: Assicura che admin@prontorad.demo sia super_admin
UPDATE users
SET 
    role = 'super_admin',
    updated_at = NOW()
WHERE email = 'admin@prontorad.demo';

-- STEP 3: Verifica le modifiche
DO $$
DECLARE
    v_tattica_role TEXT;
    v_admin_role TEXT;
BEGIN
    SELECT role INTO v_tattica_role FROM users WHERE email = 'info@tatticaweb.it';
    SELECT role INTO v_admin_role FROM users WHERE email = 'admin@prontorad.demo';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ RUOLI UTENTI AGGIORNATI:';
    RAISE NOTICE '   info@tatticaweb.it → %', COALESCE(v_tattica_role, 'NON TROVATO');
    RAISE NOTICE '   admin@prontorad.demo → %', COALESCE(v_admin_role, 'NON TROVATO');
    RAISE NOTICE '========================================';
END $$;
