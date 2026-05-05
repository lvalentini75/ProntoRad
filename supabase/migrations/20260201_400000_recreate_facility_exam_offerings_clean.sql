-- ============================================================
-- Recreate facility_exam_offerings table cleanly
-- Fixes PostgREST schema cache by starting fresh
-- ============================================================

-- Step 1: Drop old table completely (no data restore - incompatible schema)
DROP TABLE IF EXISTS facility_exam_offerings CASCADE;

-- Step 2: Create table with correct schema
CREATE TABLE facility_exam_offerings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
    exam_type_id UUID NOT NULL REFERENCES exam_types(id) ON DELETE CASCADE,
    price DOUBLE PRECISION NOT NULL DEFAULT 0,
    ssn_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    duration_minutes INTEGER NOT NULL DEFAULT 30,
    preparation_notes TEXT,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    max_daily_bookings INTEGER NOT NULL DEFAULT 10,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(facility_id, exam_type_id)
);

-- Step 3: Create indexes
CREATE INDEX idx_facility_exam_offerings_facility ON facility_exam_offerings(facility_id);
CREATE INDEX idx_facility_exam_offerings_exam ON facility_exam_offerings(exam_type_id);

-- Step 4: Enable RLS
ALTER TABLE facility_exam_offerings ENABLE ROW LEVEL SECURITY;

-- Step 5: Create RLS policies
CREATE POLICY "Public can view exam offerings"
  ON facility_exam_offerings FOR SELECT
  USING (TRUE);

CREATE POLICY "Org admins can manage org offerings"
  ON facility_exam_offerings FOR ALL TO authenticated
  USING (
    auth.uid() IN (
      SELECT u.id FROM users u
      JOIN facilities f ON f.organization_id = u.organization_id
      WHERE f.id = facility_exam_offerings.facility_id 
        AND u.role = 'org_admin'
    )
  );

CREATE POLICY "Super admins can manage all offerings"
  ON facility_exam_offerings FOR ALL TO authenticated
  USING (
    auth.uid() IN (
      SELECT u.id FROM users u
      WHERE u.role = 'super_admin'
    )
  );

-- Step 6: Create RPC functions for safe operations
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
    -- Verifica autenticazione
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Utente non autenticato';
    END IF;

    -- Inserisce con colonne esplicite
    INSERT INTO facility_exam_offerings (
        facility_id,
        exam_type_id,
        price,
        ssn_price,
        duration_minutes,
        is_available,
        max_daily_bookings,
        created_at,
        updated_at
    )
    VALUES (
        p_facility_id,
        p_exam_type_id,
        p_price,
        p_ssn_price,
        30,
        TRUE,
        10,
        NOW(),
        NOW()
    )
    RETURNING * INTO v_result;

    RETURN row_to_json(v_result);
END;
$$;

CREATE OR REPLACE FUNCTION delete_facility_exam_offering(
    p_offering_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Utente non autenticato';
    END IF;

    DELETE FROM facility_exam_offerings
    WHERE id = p_offering_id;

    RETURN TRUE;
END;
$$;

-- Step 7: Grant permissions
GRANT EXECUTE ON FUNCTION create_facility_exam_offering(UUID, UUID, DECIMAL, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_facility_exam_offering(UUID) TO authenticated;

-- Step 8: Force PostgreSQL stats update
ANALYZE facility_exam_offerings;

-- Step 9: Notify PostgREST to reload schema
DO $$
BEGIN
    PERFORM pg_notify('pgrst', 'reload schema');
    RAISE NOTICE '✅ Schema recreated and PostgREST notified';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Could not send notification (normal if PostgREST is not listening)';
END $$;

-- Step 10: Log result
DO $$
DECLARE
    col RECORD;
BEGIN
    RAISE NOTICE '=== facility_exam_offerings schema ===';
    FOR col IN 
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = 'facility_exam_offerings'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '  ✓ %: %', col.column_name, col.data_type;
    END LOOP;
    RAISE NOTICE '✅ Table recreated successfully - ready for new offerings!';
END $$;
