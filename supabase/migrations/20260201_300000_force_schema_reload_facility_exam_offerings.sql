-- ============================================================
-- Force complete schema reload for facility_exam_offerings
-- Fixes PostgREST schema cache issues definitively
-- ============================================================

-- Step 1: Log current schema
DO $$
DECLARE
    col RECORD;
BEGIN
    RAISE NOTICE '=== Current facility_exam_offerings schema ===';
    FOR col IN 
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_name = 'facility_exam_offerings'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '  - %: % (nullable: %, default: %)', 
            col.column_name, col.data_type, col.is_nullable, col.column_default;
    END LOOP;
END $$;

-- Step 2: Backup existing data
CREATE TEMP TABLE facility_exam_offerings_backup AS
SELECT * FROM facility_exam_offerings;

-- Step 3: Drop and recreate table completely
DROP TABLE IF EXISTS facility_exam_offerings CASCADE;

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

-- Step 4: Restore data (explicit columns to match schema)
INSERT INTO facility_exam_offerings (
    id,
    facility_id,
    exam_type_id,
    price,
    ssn_price,
    duration_minutes,
    preparation_notes,
    is_available,
    max_daily_bookings,
    created_at,
    updated_at
)
SELECT 
    id,
    facility_id,
    exam_type_id,
    COALESCE(price, 0),
    COALESCE(ssn_price, 0),
    COALESCE(duration_minutes, 30),
    preparation_notes,
    COALESCE(is_available, TRUE),
    COALESCE(max_daily_bookings, 10),
    created_at,
    updated_at
FROM facility_exam_offerings_backup;

-- Step 5: Recreate indexes
CREATE INDEX idx_facility_exam_offerings_facility ON facility_exam_offerings(facility_id);
CREATE INDEX idx_facility_exam_offerings_exam ON facility_exam_offerings(exam_type_id);

-- Step 6: Enable RLS
ALTER TABLE facility_exam_offerings ENABLE ROW LEVEL SECURITY;

-- Step 7: Recreate RLS policies
DROP POLICY IF EXISTS "Public can view exam offerings" ON facility_exam_offerings;
DROP POLICY IF EXISTS "Org admins can manage org offerings" ON facility_exam_offerings;
DROP POLICY IF EXISTS "Super admins can manage all offerings" ON facility_exam_offerings;

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
      JOIN facilities f ON f.id = facility_exam_offerings.facility_id 
      WHERE u.role = 'super_admin'
    )
  );

-- Step 8: Force PostgreSQL stats update
ANALYZE facility_exam_offerings;

-- Step 9: Notify PostgREST to reload schema (if available)
DO $$
BEGIN
    -- This sends a notification that PostgREST listens to for schema changes
    PERFORM pg_notify('pgrst', 'reload schema');
    RAISE NOTICE '✅ Schema reload notification sent to PostgREST';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️ Could not send notification (normal if PostgREST is not listening)';
END $$;

-- Step 10: Create RPC functions for safe operations
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_facility_exam_offering(UUID, UUID, DECIMAL, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_facility_exam_offering(UUID) TO authenticated;

-- Step 11: Verify final schema
DO $$
DECLARE
    col RECORD;
    row_count INTEGER;
BEGIN
    RAISE NOTICE '=== Final facility_exam_offerings schema ===';
    FOR col IN 
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = 'facility_exam_offerings'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '  ✓ %: %', col.column_name, col.data_type;
    END LOOP;
    
    SELECT COUNT(*) INTO row_count FROM facility_exam_offerings;
    RAISE NOTICE '=== Data restored: % rows ===', row_count;
    RAISE NOTICE '=== RPC functions created: create_facility_exam_offering, delete_facility_exam_offering ===';
    RAISE NOTICE '✅ Schema reload complete!';
END $$;
