-- =====================================================================
-- Migration: Indici per ottimizzare query su availability_slots
-- Creato: 2026-02-03
-- =====================================================================

-- Indice per query su organization_id (usato in getAllSlotsForOrganization)
CREATE INDEX IF NOT EXISTS idx_availability_slots_organization_id 
ON availability_slots(organization_id);

-- Indice per query su specific_date (usato per filtrare per range date)
CREATE INDEX IF NOT EXISTS idx_availability_slots_specific_date 
ON availability_slots(specific_date);

-- Indice per query su staff_user_id
CREATE INDEX IF NOT EXISTS idx_availability_slots_staff_user_id 
ON availability_slots(staff_user_id);

-- Indice composito per query filtrate per org + date range (ottimizzazione principale)
CREATE INDEX IF NOT EXISTS idx_availability_slots_org_date 
ON availability_slots(organization_id, specific_date);

-- Indice composito per query filtrate per staff + date range
CREATE INDEX IF NOT EXISTS idx_availability_slots_staff_date 
ON availability_slots(staff_user_id, specific_date);

-- Indice per exam_category (nuovo campo per filtri per categoria)
CREATE INDEX IF NOT EXISTS idx_availability_slots_exam_category 
ON availability_slots(exam_category);

-- Commento sulle performance
COMMENT ON INDEX idx_availability_slots_org_date IS 
'Indice composito per ottimizzare getAllSlotsForOrganization con filtro date';

COMMENT ON INDEX idx_availability_slots_staff_date IS 
'Indice composito per ottimizzare query per staff con filtro date';
