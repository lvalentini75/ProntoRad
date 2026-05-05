-- Fix availability_slots insert issues
-- Drop existing debug policy if it exists
DROP POLICY IF EXISTS "Authenticated users can insert slots (DEBUG)" ON availability_slots;

-- Ensure all columns have proper defaults and nullable settings
ALTER TABLE availability_slots 
  ALTER COLUMN specific_date DROP NOT NULL,
  ALTER COLUMN day_of_week DROP NOT NULL,
  ALTER COLUMN max_bookings SET DEFAULT 1,
  ALTER COLUMN organization_id DROP NOT NULL,
  ALTER COLUMN exam_type_id DROP NOT NULL;

-- Add a comprehensive insert policy for authenticated users
CREATE POLICY "Allow authenticated insert availability_slots"
ON availability_slots
FOR INSERT
TO authenticated
WITH CHECK (
  -- Users can insert if they belong to the organization
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = auth.uid()
    AND u.organization_id = availability_slots.organization_id
  )
);

-- Add a select policy for authenticated users to view slots
DROP POLICY IF EXISTS "Allow authenticated select availability_slots" ON availability_slots;
CREATE POLICY "Allow authenticated select availability_slots"
ON availability_slots
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = auth.uid()
    AND u.organization_id = availability_slots.organization_id
  )
);

-- Ensure the organization_id column has an index for performance
CREATE INDEX IF NOT EXISTS idx_availability_slots_organization_id 
ON availability_slots(organization_id);

-- Ensure exam_type_id is properly indexed
CREATE INDEX IF NOT EXISTS idx_availability_slots_exam_type_id 
ON availability_slots(exam_type_id);
