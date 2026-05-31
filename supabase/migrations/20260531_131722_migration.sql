-- ============================================================
-- Planning Sale (Multi-Room Calendar View) - Schema additions
-- ============================================================

-- 1. Create rooms table (one row per hospital "sala/macchinario")
CREATE TABLE IF NOT EXISTS public.rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  color TEXT, -- hex color for UI (e.g. "#3B82F6")
  description TEXT,
  display_order INT DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rooms_organization_id ON public.rooms(organization_id);
CREATE INDEX IF NOT EXISTS idx_rooms_org_active ON public.rooms(organization_id, is_active);

-- Enable RLS
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

-- Policies: org_admins manage own org rooms, super_admin all, authenticated read
DROP POLICY IF EXISTS rooms_select_all ON public.rooms;
CREATE POLICY rooms_select_all ON public.rooms
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS rooms_insert_admin ON public.rooms;
CREATE POLICY rooms_insert_admin ON public.rooms
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
      AND (u.role = 'super_admin' OR (u.role = 'org_admin' AND u.organization_id = rooms.organization_id))
    )
  );

DROP POLICY IF EXISTS rooms_update_admin ON public.rooms;
CREATE POLICY rooms_update_admin ON public.rooms
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
      AND (u.role = 'super_admin' OR (u.role = 'org_admin' AND u.organization_id = rooms.organization_id))
    )
  );

DROP POLICY IF EXISTS rooms_delete_admin ON public.rooms;
CREATE POLICY rooms_delete_admin ON public.rooms
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
      AND (u.role = 'super_admin' OR (u.role = 'org_admin' AND u.organization_id = rooms.organization_id))
    )
  );

-- 2. Add room_id to availability_slots and bookings
ALTER TABLE public.availability_slots
  ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_availability_slots_room_id ON public.availability_slots(room_id);

ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_bookings_room_id ON public.bookings(room_id);

-- 3. Add planning configuration to organizations
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS planning_start_hour INT NOT NULL DEFAULT 7,
  ADD COLUMN IF NOT EXISTS planning_end_hour INT NOT NULL DEFAULT 20,
  ADD COLUMN IF NOT EXISTS planning_slot_minutes INT NOT NULL DEFAULT 15;

-- Sanity constraints
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_planning_hours') THEN
    ALTER TABLE public.organizations
      ADD CONSTRAINT chk_planning_hours CHECK (
        planning_start_hour >= 0 AND planning_start_hour < 24
        AND planning_end_hour > planning_start_hour AND planning_end_hour <= 24
        AND planning_slot_minutes IN (5, 10, 15, 20, 30, 60)
      );
  END IF;
END $$;
