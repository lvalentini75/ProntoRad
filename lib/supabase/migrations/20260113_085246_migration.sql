-- Migration: Sistema completo prenotazione esami con slot, prezzi e conferme
-- Questa migrazione aggiunge:
-- 1. facility_exam_offerings: prezzo specifico per esame per struttura
-- 2. availability_slots: slot di disponibilità configurabili
-- 3. Aggiorna bookings con slot_id, conferme operatore

-- ========================================
-- 1. TABELLA facility_exam_offerings
-- Collegamento struttura-esame con prezzo e durata
-- ========================================
CREATE TABLE IF NOT EXISTS public.facility_exam_offerings (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  facility_id uuid NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  exam_type_id uuid NOT NULL REFERENCES public.exam_types(id) ON DELETE CASCADE,
  price numeric(10,2) NOT NULL DEFAULT 0,
  ssn_price numeric(10,2) DEFAULT 0, -- prezzo ticket SSN
  duration_minutes int NOT NULL DEFAULT 30,
  preparation_notes text, -- istruzioni preparazione esame
  is_available boolean DEFAULT true,
  max_daily_bookings int DEFAULT 10,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(facility_id, exam_type_id)
);

-- Enable RLS
ALTER TABLE public.facility_exam_offerings ENABLE ROW LEVEL SECURITY;

-- Policy per lettura pubblica e scrittura autenticata
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'facility_exam_offerings' AND policyname = 'feo_read_all') THEN
    CREATE POLICY feo_read_all ON public.facility_exam_offerings
      FOR SELECT TO anon, authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'facility_exam_offerings' AND policyname = 'feo_write_auth') THEN
    CREATE POLICY feo_write_auth ON public.facility_exam_offerings
      FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Indici per performance
CREATE INDEX IF NOT EXISTS idx_feo_facility ON public.facility_exam_offerings(facility_id);
CREATE INDEX IF NOT EXISTS idx_feo_exam ON public.facility_exam_offerings(exam_type_id);
CREATE INDEX IF NOT EXISTS idx_feo_available ON public.facility_exam_offerings(is_available);

-- ========================================
-- 2. TABELLA availability_slots
-- Slot di disponibilità per prenotazioni
-- ========================================
CREATE TABLE IF NOT EXISTS public.availability_slots (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  facility_id uuid NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  exam_type_id uuid REFERENCES public.exam_types(id) ON DELETE SET NULL, -- NULL = slot generico per tutti gli esami
  day_of_week int, -- 0=domenica, 1=lunedì... 6=sabato (per slot ricorrenti)
  specific_date date, -- per slot in date specifiche (override)
  start_time time NOT NULL,
  end_time time NOT NULL,
  max_bookings int NOT NULL DEFAULT 1, -- posti disponibili per slot
  is_active boolean DEFAULT true,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.availability_slots ENABLE ROW LEVEL SECURITY;

-- Policy
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'availability_slots' AND policyname = 'slots_read_all') THEN
    CREATE POLICY slots_read_all ON public.availability_slots
      FOR SELECT TO anon, authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'availability_slots' AND policyname = 'slots_write_auth') THEN
    CREATE POLICY slots_write_auth ON public.availability_slots
      FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Indici
CREATE INDEX IF NOT EXISTS idx_slots_facility ON public.availability_slots(facility_id);
CREATE INDEX IF NOT EXISTS idx_slots_exam ON public.availability_slots(exam_type_id);
CREATE INDEX IF NOT EXISTS idx_slots_day ON public.availability_slots(day_of_week);
CREATE INDEX IF NOT EXISTS idx_slots_date ON public.availability_slots(specific_date);
CREATE INDEX IF NOT EXISTS idx_slots_active ON public.availability_slots(is_active);

-- ========================================
-- 3. AGGIORNA TABELLA bookings
-- Aggiunge campi per slot e conferma operatore
-- ========================================

-- slot_id: collega alla disponibilità prenotata
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS slot_id uuid REFERENCES public.availability_slots(id) ON DELETE SET NULL;

-- confirmed_by: ID operatore che ha confermato
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS confirmed_by uuid REFERENCES public.users(id) ON DELETE SET NULL;

-- confirmed_at: data/ora conferma
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS confirmed_at timestamptz;

-- operator_notes: note dell'operatore
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS operator_notes text;

-- rejected_reason: motivo rifiuto
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS rejected_reason text;

-- Indici nuovi campi
CREATE INDEX IF NOT EXISTS idx_bookings_slot ON public.bookings(slot_id);
CREATE INDEX IF NOT EXISTS idx_bookings_confirmed_by ON public.bookings(confirmed_by);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);

-- ========================================
-- 4. POPOLA facility_exam_offerings DA DATI ESISTENTI
-- Crea automaticamente le offerte per esami già collegati
-- ========================================
INSERT INTO public.facility_exam_offerings (facility_id, exam_type_id, price, ssn_price, duration_minutes)
SELECT 
  f.id as facility_id,
  unnest(f.available_exam_ids)::uuid as exam_type_id,
  f.base_price as price,
  CASE WHEN f.type = 'public' THEN 36.15 ELSE 0 END as ssn_price, -- ticket standard
  30 as duration_minutes
FROM public.facilities f
WHERE array_length(f.available_exam_ids, 1) > 0
ON CONFLICT (facility_id, exam_type_id) DO NOTHING;

-- ========================================
-- 5. POPOLA availability_slots CON ORARI STANDARD
-- Crea slot di default per le strutture esistenti
-- ========================================
-- Slot mattutini: 08:00-13:00 (lun-ven)
INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '08:00'::time, '08:30'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow -- lun-ven
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '08:30'::time, '09:00'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '09:00'::time, '09:30'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '09:30'::time, '10:00'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '10:00'::time, '10:30'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '10:30'::time, '11:00'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '11:00'::time, '11:30'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '11:30'::time, '12:00'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '12:00'::time, '12:30'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

-- Slot pomeridiani: 14:00-18:00 (lun-ven)
INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '14:00'::time, '14:30'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '14:30'::time, '15:00'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '15:00'::time, '15:30'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '15:30'::time, '16:00'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '16:00'::time, '16:30'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '16:30'::time, '17:00'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '17:00'::time, '17:30'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;

INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings)
SELECT f.id, dow, '17:30'::time, '18:00'::time, 2
FROM public.facilities f
CROSS JOIN generate_series(1, 5) as dow
ON CONFLICT DO NOTHING;
