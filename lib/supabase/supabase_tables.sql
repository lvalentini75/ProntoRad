-- ProntoRad Database Schema (v2)
-- Medical radiographic exam booking system with multi‑level access

-- App users table (can exist with or without Supabase Auth linkage)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id UUID NULL UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  role TEXT NOT NULL DEFAULT 'end_user' CHECK (role IN ('super_admin','org_admin','end_user')),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone_number TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- If users table already existed from an older schema, ensure the new column exists
ALTER TABLE IF EXISTS users
  ADD COLUMN IF NOT EXISTS auth_user_id UUID NULL;

-- Ensure FK exists when upgrading older schemas (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_auth_user_id_fkey'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT users_auth_user_id_fkey
      FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Organizations (Hospitals/Institutes)
CREATE TABLE IF NOT EXISTS organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  org_type TEXT NOT NULL CHECK (org_type IN ('hospital','institute')),
  address TEXT,
  city TEXT,
  province TEXT,
  region TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS exam_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('rm', 'tac', 'eco', 'rx')),
  body_district TEXT NOT NULL CHECK (body_district IN ('testa', 'torace', 'addome', 'estremita')),
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Facilities table
CREATE TABLE IF NOT EXISTS facilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  province TEXT NOT NULL,
  region TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('private', 'public')),
  available_exam_ids TEXT[] NOT NULL DEFAULT '{}',
  base_price DOUBLE PRECISION NOT NULL,
  organization_id UUID NULL REFERENCES organizations(id) ON DELETE SET NULL,
  -- Optional parent facility id: when set, this facility is a Branch (Filiale)
  parent_facility_id UUID NULL REFERENCES facilities(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Patch: if facilities existed before organizations support, ensure column + FK exist
ALTER TABLE IF EXISTS facilities
  ADD COLUMN IF NOT EXISTS organization_id UUID NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'facilities_organization_id_fkey'
  ) THEN
    ALTER TABLE facilities
      ADD CONSTRAINT facilities_organization_id_fkey
      FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Patch: ensure parent_facility_id exists and has FK for hierarchical branches
ALTER TABLE IF EXISTS facilities
  ADD COLUMN IF NOT EXISTS parent_facility_id UUID NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'facilities_parent_facility_id_fkey'
  ) THEN
    ALTER TABLE facilities
      ADD CONSTRAINT facilities_parent_facility_id_fkey
      FOREIGN KEY (parent_facility_id) REFERENCES facilities(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  exam_type_id UUID NOT NULL REFERENCES exam_types(id) ON DELETE RESTRICT,
  facility_id UUID NOT NULL REFERENCES facilities(id) ON DELETE RESTRICT,
  booking_date TIMESTAMPTZ NOT NULL,
  booking_time TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('requested', 'confirmed', 'cancelled')) DEFAULT 'requested',
  urgency_level TEXT NOT NULL CHECK (urgency_level IN ('normal', 'urgent', 'veryUrgent')) DEFAULT 'normal',
  price DOUBLE PRECISION NOT NULL,
  needs_transport BOOLEAN DEFAULT FALSE,
  is_home_service BOOLEAN DEFAULT FALSE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_exam_types_category ON exam_types(category);
CREATE INDEX IF NOT EXISTS idx_exam_types_body_district ON exam_types(body_district);
CREATE INDEX IF NOT EXISTS idx_facilities_region ON facilities(region);
CREATE INDEX IF NOT EXISTS idx_facilities_province ON facilities(province);
CREATE INDEX IF NOT EXISTS idx_facilities_city ON facilities(city);
CREATE INDEX IF NOT EXISTS idx_facilities_type ON facilities(type);
CREATE INDEX IF NOT EXISTS idx_facilities_org ON facilities(organization_id);
CREATE INDEX IF NOT EXISTS idx_facilities_parent ON facilities(parent_facility_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_booking_date ON bookings(booking_date);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);

-- Seed data (exam types and a few facilities)
-- Exam types
INSERT INTO exam_types (name, category, body_district, description)
VALUES
('RM Cervello', 'rm', 'testa', 'Risonanza magnetica encefalo'),
('RM Colonna Lombare', 'rm', 'estremita', 'Risonanza magnetica colonna lombare'),
('TAC Torace', 'tac', 'torace', 'Tomografia del torace ad alta risoluzione'),
('TAC Addome Completo', 'tac', 'addome', 'Tomografia addome completo con contrasto'),
('ECO Addome', 'eco', 'addome', 'Ecografia addome completo'),
('ECO Tiroide', 'eco', 'testa', 'Ecografia tiroide e collo'),
('RX Torace', 'rx', 'torace', 'Radiografia torace PA e LL'),
('RX Mano', 'rx', 'estremita', 'Radiografia mano in 2 proiezioni')
ON CONFLICT DO NOTHING;

-- Organizations
INSERT INTO organizations (name, org_type, address, city, province, region)
VALUES
('Ospedale San Carlo', 'hospital', 'Via San Carlo 10', 'Milano', 'MI', 'Lombardia'),
('Istituto Medico Aurora', 'institute', 'Viale Aurora 22', 'Roma', 'RM', 'Lazio')
ON CONFLICT DO NOTHING;

-- Facilities
INSERT INTO facilities (name, address, city, province, region, latitude, longitude, type, base_price, organization_id, available_exam_ids)
VALUES
('San Carlo Radiologia - Milano', 'Via Torino 5', 'Milano', 'MI', 'Lombardia', 45.4642, 9.1900, 'public', 120.0,
 (SELECT id FROM organizations WHERE name='Ospedale San Carlo'),
 (SELECT ARRAY(SELECT id::text FROM exam_types WHERE category IN ('rm','rx')))
),
('Aurora Imaging - Roma', 'Via Appia 100', 'Roma', 'RM', 'Lazio', 41.9028, 12.4964, 'private', 140.0,
 (SELECT id FROM organizations WHERE name='Istituto Medico Aurora'),
 (SELECT ARRAY(SELECT id::text FROM exam_types WHERE category IN ('tac','eco','rx')))
)
ON CONFLICT DO NOTHING;
