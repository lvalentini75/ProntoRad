-- Fix RLS policies for organization-related tables
-- Ensures org_admin users can access their organization's data

-- ==============================================================================
-- ORGANIZATIONS TABLE
-- ==============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Org admins can view their organization" ON organizations;
DROP POLICY IF EXISTS "Org admins can update their organization" ON organizations;
DROP POLICY IF EXISTS "Super admins can view all organizations" ON organizations;
DROP POLICY IF EXISTS "Super admins full access" ON organizations;
DROP POLICY IF EXISTS "Anyone can view organizations" ON organizations;

-- Enable RLS
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

-- Anyone can view organizations (needed for public booking interface)
CREATE POLICY "Anyone can view organizations"
ON organizations
FOR SELECT
USING (true);

-- Org admins can update their own organization
CREATE POLICY "Org admins can update their organization"
ON organizations
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.organization_id = organizations.id
    AND users.role = 'org_admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.organization_id = organizations.id
    AND users.role = 'org_admin'
  )
);

-- Super admins have full access
CREATE POLICY "Super admins full access to organizations"
ON organizations
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.role = 'super_admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.role = 'super_admin'
  )
);

-- ==============================================================================
-- TARIFFS TABLE
-- ==============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can view tariffs" ON tariffs;
DROP POLICY IF EXISTS "Org admins can manage tariffs" ON tariffs;
DROP POLICY IF EXISTS "Super admins full access to tariffs" ON tariffs;

-- Enable RLS
ALTER TABLE tariffs ENABLE ROW LEVEL SECURITY;

-- Anyone can view tariffs (needed for pricing display)
CREATE POLICY "Anyone can view tariffs"
ON tariffs
FOR SELECT
USING (true);

-- Org admins can manage their organization's tariffs
CREATE POLICY "Org admins can manage their tariffs"
ON tariffs
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.organization_id = tariffs.organization_id
    AND users.role IN ('org_admin', 'super_admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.organization_id = tariffs.organization_id
    AND users.role IN ('org_admin', 'super_admin')
  )
);

-- ==============================================================================
-- AVAILABILITY_SLOTS TABLE
-- ==============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can view availability slots" ON availability_slots;
DROP POLICY IF EXISTS "Org staff can manage slots" ON availability_slots;
DROP POLICY IF EXISTS "Allow authenticated insert availability_slots" ON availability_slots;
DROP POLICY IF EXISTS "Allow authenticated select availability_slots" ON availability_slots;

-- Enable RLS
ALTER TABLE availability_slots ENABLE ROW LEVEL SECURITY;

-- Anyone can view available slots (needed for booking interface)
CREATE POLICY "Anyone can view availability slots"
ON availability_slots
FOR SELECT
USING (true);

-- Org admins and staff can manage their organization's slots
CREATE POLICY "Org staff can manage their availability slots"
ON availability_slots
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.organization_id = availability_slots.organization_id
    AND users.role IN ('org_admin', 'super_admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.organization_id = availability_slots.organization_id
    AND users.role IN ('org_admin', 'super_admin')
  )
);

-- ==============================================================================
-- BOOKINGS TABLE
-- ==============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own bookings" ON bookings;
DROP POLICY IF EXISTS "Org staff can view org bookings" ON bookings;
DROP POLICY IF EXISTS "Anyone can create bookings" ON bookings;
DROP POLICY IF EXISTS "Org staff can update org bookings" ON bookings;
DROP POLICY IF EXISTS "Allow booking insert for authenticated" ON bookings;
DROP POLICY IF EXISTS "Allow booking insert for anon" ON bookings;

-- Enable RLS
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- End users can view their own bookings
CREATE POLICY "Users can view their own bookings"
ON bookings
FOR SELECT
TO authenticated
USING (
  user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
);

-- Org admins can view all bookings for their organization
CREATE POLICY "Org admins can view their org bookings"
ON bookings
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.organization_id = bookings.organization_id
    AND users.role IN ('org_admin', 'super_admin')
  )
);

-- Anyone can create bookings (both authenticated and anonymous)
CREATE POLICY "Anyone can create bookings"
ON bookings
FOR INSERT
WITH CHECK (true);

-- Org admins can update bookings for their organization
CREATE POLICY "Org admins can update their org bookings"
ON bookings
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.organization_id = bookings.organization_id
    AND users.role IN ('org_admin', 'super_admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.auth_user_id = auth.uid()
    AND users.organization_id = bookings.organization_id
    AND users.role IN ('org_admin', 'super_admin')
  )
);

-- Users can update their own bookings (for cancellation)
CREATE POLICY "Users can cancel their own bookings"
ON bookings
FOR UPDATE
TO authenticated
USING (
  user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
  AND status IN ('requested', 'confirmed')
)
WITH CHECK (
  user_id IN (
    SELECT id FROM users WHERE auth_user_id = auth.uid()
  )
  AND status IN ('requested', 'confirmed', 'cancelled')
);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ All organization-related RLS policies fixed';
  RAISE NOTICE '   - Organizations: Anyone can view, org_admin can update';
  RAISE NOTICE '   - Tariffs: Anyone can view, org_admin can manage';
  RAISE NOTICE '   - Availability: Anyone can view, org_admin can manage';
  RAISE NOTICE '   - Bookings: Users see own, org_admin sees org, anyone can create';
END $$;
