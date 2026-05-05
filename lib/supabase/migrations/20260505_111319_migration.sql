-- ============================================================================
-- MIGRATION: Allow org_admin to read patients with bookings in their organization
-- ============================================================================
-- Problem: org_admin can only see users in their organization, but patients
-- who book exams don't have organization_id set (they are independent end_users).
-- Solution: Add a policy that allows org_admin to read users who have bookings
-- at their organization.
-- ============================================================================

-- ============================================================================
-- STEP 1: Create helper function to check if user has booking at organization
-- ============================================================================
DROP FUNCTION IF EXISTS user_has_booking_at_organization(UUID, UUID);
CREATE OR REPLACE FUNCTION user_has_booking_at_organization(p_user_id UUID, p_org_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM bookings 
    WHERE user_id = p_user_id 
    AND organization_id = p_org_id
    LIMIT 1
  );
$$;

-- ============================================================================
-- STEP 2: Create policy for org_admin to read patients with bookings
-- ============================================================================
DROP POLICY IF EXISTS "select_patients_with_bookings_if_org_admin" ON users;

CREATE POLICY "select_patients_with_bookings_if_org_admin"
ON users FOR SELECT
TO authenticated
USING (
  get_my_role() = 'org_admin'
  AND get_my_organization_id() IS NOT NULL
  AND user_has_booking_at_organization(id, get_my_organization_id())
);

-- ============================================================================
-- STEP 3: Also allow super_admin to use the function
-- ============================================================================
GRANT EXECUTE ON FUNCTION user_has_booking_at_organization(UUID, UUID) TO authenticated;

-- ============================================================================
-- Success message
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '✅ PATIENTS VISIBILITY FIX FOR ORG_ADMIN APPLIED';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '';
  RAISE NOTICE '🔧 Changes:';
  RAISE NOTICE '   - Created user_has_booking_at_organization() function';
  RAISE NOTICE '   - Created select_patients_with_bookings_if_org_admin policy';
  RAISE NOTICE '   - org_admin can now see patient data for their bookings';
  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
END $$;
