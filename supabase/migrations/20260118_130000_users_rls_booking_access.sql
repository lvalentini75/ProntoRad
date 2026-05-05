-- Allow users to read user records linked to their own bookings
-- This fixes the issue where patient data shows as N/A in booking status screen

-- Ensure RLS is enabled on users (no-op if already enabled)
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read user data for their own bookings
-- This allows a patient to see their own user data when viewing their booking
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'user_select_own_booking_user'
  ) THEN
    CREATE POLICY user_select_own_booking_user
    ON public.users
    FOR SELECT
    TO authenticated
    USING (
      -- User can read their own record if they created a booking with this user_id
      EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.user_id = users.id
          AND EXISTS (
            SELECT 1 FROM public.users me
            WHERE me.auth_user_id = auth.uid()
              AND (me.id = b.user_id OR me.email = users.email)
          )
      )
    );
  END IF;
END $$;

-- Policy: Allow authenticated users to read their own profile by email
-- This helps when auth_user_id is not linked yet
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'self_select_users_by_email'
  ) THEN
    CREATE POLICY self_select_users_by_email
    ON public.users
    FOR SELECT
    TO authenticated
    USING (
      -- User can read their own record by matching auth email
      email = (SELECT email FROM auth.users WHERE id = auth.uid())
    );
  END IF;
END $$;

-- Policy: Allow anon users to read user data via bookings (for guest checkout flow)
-- Only the user linked to the booking can be read
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'anon_select_booking_user'
  ) THEN
    CREATE POLICY anon_select_booking_user
    ON public.users
    FOR SELECT
    TO anon
    USING (
      -- Anon can read user if it's linked to any booking
      -- This is needed for guest checkout where user views their booking status
      EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.user_id = users.id
      )
    );
  END IF;
END $$;

-- Grant additional permissions if needed
GRANT SELECT ON public.users TO anon;
GRANT SELECT ON public.users TO authenticated;
