-- Migration: Debug RLS policies for availability_slots
-- Date: 2026-01-19 30:00:00
-- This adds a temporary policy to allow authenticated users to insert slots for debugging

-- Add a temporary INSERT policy for all authenticated users
CREATE POLICY "Authenticated users can insert slots (DEBUG)"
  ON availability_slots FOR INSERT TO authenticated
  WITH CHECK (true);

-- Add a comment to remind to remove this later
COMMENT ON POLICY "Authenticated users can insert slots (DEBUG)" ON availability_slots 
  IS 'TEMPORARY DEBUG POLICY - Remove after fixing the real issue';
