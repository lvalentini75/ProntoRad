-- Remove duplicate exam_id column from availability_slots
-- This migration standardizes the schema to use only exam_type_id

-- Step 1: Drop any views that depend on exam_id column
DROP VIEW IF EXISTS availability_slots_with_org CASCADE;

-- Step 2: Drop the foreign key constraint for exam_id
ALTER TABLE availability_slots
DROP CONSTRAINT IF EXISTS availability_slots_exam_id_fkey;

-- Step 3: Copy any data from exam_id to exam_type_id if exam_type_id is null
-- Only if the exam_id column actually exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'availability_slots' 
    AND column_name = 'exam_id'
    AND table_schema = 'public'
  ) THEN
    UPDATE availability_slots
    SET exam_type_id = exam_id
    WHERE exam_type_id IS NULL AND exam_id IS NOT NULL;
    RAISE NOTICE 'Copied data from exam_id to exam_type_id';
  ELSE
    RAISE NOTICE 'Column exam_id does not exist, skipping data copy';
  END IF;
END $$;

-- Step 4: Drop the exam_id column completely (only if it exists)
ALTER TABLE availability_slots
DROP COLUMN IF EXISTS exam_id;

-- Step 5: Delete any orphaned slots without exam_type_id (data cleanup)
DELETE FROM availability_slots
WHERE exam_type_id IS NULL;

-- Step 6: Ensure exam_type_id is NOT NULL (standard requirement)
ALTER TABLE availability_slots
ALTER COLUMN exam_type_id SET NOT NULL;

-- Step 7: Recreate the view if it was being used (now using exam_type_id)
CREATE OR REPLACE VIEW availability_slots_with_org AS
SELECT 
  s.*,
  o.name as organization_name,
  o.org_type as organization_type,
  e.name as exam_name,
  e.category as exam_category,
  e.body_district as exam_body_district
FROM availability_slots s
LEFT JOIN organizations o ON s.organization_id = o.id
LEFT JOIN exam_types e ON s.exam_type_id = e.id;

-- Grant access to the view
GRANT SELECT ON availability_slots_with_org TO authenticated;
GRANT SELECT ON availability_slots_with_org TO anon;

-- Step 8: Verify the foreign key for exam_type_id exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'availability_slots_exam_type_id_fkey'
    AND table_name = 'availability_slots'
  ) THEN
    ALTER TABLE availability_slots
    ADD CONSTRAINT availability_slots_exam_type_id_fkey
    FOREIGN KEY (exam_type_id) REFERENCES exam_types(id);
  END IF;
END $$;

-- Step 9: Ensure index exists for performance
CREATE INDEX IF NOT EXISTS idx_availability_slots_exam_type_id 
ON availability_slots(exam_type_id);

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Migration completed: exam_id column removed, exam_type_id is now the standard';
  RAISE NOTICE 'View availability_slots_with_org recreated using exam_type_id';
END $$;
