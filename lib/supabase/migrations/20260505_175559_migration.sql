-- Migration: Add exam_prerequisites table
-- Data: 2026-05-05
-- Descrizione: Tabella per i prerequisiti tra esami
-- Es: "Ecografia Mammaria" richiede "Mammografia" 20 minuti prima

-- ============================================================================
-- Tabella exam_prerequisites
-- ============================================================================

CREATE TABLE IF NOT EXISTS exam_prerequisites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    -- Esame che richiede il prerequisito (es: Ecografia Mammaria)
    exam_id UUID NOT NULL REFERENCES exam_types(id) ON DELETE CASCADE,
    -- Esame prerequisito (es: Mammografia)
    prerequisite_exam_id UUID NOT NULL REFERENCES exam_types(id) ON DELETE CASCADE,
    -- Minuti che il prerequisito deve essere PRIMA dell'esame principale
    time_gap_minutes INTEGER NOT NULL DEFAULT 20,
    -- Se true, il prerequisito è obbligatorio. Se false, è consigliato ma non bloccante
    is_mandatory BOOLEAN NOT NULL DEFAULT true,
    -- Note descrittive
    notes TEXT,
    -- Se attivo o meno
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Vincolo: non può essere lo stesso esame
    CONSTRAINT exam_prerequisites_different_exams CHECK (exam_id != prerequisite_exam_id),
    -- Vincolo: combinazione unica per organizzazione
    CONSTRAINT exam_prerequisites_unique UNIQUE (organization_id, exam_id, prerequisite_exam_id)
);

-- ============================================================================
-- Indici per exam_prerequisites
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_exam_prerequisites_organization_id ON exam_prerequisites(organization_id);
CREATE INDEX IF NOT EXISTS idx_exam_prerequisites_exam_id ON exam_prerequisites(exam_id);
CREATE INDEX IF NOT EXISTS idx_exam_prerequisites_prerequisite_exam_id ON exam_prerequisites(prerequisite_exam_id);
CREATE INDEX IF NOT EXISTS idx_exam_prerequisites_is_active ON exam_prerequisites(is_active);

-- ============================================================================
-- RLS Policies per exam_prerequisites
-- ============================================================================

ALTER TABLE exam_prerequisites ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS exam_prerequisites_super_admin_select ON exam_prerequisites;
DROP POLICY IF EXISTS exam_prerequisites_org_admin_select ON exam_prerequisites;
DROP POLICY IF EXISTS exam_prerequisites_super_admin_insert ON exam_prerequisites;
DROP POLICY IF EXISTS exam_prerequisites_org_admin_insert ON exam_prerequisites;
DROP POLICY IF EXISTS exam_prerequisites_super_admin_update ON exam_prerequisites;
DROP POLICY IF EXISTS exam_prerequisites_org_admin_update ON exam_prerequisites;
DROP POLICY IF EXISTS exam_prerequisites_super_admin_delete ON exam_prerequisites;
DROP POLICY IF EXISTS exam_prerequisites_org_admin_delete ON exam_prerequisites;
DROP POLICY IF EXISTS exam_prerequisites_end_user_select ON exam_prerequisites;

-- super_admin: può vedere tutto
CREATE POLICY exam_prerequisites_super_admin_select ON exam_prerequisites
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.auth_user_id = auth.uid() AND users.role = 'super_admin')
    );

-- org_admin: può vedere solo della propria organizzazione
CREATE POLICY exam_prerequisites_org_admin_select ON exam_prerequisites
    FOR SELECT
    TO authenticated
    USING (
        organization_id = (SELECT organization_id FROM users WHERE users.auth_user_id = auth.uid())
    );

-- super_admin: può inserire ovunque
CREATE POLICY exam_prerequisites_super_admin_insert ON exam_prerequisites
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE users.auth_user_id = auth.uid() AND users.role = 'super_admin')
    );

-- org_admin: può inserire solo nella propria organizzazione
CREATE POLICY exam_prerequisites_org_admin_insert ON exam_prerequisites
    FOR INSERT
    TO authenticated
    WITH CHECK (
        organization_id = (SELECT organization_id FROM users WHERE users.auth_user_id = auth.uid())
        AND EXISTS (SELECT 1 FROM users WHERE users.auth_user_id = auth.uid() AND users.role = 'org_admin')
    );

-- super_admin: può aggiornare ovunque
CREATE POLICY exam_prerequisites_super_admin_update ON exam_prerequisites
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.auth_user_id = auth.uid() AND users.role = 'super_admin')
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE users.auth_user_id = auth.uid() AND users.role = 'super_admin')
    );

-- org_admin: può aggiornare solo nella propria organizzazione
CREATE POLICY exam_prerequisites_org_admin_update ON exam_prerequisites
    FOR UPDATE
    TO authenticated
    USING (
        organization_id = (SELECT organization_id FROM users WHERE users.auth_user_id = auth.uid())
        AND EXISTS (SELECT 1 FROM users WHERE users.auth_user_id = auth.uid() AND users.role = 'org_admin')
    )
    WITH CHECK (
        organization_id = (SELECT organization_id FROM users WHERE users.auth_user_id = auth.uid())
        AND EXISTS (SELECT 1 FROM users WHERE users.auth_user_id = auth.uid() AND users.role = 'org_admin')
    );

-- super_admin: può eliminare ovunque
CREATE POLICY exam_prerequisites_super_admin_delete ON exam_prerequisites
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE users.auth_user_id = auth.uid() AND users.role = 'super_admin')
    );

-- org_admin: può eliminare solo nella propria organizzazione
CREATE POLICY exam_prerequisites_org_admin_delete ON exam_prerequisites
    FOR DELETE
    TO authenticated
    USING (
        organization_id = (SELECT organization_id FROM users WHERE users.auth_user_id = auth.uid())
        AND EXISTS (SELECT 1 FROM users WHERE users.auth_user_id = auth.uid() AND users.role = 'org_admin')
    );

-- end_user: può vedere i prerequisiti attivi (per la logica di prenotazione)
CREATE POLICY exam_prerequisites_end_user_select ON exam_prerequisites
    FOR SELECT
    TO authenticated
    USING (is_active = true);
