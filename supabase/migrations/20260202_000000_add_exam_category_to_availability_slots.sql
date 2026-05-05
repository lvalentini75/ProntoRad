-- Aggiunge il supporto per exam_category in availability_slots
-- Permette di creare slot per macrocategoria (RM, TAC, ECO, RX) senza specificare exam_type_id

-- Step 1: Aggiungi la colonna exam_category se non esiste
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'availability_slots' 
    AND column_name = 'exam_category'
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE availability_slots
    ADD COLUMN exam_category TEXT;
    RAISE NOTICE 'Added exam_category column to availability_slots';
  ELSE
    RAISE NOTICE 'Column exam_category already exists';
  END IF;
END $$;

-- Step 2: Rimuovi il vincolo NOT NULL da exam_type_id
-- Ora uno slot può avere O exam_type_id O exam_category (o entrambi)
ALTER TABLE availability_slots
ALTER COLUMN exam_type_id DROP NOT NULL;

-- Step 3: Aggiungi un constraint CHECK per garantire che almeno uno sia valorizzato
ALTER TABLE availability_slots
DROP CONSTRAINT IF EXISTS availability_slots_exam_check;

ALTER TABLE availability_slots
ADD CONSTRAINT availability_slots_exam_check 
CHECK (
  exam_type_id IS NOT NULL OR exam_category IS NOT NULL
);

-- Step 4: Crea indice per performance su exam_category
CREATE INDEX IF NOT EXISTS idx_availability_slots_exam_category 
ON availability_slots(exam_category)
WHERE exam_category IS NOT NULL;

-- Step 5: Aggiorna la view per includere exam_category dalla tabella
DROP VIEW IF EXISTS availability_slots_with_org CASCADE;

CREATE OR REPLACE VIEW availability_slots_with_org AS
SELECT 
  s.*,
  o.name as organization_name,
  o.org_type as organization_type,
  COALESCE(e.name, s.exam_category) as exam_name,
  COALESCE(s.exam_category, e.category) as exam_category_resolved,
  e.body_district as exam_body_district
FROM availability_slots s
LEFT JOIN organizations o ON s.organization_id = o.id
LEFT JOIN exam_types e ON s.exam_type_id = e.id;

-- Grant access to the view
GRANT SELECT ON availability_slots_with_org TO authenticated;
GRANT SELECT ON availability_slots_with_org TO anon;

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Migration completed: exam_category column added to availability_slots';
  RAISE NOTICE 'Constraint updated: exam_type_id is now nullable';
  RAISE NOTICE 'CHECK constraint added: at least one of exam_type_id or exam_category must be set';
END $$;
