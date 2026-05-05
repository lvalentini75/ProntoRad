-- Auto-link user to organization when created
-- This ensures that when a user creates an organization, their user record
-- is automatically updated with the organization_id

-- ==============================================================================
-- STEP 1: Create helper function to auto-link user to new organization
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.auto_link_user_to_organization()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_auth_id uuid;
  user_record_id uuid;
BEGIN
  -- Get the current authenticated user's auth.uid()
  current_auth_id := auth.uid();
  
  -- Skip if this is called from an unauthenticated context
  IF current_auth_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Find the user record for this auth_user_id
  SELECT id INTO user_record_id
  FROM public.users
  WHERE auth_user_id = current_auth_id
  LIMIT 1;
  
  -- If user exists and doesn't have an organization yet, link them
  IF user_record_id IS NOT NULL THEN
    UPDATE public.users
    SET 
      organization_id = NEW.id,
      updated_at = NOW()
    WHERE id = user_record_id
      AND organization_id IS NULL;
    
    RAISE NOTICE 'Auto-linked user % to organization %', user_record_id, NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.auto_link_user_to_organization() TO authenticated;

-- ==============================================================================
-- STEP 2: Create trigger on organizations table
-- ==============================================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_auto_link_user_to_organization ON public.organizations;

-- Create trigger that fires AFTER INSERT on organizations
CREATE TRIGGER trigger_auto_link_user_to_organization
AFTER INSERT ON public.organizations
FOR EACH ROW
EXECUTE FUNCTION public.auto_link_user_to_organization();

-- ==============================================================================
-- STEP 3: Fix existing data - link admin users to their organizations
-- ==============================================================================

-- For each organization, if there's a user with matching email that's not linked, link them
DO $$
DECLARE
  org_record RECORD;
  user_record RECORD;
  linked_count INTEGER := 0;
BEGIN
  FOR org_record IN 
    SELECT id, email FROM public.organizations WHERE email IS NOT NULL AND email != ''
  LOOP
    -- Find user with matching email and no organization
    SELECT id, email, role INTO user_record
    FROM public.users
    WHERE email = org_record.email
      AND organization_id IS NULL
      AND role IN ('org_admin', 'super_admin')
    LIMIT 1;
    
    IF FOUND THEN
      -- Link this user to the organization
      UPDATE public.users
      SET 
        organization_id = org_record.id,
        updated_at = NOW()
      WHERE id = user_record.id;
      
      linked_count := linked_count + 1;
      RAISE NOTICE 'Linked user % (%) to organization %', user_record.email, user_record.role, org_record.id;
    END IF;
  END LOOP;
  
  RAISE NOTICE '✅ Fixed % existing user-organization links', linked_count;
END $$;

-- ==============================================================================
-- STEP 4: Create helper function to manually link user to organization
-- ==============================================================================

-- This can be called by super_admin to manually link a user to an organization
CREATE OR REPLACE FUNCTION public.link_user_to_organization(
  p_user_id uuid,
  p_organization_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify caller is super_admin
  IF NOT EXISTS (
    SELECT 1 FROM public.get_current_user_role() me
    WHERE me.user_role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Only super_admin can manually link users to organizations';
  END IF;
  
  -- Update user record
  UPDATE public.users
  SET 
    organization_id = p_organization_id,
    updated_at = NOW()
  WHERE id = p_user_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User with id % not found', p_user_id;
  END IF;
  
  RAISE NOTICE 'Successfully linked user % to organization %', p_user_id, p_organization_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.link_user_to_organization(uuid, uuid) TO authenticated;

-- ==============================================================================
-- SUCCESS MESSAGE
-- ==============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Auto-link user to organization setup complete';
  RAISE NOTICE '   - Trigger created on organizations table';
  RAISE NOTICE '   - Existing data fixed';
  RAISE NOTICE '   - Helper function available: link_user_to_organization(user_id, org_id)';
END $$;
