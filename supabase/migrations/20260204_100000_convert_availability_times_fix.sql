-- Migration: Convert start_time and end_time from TIMESTAMPTZ to TIME
-- This migration properly handles the dependent view availability_slots_with_org

DO $$
DECLARE
    start_time_type TEXT;
    end_time_type TEXT;
BEGIN
    -- Get current data types
    SELECT data_type INTO start_time_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'availability_slots'
    AND column_name = 'start_time';

    SELECT data_type INTO end_time_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'availability_slots'
    AND column_name = 'end_time';

    RAISE NOTICE '🔍 Current types: start_time=%, end_time=%', start_time_type, end_time_type;

    -- Only proceed if conversion is needed
    IF start_time_type = 'timestamp with time zone' OR end_time_type = 'timestamp with time zone' THEN
        RAISE NOTICE '🚀 Starting conversion...';

        -- Step 1: Drop the dependent view
        RAISE NOTICE '📋 Dropping view availability_slots_with_org...';
        DROP VIEW IF EXISTS availability_slots_with_org CASCADE;

        -- Step 2: Convert start_time if needed
        IF start_time_type = 'timestamp with time zone' THEN
            RAISE NOTICE '⏰ Converting start_time column...';
            
            -- Create temporary column
            ALTER TABLE availability_slots ADD COLUMN start_time_temp TIME;
            
            -- Copy data (extract time portion)
            UPDATE availability_slots 
            SET start_time_temp = start_time::TIME;
            
            -- Drop old column and rename new one
            ALTER TABLE availability_slots DROP COLUMN start_time;
            ALTER TABLE availability_slots RENAME COLUMN start_time_temp TO start_time;
            
            -- Add NOT NULL constraint
            ALTER TABLE availability_slots ALTER COLUMN start_time SET NOT NULL;
            
            RAISE NOTICE '✅ start_time converted to TIME';
        ELSE
            RAISE NOTICE '✅ start_time already TIME type';
        END IF;

        -- Step 3: Convert end_time if needed
        IF end_time_type = 'timestamp with time zone' THEN
            RAISE NOTICE '⏰ Converting end_time column...';
            
            -- Create temporary column
            ALTER TABLE availability_slots ADD COLUMN end_time_temp TIME;
            
            -- Copy data (extract time portion)
            UPDATE availability_slots 
            SET end_time_temp = end_time::TIME;
            
            -- Drop old column and rename new one
            ALTER TABLE availability_slots DROP COLUMN end_time;
            ALTER TABLE availability_slots RENAME COLUMN end_time_temp TO end_time;
            
            -- Add NOT NULL constraint
            ALTER TABLE availability_slots ALTER COLUMN end_time SET NOT NULL;
            
            RAISE NOTICE '✅ end_time converted to TIME';
        ELSE
            RAISE NOTICE '✅ end_time already TIME type';
        END IF;

        -- Step 4: Recreate indexes
        RAISE NOTICE '📊 Creating indexes...';
        
        DROP INDEX IF EXISTS idx_availability_slots_start_time;
        DROP INDEX IF EXISTS idx_availability_slots_end_time;
        
        CREATE INDEX idx_availability_slots_start_time ON availability_slots(start_time);
        CREATE INDEX idx_availability_slots_end_time ON availability_slots(end_time);
        
        RAISE NOTICE '✅ Indexes created';

        -- Step 5: Recreate the view with same definition
        RAISE NOTICE '📋 Recreating view availability_slots_with_org...';
        
        CREATE OR REPLACE VIEW availability_slots_with_org AS
        SELECT 
          s.*,
          o.name as organization_name,
          o.org_type as organization_type,
          COALESCE(e.name, s.exam_category) as exam_name,
          COALESCE(s.exam_category, e.category) as exam_category_resolved,
          e.body_district as exam_body_district
        FROM availability_slots s
        LEFT JOIN organizations o ON s.organization_id = o.id
        LEFT JOIN exam_types e ON s.exam_type_id = e.id;

        -- Grant access to the view
        GRANT SELECT ON availability_slots_with_org TO authenticated;
        GRANT SELECT ON availability_slots_with_org TO anon;
        
        RAISE NOTICE '✅ View recreated successfully';

        RAISE NOTICE '✨ Migration completed successfully!';
    ELSE
        RAISE NOTICE 'ℹ️  Columns already have TIME type, no conversion needed';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error during migration: %', SQLERRM;
        RAISE;
END $$;
