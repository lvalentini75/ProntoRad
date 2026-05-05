-- Migration: Aggiunge organization_id a availability_slots per gestione diretta per Istituto
-- Data: 2026-01-13

-- 1) Aggiungi colonna organization_id (nullable inizialmente)
ALTER TABLE public.availability_slots
  ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE;

-- 2) Crea indice per organization_id
CREATE INDEX IF NOT EXISTS idx_slots_organization ON public.availability_slots(organization_id);

-- 3) Popola organization_id dai facility esistenti
UPDATE public.availability_slots AS s
SET organization_id = f.organization_id
FROM public.facilities AS f
WHERE s.facility_id = f.id
  AND s.organization_id IS NULL;

-- 4) Policy RLS per org_admin: possono gestire slot della propria organizzazione
DO $$
BEGIN
  -- Drop existing restrictive policies if any
  DROP POLICY IF EXISTS slots_org_admin_select ON public.availability_slots;
  DROP POLICY IF EXISTS slots_org_admin_insert ON public.availability_slots;
  DROP POLICY IF EXISTS slots_org_admin_update ON public.availability_slots;
  DROP POLICY IF EXISTS slots_org_admin_delete ON public.availability_slots;

  -- Crea policy per SELECT: tutti possono leggere
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'availability_slots' AND policyname = 'slots_public_read') THEN
    CREATE POLICY slots_public_read ON public.availability_slots
      FOR SELECT USING (true);
  END IF;

  -- Policy per INSERT: utenti autenticati con organization_id corrispondente
  CREATE POLICY slots_org_admin_insert ON public.availability_slots
    FOR INSERT WITH CHECK (
      organization_id IN (
        SELECT u.organization_id FROM public.users u WHERE u.id = auth.uid()
      )
      OR 
      facility_id IN (
        SELECT f.id FROM public.facilities f 
        JOIN public.users u ON u.organization_id = f.organization_id 
        WHERE u.id = auth.uid()
      )
    );

  -- Policy per UPDATE
  CREATE POLICY slots_org_admin_update ON public.availability_slots
    FOR UPDATE USING (
      organization_id IN (
        SELECT u.organization_id FROM public.users u WHERE u.id = auth.uid()
      )
      OR 
      facility_id IN (
        SELECT f.id FROM public.facilities f 
        JOIN public.users u ON u.organization_id = f.organization_id 
        WHERE u.id = auth.uid()
      )
    );

  -- Policy per DELETE
  CREATE POLICY slots_org_admin_delete ON public.availability_slots
    FOR DELETE USING (
      organization_id IN (
        SELECT u.organization_id FROM public.users u WHERE u.id = auth.uid()
      )
      OR 
      facility_id IN (
        SELECT f.id FROM public.facilities f 
        JOIN public.users u ON u.organization_id = f.organization_id 
        WHERE u.id = auth.uid()
      )
    );
END $$;

-- 5) Commento esplicativo
COMMENT ON COLUMN public.availability_slots.organization_id IS 'ID dell''Istituto/Ospedale proprietario dello slot (alternativo a facility_id)';
