-- Aggiungi campo onboarding_completed alla tabella organizations
-- per tracciare se l'organizzazione ha completato il wizard di configurazione iniziale

-- Aggiungi colonna se non esiste già
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'organizations' 
    AND column_name = 'onboarding_completed'
  ) THEN
    ALTER TABLE organizations 
    ADD COLUMN onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;
    
    COMMENT ON COLUMN organizations.onboarding_completed IS 'Indica se l''organizzazione ha completato il wizard di configurazione iniziale';
  END IF;
END $$;

-- Aggiorna le organizzazioni esistenti che hanno già dati configurati come completate
UPDATE organizations
SET onboarding_completed = TRUE
WHERE id IN (
  -- Considera completate le organizzazioni che hanno almeno un tariff definito
  SELECT DISTINCT organization_id 
  FROM tariffs
)
AND onboarding_completed = FALSE;
