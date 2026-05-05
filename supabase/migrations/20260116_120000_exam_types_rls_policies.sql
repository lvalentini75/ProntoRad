-- Migration: Add RLS policies for exam_types
-- Date: 2026-01-16 12:00:00
-- This migration adds RLS policies to allow super admins to manage exam types

-- Enable RLS on exam_types if not already enabled
ALTER TABLE exam_types ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Public can view exam types" ON exam_types;
DROP POLICY IF EXISTS "Super admins can manage exam types" ON exam_types;

-- Public can view all exam types (read-only)
CREATE POLICY "Public can view exam types"
  ON exam_types FOR SELECT
  USING (true);

-- Super admins can manage all exam types (insert, update, delete)
CREATE POLICY "Super admins can manage exam types"
  ON exam_types FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());
