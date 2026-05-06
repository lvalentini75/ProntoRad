-- Migration: Add country column to organizations table
-- Date: 2026-05-05
-- Description: Add support for Switzerland in addition to Italy

-- Add country column to organizations table with default 'Italia'
ALTER TABLE organizations 
ADD COLUMN IF NOT EXISTS country TEXT DEFAULT 'Italia' NOT NULL;

-- Update any existing records to have 'Italia' as country (redundant but safe)
UPDATE organizations SET country = 'Italia' WHERE country IS NULL OR country = '';

-- Add comment for documentation
COMMENT ON COLUMN organizations.country IS 'Country where the organization is located (Italia or Svizzera)';

-- Create index for faster filtering by country
CREATE INDEX IF NOT EXISTS idx_organizations_country ON organizations(country);
