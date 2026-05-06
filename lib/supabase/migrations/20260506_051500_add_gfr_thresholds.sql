-- Add GFR threshold configuration to organizations table
-- These thresholds determine when to show warning/critical alerts for low GFR values in TAC bookings

ALTER TABLE organizations 
ADD COLUMN IF NOT EXISTS gfr_warning_threshold DOUBLE PRECISION DEFAULT 60.0,
ADD COLUMN IF NOT EXISTS gfr_critical_threshold DOUBLE PRECISION DEFAULT 30.0;

-- Add constraints to ensure valid ranges
ALTER TABLE organizations 
ADD CONSTRAINT check_gfr_warning_range CHECK (gfr_warning_threshold >= 0 AND gfr_warning_threshold <= 200),
ADD CONSTRAINT check_gfr_critical_range CHECK (gfr_critical_threshold >= 0 AND gfr_critical_threshold <= 200),
ADD CONSTRAINT check_gfr_thresholds_order CHECK (gfr_critical_threshold <= gfr_warning_threshold);

-- Update existing organizations with default values
UPDATE organizations 
SET 
  gfr_warning_threshold = 60.0,
  gfr_critical_threshold = 30.0
WHERE gfr_warning_threshold IS NULL OR gfr_critical_threshold IS NULL;

-- Comments
COMMENT ON COLUMN organizations.gfr_warning_threshold IS 'GFR threshold (mL/min/1.73m²) below which a warning is shown for TAC bookings. Default: 60';
COMMENT ON COLUMN organizations.gfr_critical_threshold IS 'GFR threshold (mL/min/1.73m²) below which a critical alert is shown for TAC bookings. Default: 30';
