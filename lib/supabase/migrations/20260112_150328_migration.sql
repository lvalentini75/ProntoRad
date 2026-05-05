-- Idempotent fix: ensure users.auth_user_id exists before any index creation
-- and add supporting FK and index only if missing. This prevents failures
-- like: ERROR: column "auth_user_id" does not exist when creating index.

-- 1) Add column if missing
ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS auth_user_id uuid NULL;

-- 2) Add FK to auth.users(id) if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_auth_user_id_fkey'
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_auth_user_id_fkey
      FOREIGN KEY (auth_user_id)
      REFERENCES auth.users(id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- 3) Create non-unique index for lookups (only if column exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'auth_user_id'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_users_auth_user_id'
    ) THEN
      EXECUTE 'CREATE INDEX idx_users_auth_user_id ON public.users(auth_user_id)';
    END IF;
  END IF;
END $$;

-- 4) Optional: ensure email index exists (defensive, no-op if present)
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
