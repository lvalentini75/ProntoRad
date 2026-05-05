-- ProntoRad - Safe idempotent patch for existing databases
-- Context: Previous migration failed when creating idx_users_auth_user_id
-- because some remote databases already had users without the auth_user_id column.
-- This migration adds the missing column/constraints/index only if needed.

-- 1) Ensure users.auth_user_id exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'auth_user_id'
  ) THEN
    ALTER TABLE public.users ADD COLUMN auth_user_id uuid NULL;
  END IF;
END $$;

-- 1a) Ensure UNIQUE constraint on users.auth_user_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_auth_user_id_key'
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_auth_user_id_key UNIQUE (auth_user_id);
  END IF;
END $$;

-- 1b) Ensure FK from users.auth_user_id -> auth.users(id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_auth_user_id_fkey'
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_auth_user_id_fkey
      FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 1c) Create index for fast lookups by auth_user_id (only if column exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'auth_user_id'
  ) THEN
    CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON public.users(auth_user_id);
  END IF;
END $$;

-- 2) Facilities: ensure organization_id column, FK and index exist (for older DBs)
ALTER TABLE IF EXISTS public.facilities
  ADD COLUMN IF NOT EXISTS organization_id uuid NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'facilities_organization_id_fkey'
  ) THEN
    ALTER TABLE public.facilities
      ADD CONSTRAINT facilities_organization_id_fkey
      FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_facilities_org ON public.facilities(organization_id);

-- 3) Defensive: ensure helpful supporting indexes exist (no-ops if already created)
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_booking_date ON public.bookings(booking_date);
