-- ============================================================
-- RPC Functions per facility_exam_offerings
-- Bypassa il bug della cache schema di PostgREST (PGRST204)
-- ============================================================

-- Funzione per creare una nuova offerta esame
CREATE OR REPLACE FUNCTION create_facility_exam_offering(
    p_facility_id UUID,
    p_exam_type_id UUID,
    p_price DECIMAL DEFAULT 0,
    p_ssn_price DECIMAL DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result facility_exam_offerings%ROWTYPE;
BEGIN
    -- Verifica che l'utente sia autenticato
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Utente non autenticato';
    END IF;

    -- Inserisce la nuova offerta
    INSERT INTO facility_exam_offerings (
        facility_id,
        exam_type_id,
        price,
        ssn_price,
        is_available,
        created_at,
        updated_at
    )
    VALUES (
        p_facility_id,
        p_exam_type_id,
        p_price,
        p_ssn_price,
        TRUE,
        NOW(),
        NOW()
    )
    RETURNING * INTO v_result;

    -- Restituisce il risultato come JSON
    RETURN row_to_json(v_result);
END;
$$;

-- Funzione per eliminare un'offerta esame
CREATE OR REPLACE FUNCTION delete_facility_exam_offering(
    p_offering_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verifica che l'utente sia autenticato
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Utente non autenticato';
    END IF;

    -- Elimina l'offerta
    DELETE FROM facility_exam_offerings
    WHERE id = p_offering_id;

    RETURN TRUE;
END;
$$;

-- Grant esecuzione alle funzioni per utenti autenticati
GRANT EXECUTE ON FUNCTION create_facility_exam_offering(UUID, UUID, DECIMAL, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_facility_exam_offering(UUID) TO authenticated;
