-- Migration: Ensure RLS helper functions exist
-- Date: 2026-01-19 10:00:01
-- This migration creates the helper functions used by RLS policies

-- ============================================================================
-- Helper function: Check if current user is super admin
-- ============================================================================

CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE auth_user_id = auth.uid()
    AND role = 'super_admin'
  );
END;
$$;

-- ============================================================================
-- Helper function: Check if current user is org admin
-- ============================================================================

CREATE OR REPLACE FUNCTION is_org_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE auth_user_id = auth.uid()
    AND role IN ('org_admin', 'super_admin')
  );
END;
$$;

-- ============================================================================
-- Helper function: Get current user's organization_id
-- ============================================================================

CREATE OR REPLACE FUNCTION current_user_organization_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  org_id UUID;
BEGIN
  SELECT organization_id INTO org_id
  FROM users
  WHERE auth_user_id = auth.uid();
  
  RETURN org_id;
END;
$$;

-- ============================================================================
-- Helper function: Check if user can access organization
-- ============================================================================

CREATE OR REPLACE FUNCTION can_access_organization(target_org_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Super admins can access everything
  IF is_super_admin() THEN
    RETURN TRUE;
  END IF;
  
  -- Org admins can only access their own organization
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE auth_user_id = auth.uid()
    AND organization_id = target_org_id
    AND role IN ('org_admin', 'super_admin')
  );
END;
$$;
