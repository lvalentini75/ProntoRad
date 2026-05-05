-- Migration: Fix availability_slots table
-- Data: 2026-01-14 10:05:43
-- Descrizione: Ricrea la tabella availability_slots se non esiste o ha errori

-- 0) Aggiungi organization_id alla tabella users se non esiste
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS organization_id UUID NULL REFERENCES public.organizations(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_users_organization ON public.users(organization_id) WHERE organization_id IS NOT NULL;

-- 1) Elimina la tabella esistente se c'è (per ripartire da zero)
DROP TABLE IF EXISTS public.availability_slots CASCADE;

-- 2) Crea la tabella availability_slots
CREATE TABLE public.availability_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  organization_id UUID NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  exam_type_id UUID NULL REFERENCES public.exam_types(id) ON DELETE CASCADE,
  day_of_week INTEGER NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
  specific_date DATE NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  max_bookings INTEGER NOT NULL DEFAULT 1 CHECK (max_bookings >= 0),
  is_active BOOLEAN NOT NULL DEFAULT true,
  notes TEXT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  -- Vincolo: deve avere almeno facility_id o organization_id
  CONSTRAINT check_has_facility_or_org CHECK (
    facility_id IS NOT NULL OR organization_id IS NOT NULL
  ),
  
  -- Vincolo: deve avere day_of_week (ricorrente) o specific_date (data specifica), ma non entrambi
  CONSTRAINT check_day_or_date CHECK (
    (day_of_week IS NOT NULL AND specific_date IS NULL) OR
    (day_of_week IS NULL AND specific_date IS NOT NULL)
  )
);

-- 3) Crea indici
CREATE INDEX idx_slots_facility ON public.availability_slots(facility_id) WHERE facility_id IS NOT NULL;
CREATE INDEX idx_slots_organization ON public.availability_slots(organization_id) WHERE organization_id IS NOT NULL;
CREATE INDEX idx_slots_exam_type ON public.availability_slots(exam_type_id) WHERE exam_type_id IS NOT NULL;
CREATE INDEX idx_slots_day_of_week ON public.availability_slots(day_of_week) WHERE day_of_week IS NOT NULL;
CREATE INDEX idx_slots_specific_date ON public.availability_slots(specific_date) WHERE specific_date IS NOT NULL;
CREATE INDEX idx_slots_active ON public.availability_slots(is_active) WHERE is_active = true;

-- 4) Abilita RLS
ALTER TABLE public.availability_slots ENABLE ROW LEVEL SECURITY;

-- 5) Crea policy per lettura pubblica
CREATE POLICY slots_public_read ON public.availability_slots
  FOR SELECT 
  USING (true);

-- 6) Crea policy per insert (solo org_admin della propria organizzazione)
CREATE POLICY slots_org_admin_insert ON public.availability_slots
  FOR INSERT 
  WITH CHECK (
    organization_id IN (
      SELECT u.organization_id 
      FROM public.users u 
      WHERE u.id = auth.uid() AND u.organization_id IS NOT NULL
    )
  );

-- 7) Crea policy per update (solo org_admin della propria organizzazione)
CREATE POLICY slots_org_admin_update ON public.availability_slots
  FOR UPDATE 
  USING (
    organization_id IN (
      SELECT u.organization_id 
      FROM public.users u 
      WHERE u.id = auth.uid() AND u.organization_id IS NOT NULL
    )
  )
  WITH CHECK (
    organization_id IN (
      SELECT u.organization_id 
      FROM public.users u 
      WHERE u.id = auth.uid() AND u.organization_id IS NOT NULL
    )
  );

-- 8) Crea policy per delete (solo org_admin della propria organizzazione)
CREATE POLICY slots_org_admin_delete ON public.availability_slots
  FOR DELETE 
  USING (
    organization_id IN (
      SELECT u.organization_id 
      FROM public.users u 
      WHERE u.id = auth.uid() AND u.organization_id IS NOT NULL
    )
  );

-- 9) Aggiungi commenti per documentazione
COMMENT ON TABLE public.availability_slots IS 'Slot di disponibilità per prenotazioni esami';
COMMENT ON COLUMN public.availability_slots.organization_id IS 'ID dell''organizzazione che gestisce questo slot';
COMMENT ON COLUMN public.availability_slots.exam_type_id IS 'ID del tipo di esame (NULL = tutti gli esami)';
COMMENT ON COLUMN public.availability_slots.day_of_week IS 'Giorno della settimana per slot ricorrenti (0=Dom, 1=Lun, ..., 6=Sab)';
COMMENT ON COLUMN public.availability_slots.specific_date IS 'Data specifica per slot non ricorrenti';
