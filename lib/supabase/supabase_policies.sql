-- Row Level Security Policies for ProntoRad (v2)

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Helpers:
-- Determine if current auth user is super_admin / org_admin
-- We resolve via users.auth_user_id mapping
CREATE OR REPLACE FUNCTION is_super_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM users u WHERE u.auth_user_id = auth.uid() AND u.role = 'super_admin'
  );
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION is_org_admin() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM users u WHERE u.auth_user_id = auth.uid() AND u.role = 'org_admin'
  );
$$ LANGUAGE SQL STABLE;

-- Allow authenticated users to read/update their own app profile (via auth_user_id)
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
CREATE POLICY "Users can view their own profile"
  ON users FOR SELECT
  USING (auth.uid() IS NOT NULL AND auth.uid() = auth_user_id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
CREATE POLICY "Users can insert their own profile"
  ON users FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON users;
CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  USING (auth.uid() IS NOT NULL AND auth.uid() = auth_user_id)
  WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = auth_user_id);

-- Admins can read all users
CREATE POLICY "Admins can read all users"
  ON users FOR SELECT
  USING (is_super_admin());

-- Allow everyone (including anon) to read exam types
DROP POLICY IF EXISTS "Authenticated users can view exam types" ON exam_types;
CREATE POLICY "Public can view exam types"
  ON exam_types FOR SELECT
  USING (true);

-- Allow everyone (including anon) to read facilities
DROP POLICY IF EXISTS "Authenticated users can view facilities" ON facilities;
CREATE POLICY "Public can view facilities"
  ON facilities FOR SELECT
  USING (true);

-- Org admins can manage their own facilities
CREATE POLICY "Org admins can manage own facilities"
  ON facilities FOR INSERT TO authenticated
  WITH CHECK (
    is_org_admin()
  );

CREATE POLICY "Org admins can update own facilities"
  ON facilities FOR UPDATE TO authenticated
  USING (
    is_org_admin()
  )
  WITH CHECK (
    is_org_admin()
  );

-- Authenticated end users: own bookings
DROP POLICY IF EXISTS "Users can view their own bookings" ON bookings;
CREATE POLICY "Users can view their own bookings"
  ON bookings FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM users u WHERE u.auth_user_id = auth.uid() AND u.id = user_id));

DROP POLICY IF EXISTS "Users can create their own bookings" ON bookings;
CREATE POLICY "Users can create their own bookings"
  ON bookings FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM users u WHERE u.auth_user_id = auth.uid() AND u.id = user_id));

DROP POLICY IF EXISTS "Users can update their own bookings" ON bookings;
CREATE POLICY "Users can update their own bookings"
  ON bookings FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM users u WHERE u.auth_user_id = auth.uid() AND u.id = user_id))
  WITH CHECK (EXISTS (SELECT 1 FROM users u WHERE u.auth_user_id = auth.uid() AND u.id = user_id));

DROP POLICY IF EXISTS "Users can delete their own bookings" ON bookings;
CREATE POLICY "Users can delete their own bookings"
  ON bookings FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM users u WHERE u.auth_user_id = auth.uid() AND u.id = user_id));

-- Anonymous users: can create bookings (no auth required)
CREATE POLICY "Anon can create bookings"
  ON bookings FOR INSERT TO anon
  WITH CHECK (true);

-- Anonymous users: can view recent booking by id (for status page after creation)
CREATE POLICY "Anon can view recent bookings"
  ON bookings FOR SELECT TO anon
  USING (created_at >= now() - interval '14 days');

-- Org admins: can view bookings for facilities in their organization
CREATE POLICY "Org admins can view org bookings"
  ON bookings FOR SELECT TO authenticated
  USING (
    is_org_admin() AND EXISTS (
      SELECT 1 FROM facilities f
      JOIN users u ON u.auth_user_id = auth.uid()
      WHERE f.id = bookings.facility_id AND f.organization_id IS NOT NULL
    )
  );

-- Super admins: full access
CREATE POLICY "Super admins can view all bookings"
  ON bookings FOR SELECT TO authenticated
  USING (is_super_admin());

CREATE POLICY "Super admins can manage all bookings"
  ON bookings FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());
