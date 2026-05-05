-- ================================================================
-- MIGRATION: Availability Management System - FRESH START
-- Created: 2026-01-14
-- Description: Complete rebuild of availability system
-- ================================================================

-- 0. Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- 1. Create facility_exam_offerings table
CREATE TABLE IF NOT EXISTS public.facility_exam_offerings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  exam_id UUID NOT NULL REFERENCES public.exam_types(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(facility_id, exam_id)
);

-- 2. Create availability_slots table
CREATE TABLE IF NOT EXISTS public.availability_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  exam_id UUID NOT NULL REFERENCES public.exam_types(id) ON DELETE CASCADE,
  staff_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  is_available BOOLEAN DEFAULT true,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Constraints
  CONSTRAINT valid_time_range CHECK (end_time > start_time)
);

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_facility_exam_offerings_facility ON public.facility_exam_offerings(facility_id);
CREATE INDEX IF NOT EXISTS idx_facility_exam_offerings_exam ON public.facility_exam_offerings(exam_id);
CREATE INDEX IF NOT EXISTS idx_availability_slots_facility ON public.availability_slots(facility_id);
CREATE INDEX IF NOT EXISTS idx_availability_slots_exam ON public.availability_slots(exam_id);
CREATE INDEX IF NOT EXISTS idx_availability_slots_staff ON public.availability_slots(staff_user_id);
CREATE INDEX IF NOT EXISTS idx_availability_slots_time ON public.availability_slots(start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_availability_slots_available ON public.availability_slots(is_available) WHERE is_available = true;

-- 4. Enable Row Level Security
ALTER TABLE public.facility_exam_offerings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability_slots ENABLE ROW LEVEL SECURITY;

-- 5. Drop existing policies if any
DROP POLICY IF EXISTS "Enable read for all authenticated users" ON public.facility_exam_offerings;
DROP POLICY IF EXISTS "Enable insert for hospital staff" ON public.facility_exam_offerings;
DROP POLICY IF EXISTS "Enable update for hospital staff" ON public.facility_exam_offerings;
DROP POLICY IF EXISTS "Enable delete for hospital staff" ON public.facility_exam_offerings;

DROP POLICY IF EXISTS "Enable read for all authenticated users" ON public.availability_slots;
DROP POLICY IF EXISTS "Enable insert for hospital staff" ON public.availability_slots;
DROP POLICY IF EXISTS "Enable update for hospital staff" ON public.availability_slots;
DROP POLICY IF EXISTS "Enable delete for hospital staff" ON public.availability_slots;

-- 6. Create RLS policies for facility_exam_offerings
CREATE POLICY "Enable read for all authenticated users"
  ON public.facility_exam_offerings FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert for hospital staff"
  ON public.facility_exam_offerings FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.role IN ('hospital_staff', 'admin')
    )
  );

CREATE POLICY "Enable update for hospital staff"
  ON public.facility_exam_offerings FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.role IN ('hospital_staff', 'admin')
    )
  );

CREATE POLICY "Enable delete for hospital staff"
  ON public.facility_exam_offerings FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.role IN ('hospital_staff', 'admin')
    )
  );

-- 7. Create RLS policies for availability_slots
CREATE POLICY "Enable read for all authenticated users"
  ON public.availability_slots FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert for hospital staff"
  ON public.availability_slots FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.role IN ('hospital_staff', 'admin')
    )
  );

CREATE POLICY "Enable update for hospital staff"
  ON public.availability_slots FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.role IN ('hospital_staff', 'admin')
    )
  );

CREATE POLICY "Enable delete for hospital staff"
  ON public.availability_slots FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.role IN ('hospital_staff', 'admin')
    )
  );

-- 8. Grant permissions
GRANT ALL ON public.facility_exam_offerings TO authenticated;
GRANT ALL ON public.availability_slots TO authenticated;

-- 9. Add helpful comments
COMMENT ON TABLE public.facility_exam_offerings IS 'Tracks which exams are offered at each facility';
COMMENT ON TABLE public.availability_slots IS 'Staff availability slots for exams at facilities';
COMMENT ON COLUMN public.availability_slots.is_available IS 'Whether the slot is available for booking';
COMMENT ON COLUMN public.availability_slots.booking_id IS 'Reference to booking if slot is booked';

-- 10. Create function to check for overlapping slots (for application-level validation)
CREATE OR REPLACE FUNCTION check_slot_overlap(
  p_staff_user_id UUID,
  p_start_time TIMESTAMP WITH TIME ZONE,
  p_end_time TIMESTAMP WITH TIME ZONE,
  p_exclude_slot_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1
    FROM public.availability_slots
    WHERE staff_user_id = p_staff_user_id
    AND is_available = true
    AND (id != p_exclude_slot_id OR p_exclude_slot_id IS NULL)
    AND (
      (start_time < p_end_time AND end_time > p_start_time)
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
