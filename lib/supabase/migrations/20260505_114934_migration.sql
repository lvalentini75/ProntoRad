-- =====================================================
-- FASE A: Esami Multipli nella Stessa Sala
-- Tabelle per pacchetti esami e compatibilità
-- =====================================================

-- Tabella exam_packages: Pacchetti di esami predefiniti
-- Es: "RM Colonna Completa" = RM Cervicale + RM Dorsale + RM Lombare
CREATE TABLE IF NOT EXISTS exam_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    -- Array di exam_type IDs inclusi nel pacchetto
    exam_ids UUID[] NOT NULL DEFAULT '{}',
    -- Durata totale in minuti (può essere diversa dalla somma se esami in parallelo)
    total_duration_minutes INTEGER NOT NULL DEFAULT 30,
    -- Se true, i tempi degli esami si sommano; se false, usano lo slot più lungo
    is_cumulative BOOLEAN NOT NULL DEFAULT true,
    -- Prezzo pacchetto (opzionale, può essere diverso dalla somma singoli)
    package_price DECIMAL(10,2),
    -- Stato attivo
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabella exam_compatibility: Regole di compatibilità tra esami
-- Definisce quali esami possono essere combinati e come
CREATE TABLE IF NOT EXISTS exam_compatibility (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    -- Primo esame
    exam_id_1 UUID NOT NULL REFERENCES exam_types(id) ON DELETE CASCADE,
    -- Secondo esame
    exam_id_2 UUID NOT NULL REFERENCES exam_types(id) ON DELETE CASCADE,
    -- Tipo di compatibilità:
    -- 'same_slot' = stesso slot, stessa sala (es: TAC addome + torace)
    -- 'sequential' = consecutivi, stessa sala (es: RM cervicale + dorsale)
    -- 'different_room' = sale diverse, distanziati nel tempo (es: mammografia + eco mammaria)
    compatibility_type VARCHAR(50) NOT NULL DEFAULT 'sequential',
    -- Intervallo minimo tra gli esami in minuti (per different_room)
    time_gap_minutes INTEGER NOT NULL DEFAULT 0,
    -- Note aggiuntive
    notes TEXT,
    -- Stato attivo
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Evita duplicati (esame A-B = esame B-A)
    CONSTRAINT exam_compatibility_unique UNIQUE (organization_id, exam_id_1, exam_id_2)
);

-- Indici per exam_packages
CREATE INDEX IF NOT EXISTS idx_exam_packages_organization_id ON exam_packages(organization_id);
CREATE INDEX IF NOT EXISTS idx_exam_packages_is_active ON exam_packages(is_active);

-- Indici per exam_compatibility
CREATE INDEX IF NOT EXISTS idx_exam_compatibility_organization_id ON exam_compatibility(organization_id);
CREATE INDEX IF NOT EXISTS idx_exam_compatibility_exam_id_1 ON exam_compatibility(exam_id_1);
CREATE INDEX IF NOT EXISTS idx_exam_compatibility_exam_id_2 ON exam_compatibility(exam_id_2);
CREATE INDEX IF NOT EXISTS idx_exam_compatibility_type ON exam_compatibility(compatibility_type);

-- =====================================================
-- RLS Policies per exam_packages
-- =====================================================
ALTER TABLE exam_packages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (now the table exists)
DROP POLICY IF EXISTS exam_packages_super_admin_select ON exam_packages;
DROP POLICY IF EXISTS exam_packages_org_admin_select ON exam_packages;
DROP POLICY IF EXISTS exam_packages_super_admin_insert ON exam_packages;
DROP POLICY IF EXISTS exam_packages_org_admin_insert ON exam_packages;
DROP POLICY IF EXISTS exam_packages_super_admin_update ON exam_packages;
DROP POLICY IF EXISTS exam_packages_org_admin_update ON exam_packages;
DROP POLICY IF EXISTS exam_packages_super_admin_delete ON exam_packages;
DROP POLICY IF EXISTS exam_packages_org_admin_delete ON exam_packages;
DROP POLICY IF EXISTS exam_packages_end_user_select ON exam_packages;

-- Super admin può vedere tutti i pacchetti
CREATE POLICY exam_packages_super_admin_select ON exam_packages
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    );

-- Org admin può vedere i pacchetti della propria organizzazione
CREATE POLICY exam_packages_org_admin_select ON exam_packages
    FOR SELECT
    TO authenticated
    USING (
        organization_id = get_my_organization_id()
    );

-- Super admin può inserire pacchetti per qualsiasi organizzazione
CREATE POLICY exam_packages_super_admin_insert ON exam_packages
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    );

-- Org admin può inserire pacchetti per la propria organizzazione
CREATE POLICY exam_packages_org_admin_insert ON exam_packages
    FOR INSERT
    TO authenticated
    WITH CHECK (
        organization_id = get_my_organization_id()
    );

-- Super admin può aggiornare qualsiasi pacchetto
CREATE POLICY exam_packages_super_admin_update ON exam_packages
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    );

-- Org admin può aggiornare i pacchetti della propria organizzazione
CREATE POLICY exam_packages_org_admin_update ON exam_packages
    FOR UPDATE
    TO authenticated
    USING (
        organization_id = get_my_organization_id()
    )
    WITH CHECK (
        organization_id = get_my_organization_id()
    );

-- Super admin può eliminare qualsiasi pacchetto
CREATE POLICY exam_packages_super_admin_delete ON exam_packages
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    );

-- Org admin può eliminare i pacchetti della propria organizzazione
CREATE POLICY exam_packages_org_admin_delete ON exam_packages
    FOR DELETE
    TO authenticated
    USING (
        organization_id = get_my_organization_id()
    );

-- Policy per end_user: possono vedere i pacchetti attivi (per la prenotazione)
CREATE POLICY exam_packages_end_user_select ON exam_packages
    FOR SELECT
    TO authenticated
    USING (
        is_active = true
    );

-- =====================================================
-- RLS Policies per exam_compatibility
-- =====================================================
ALTER TABLE exam_compatibility ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (now the table exists)
DROP POLICY IF EXISTS exam_compatibility_super_admin_select ON exam_compatibility;
DROP POLICY IF EXISTS exam_compatibility_org_admin_select ON exam_compatibility;
DROP POLICY IF EXISTS exam_compatibility_super_admin_insert ON exam_compatibility;
DROP POLICY IF EXISTS exam_compatibility_org_admin_insert ON exam_compatibility;
DROP POLICY IF EXISTS exam_compatibility_super_admin_update ON exam_compatibility;
DROP POLICY IF EXISTS exam_compatibility_org_admin_update ON exam_compatibility;
DROP POLICY IF EXISTS exam_compatibility_super_admin_delete ON exam_compatibility;
DROP POLICY IF EXISTS exam_compatibility_org_admin_delete ON exam_compatibility;
DROP POLICY IF EXISTS exam_compatibility_end_user_select ON exam_compatibility;

-- Super admin può vedere tutte le regole di compatibilità
CREATE POLICY exam_compatibility_super_admin_select ON exam_compatibility
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    );

-- Org admin può vedere le regole della propria organizzazione
CREATE POLICY exam_compatibility_org_admin_select ON exam_compatibility
    FOR SELECT
    TO authenticated
    USING (
        organization_id = get_my_organization_id()
    );

-- Super admin può inserire regole per qualsiasi organizzazione
CREATE POLICY exam_compatibility_super_admin_insert ON exam_compatibility
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    );

-- Org admin può inserire regole per la propria organizzazione
CREATE POLICY exam_compatibility_org_admin_insert ON exam_compatibility
    FOR INSERT
    TO authenticated
    WITH CHECK (
        organization_id = get_my_organization_id()
    );

-- Super admin può aggiornare qualsiasi regola
CREATE POLICY exam_compatibility_super_admin_update ON exam_compatibility
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    );

-- Org admin può aggiornare le regole della propria organizzazione
CREATE POLICY exam_compatibility_org_admin_update ON exam_compatibility
    FOR UPDATE
    TO authenticated
    USING (
        organization_id = get_my_organization_id()
    )
    WITH CHECK (
        organization_id = get_my_organization_id()
    );

-- Super admin può eliminare qualsiasi regola
CREATE POLICY exam_compatibility_super_admin_delete ON exam_compatibility
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'super_admin')
    );

-- Org admin può eliminare le regole della propria organizzazione
CREATE POLICY exam_compatibility_org_admin_delete ON exam_compatibility
    FOR DELETE
    TO authenticated
    USING (
        organization_id = get_my_organization_id()
    );

-- Policy per end_user: possono vedere le regole attive (per calcolo compatibilità)
CREATE POLICY exam_compatibility_end_user_select ON exam_compatibility
    FOR SELECT
    TO authenticated
    USING (
        is_active = true
    );
