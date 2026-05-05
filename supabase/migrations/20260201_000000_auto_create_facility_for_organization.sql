-- Migration: Auto-create facility for each organization
-- Date: 2026-02-01 00:00:00
-- Purpose: Ensure every organization has exactly one main facility

-- ============================================================================
-- SECTION 1: Create facilities for existing organizations without one
-- ============================================================================

INSERT INTO facilities (
  id,
  organization_id,
  name,
  address,
  city,
  province,
  region,
  latitude,
  longitude,
  type,
  available_exam_ids,
  base_price,
  created_at,
  updated_at
)
SELECT 
  gen_random_uuid(),
  o.id,
  o.name,
  COALESCE(o.address, ''),
  COALESCE(o.city, ''),
  COALESCE(o.province, ''),
  COALESCE(o.region, ''),
  COALESCE(o.latitude, 45.4642),
  COALESCE(o.longitude, 9.1900),
  'public',
  ARRAY[]::text[],
  120.0,
  NOW(),
  NOW()
FROM organizations o
WHERE NOT EXISTS (
  SELECT 1 FROM facilities f 
  WHERE f.organization_id = o.id
);

-- ============================================================================
-- SECTION 2: Create function to auto-create facility on organization insert
-- ============================================================================

CREATE OR REPLACE FUNCTION auto_create_facility_for_organization()
RETURNS TRIGGER AS $$
BEGIN
  -- Create a default facility for the new organization
  INSERT INTO facilities (
    organization_id,
    name,
    address,
    city,
    province,
    region,
    latitude,
    longitude,
    type,
    available_exam_ids,
    base_price,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    NEW.name,
    COALESCE(NEW.address, ''),
    COALESCE(NEW.city, ''),
    COALESCE(NEW.province, ''),
    COALESCE(NEW.region, ''),
    COALESCE(NEW.latitude, 45.4642),
    COALESCE(NEW.longitude, 9.1900),
    'public',
    ARRAY[]::text[],
    120.0,
    NOW(),
    NOW()
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- SECTION 3: Create trigger on organizations table
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_auto_create_facility ON organizations;

CREATE TRIGGER trigger_auto_create_facility
  AFTER INSERT ON organizations
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_facility_for_organization();

-- ============================================================================
-- SECTION 4: Create helper function to get organization's main facility
-- ============================================================================

CREATE OR REPLACE FUNCTION get_organization_facility_id(org_id UUID)
RETURNS UUID AS $$
DECLARE
  facility_id UUID;
BEGIN
  -- Get the first (main) facility for this organization
  SELECT id INTO facility_id
  FROM facilities
  WHERE organization_id = org_id
  LIMIT 1;
  
  RETURN facility_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_organization_facility_id IS 
'Returns the main facility ID for a given organization. Every organization is guaranteed to have at least one facility.';
