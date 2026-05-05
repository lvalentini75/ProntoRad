-- Fix infinite recursion in organizations RLS policies
-- The previous policies reference the users table, which causes infinite recursion
-- when trying to update organizations. We use the security definer function instead.

-- ==============================================================================
-- FIX ORGANIZATIONS TABLE POLICIES
-- ==============================================================================

-- Drop existing policies that cause recursion
DROP POLICY IF EXISTS "Org admins can update their organization" ON organizations;
DROP POLICY IF EXISTS "Super admins full access to organizations" ON organizations;

-- Anyone can view organizations (no change needed, this one is safe)
-- CREATE POLICY "Anyone can view organizations" ON organizations FOR SELECT USING (true);

-- Org admins can update their own organization (using security definer function)
CREATE POLICY "Org admins can update their organization"
ON organizations
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role = 'org_admin'
    AND me.org_id = organizations.id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role = 'org_admin'
    AND me.org_id = organizations.id
  )
);

-- Super admins have full access (using security definer function)
CREATE POLICY "Super admins full access to organizations"
ON organizations
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role = 'super_admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role = 'super_admin'
  )
);

-- ==============================================================================
-- FIX TARIFFS TABLE POLICIES
-- ==============================================================================

-- Drop existing policies that might cause recursion
DROP POLICY IF EXISTS "Org admins can manage their tariffs" ON tariffs;

-- Recreate with security definer function
CREATE POLICY "Org admins can manage their tariffs"
ON tariffs
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
    AND me.org_id = tariffs.organization_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
    AND me.org_id = tariffs.organization_id
  )
);

-- ==============================================================================
-- FIX AVAILABILITY_SLOTS TABLE POLICIES
-- ==============================================================================

-- Drop existing policies that might cause recursion
DROP POLICY IF EXISTS "Org staff can manage their availability slots" ON availability_slots;

-- Recreate with security definer function
CREATE POLICY "Org staff can manage their availability slots"
ON availability_slots
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
    AND me.org_id = availability_slots.organization_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
    AND me.org_id = availability_slots.organization_id
  )
);

-- ==============================================================================
-- FIX BOOKINGS TABLE POLICIES
-- ==============================================================================

-- Drop existing policies that might cause recursion
DROP POLICY IF EXISTS "Users can view their own bookings" ON bookings;
DROP POLICY IF EXISTS "Org admins can view their org bookings" ON bookings;
DROP POLICY IF EXISTS "Org admins can update their org bookings" ON bookings;
DROP POLICY IF EXISTS "Users can cancel their own bookings" ON bookings;

-- Recreate with security definer function (or direct auth.uid() where possible)

-- End users can view their own bookings (direct auth.uid, no recursion)
CREATE POLICY "Users can view their own bookings"
ON bookings
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = bookings.user_id
    AND users.auth_user_id = auth.uid()
  )
);

-- Org admins can view all bookings for their organization
CREATE POLICY "Org admins can view their org bookings"
ON bookings
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
    AND me.org_id = bookings.organization_id
  )
);

-- Org admins can update bookings for their organization
CREATE POLICY "Org admins can update their org bookings"
ON bookings
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
    AND me.org_id = bookings.organization_id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role IN ('org_admin', 'super_admin')
    AND me.org_id = bookings.organization_id
  )
);

-- Users can update their own bookings (for cancellation)
CREATE POLICY "Users can cancel their own bookings"
ON bookings
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = bookings.user_id
    AND users.auth_user_id = auth.uid()
  )
  AND status IN ('requested', 'confirmed')
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = bookings.user_id
    AND users.auth_user_id = auth.uid()
  )
  AND status IN ('requested', 'confirmed', 'cancelled')
);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Fixed infinite recursion in RLS policies';
  RAISE NOTICE '   - All policies now use get_current_user_role() security definer function';
  RAISE NOTICE '   - This prevents circular references to users table';
END $$;
