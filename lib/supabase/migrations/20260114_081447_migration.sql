-- Migration: Crea tabella availability_slots e aggiunge organization_id a users
-- Data: 2026-01-14
-- Descrizione: Crea la tabella availability_slots per gestire gli slot di disponibilità degli esami
--              e aggiunge organization_id alla tabella users per associare gli utenti alle organizzazioni

-- 0) Aggiungi organization_id alla tabella users se non esiste
ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS organization_id UUID NULL REFERENCES public.organizations(id) ON DELETE SET NULL;

-- Crea indice per organization_id sulla tabella users
CREATE INDEX IF NOT EXISTS idx_users_organization ON public.users(organization_id) WHERE organization_id IS NOT NULL;

-- 1) Crea la tabella availability_slots
CREATE TABLE IF NOT EXISTS public.availability_slots (
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

-- 2) Crea indici per migliorare le performance delle query
CREATE INDEX IF NOT EXISTS idx_slots_facility ON public.availability_slots(facility_id) WHERE facility_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_slots_organization ON public.availability_slots(organization_id) WHERE organization_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_slots_exam_type ON public.availability_slots(exam_type_id) WHERE exam_type_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_slots_day_of_week ON public.availability_slots(day_of_week) WHERE day_of_week IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_slots_specific_date ON public.availability_slots(specific_date) WHERE specific_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_slots_active ON public.availability_slots(is_active) WHERE is_active = true;

-- 3) Abilita RLS (Row Level Security)
ALTER TABLE public.availability_slots ENABLE ROW LEVEL SECURITY;

-- 4) Crea policies RLS usando blocchi DO per gestire la condizione IF NOT EXISTS
DO $$
BEGIN
  -- Policy: Tutti possono leggere gli slot attivi (per ricerca pubblica)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'availability_slots' AND policyname = 'slots_public_read'
  ) THEN
    CREATE POLICY slots_public_read ON public.availability_slots
      FOR SELECT 
      USING (true);
  END IF;

  -- Policy: Gli org_admin possono inserire slot per la propria organizzazione
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'availability_slots' AND policyname = 'slots_org_admin_insert'
  ) THEN
    CREATE POLICY slots_org_admin_insert ON public.availability_slots
      FOR INSERT 
      WITH CHECK (
        -- L'utente deve essere autenticato e avere lo stesso organization_id dello slot
        organization_id IN (
          SELECT u.organization_id 
          FROM public.users u 
          WHERE u.id = auth.uid() AND u.organization_id IS NOT NULL
        )
        OR 
        -- Oppure lo slot appartiene a una facility della sua organizzazione
        facility_id IN (
          SELECT f.id 
          FROM public.facilities f 
          JOIN public.users u ON u.organization_id = f.organization_id 
          WHERE u.id = auth.uid()
        )
      );
  END IF;

  -- Policy: Gli org_admin possono aggiornare slot della propria organizzazione
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'availability_slots' AND policyname = 'slots_org_admin_update'
  ) THEN
    CREATE POLICY slots_org_admin_update ON public.availability_slots
      FOR UPDATE 
      USING (
        organization_id IN (
          SELECT u.organization_id 
          FROM public.users u 
          WHERE u.id = auth.uid() AND u.organization_id IS NOT NULL
        )
        OR 
        facility_id IN (
          SELECT f.id 
          FROM public.facilities f 
          JOIN public.users u ON u.organization_id = f.organization_id 
          WHERE u.id = auth.uid()
        )
      )
      WITH CHECK (
        organization_id IN (
          SELECT u.organization_id 
          FROM public.users u 
          WHERE u.id = auth.uid() AND u.organization_id IS NOT NULL
        )
        OR 
        facility_id IN (
          SELECT f.id 
          FROM public.facilities f 
          JOIN public.users u ON u.organization_id = f.organization_id 
          WHERE u.id = auth.uid()
        )
      );
  END IF;

  -- Policy: Gli org_admin possono eliminare slot della propria organizzazione
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'availability_slots' AND policyname = 'slots_org_admin_delete'
  ) THEN
    CREATE POLICY slots_org_admin_delete ON public.availability_slots
      FOR DELETE 
      USING (
        organization_id IN (
          SELECT u.organization_id 
          FROM public.users u 
          WHERE u.id = auth.uid() AND u.organization_id IS NOT NULL
        )
        OR 
        facility_id IN (
          SELECT f.id 
          FROM public.facilities f 
          JOIN public.users u ON u.organization_id = f.organization_id 
          WHERE u.id = auth.uid()
        )
      );
  END IF;
END $$;

-- 8) Commenti sulla tabella e colonne per documentazione
COMMENT ON TABLE public.availability_slots IS 'Slot di disponibilità per prenotazioni esami radiografici';
COMMENT ON COLUMN public.availability_slots.facility_id IS 'ID della struttura (opzionale, alternativo a organization_id)';
COMMENT ON COLUMN public.availability_slots.organization_id IS 'ID dell''Istituto/Ospedale (opzionale, alternativo a facility_id)';
COMMENT ON COLUMN public.availability_slots.exam_type_id IS 'ID del tipo di esame specifico (NULL = valido per tutti gli esami)';
COMMENT ON COLUMN public.availability_slots.day_of_week IS 'Giorno della settimana per slot ricorrenti (0=Domenica, 1=Lunedì, ..., 6=Sabato)';
COMMENT ON COLUMN public.availability_slots.specific_date IS 'Data specifica per slot non ricorrenti';
COMMENT ON COLUMN public.availability_slots.max_bookings IS 'Numero massimo di prenotazioni per questo slot (0 = blocco/chiusura)';
