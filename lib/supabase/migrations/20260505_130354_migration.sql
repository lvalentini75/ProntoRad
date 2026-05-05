-- Add GFR (Glomerular Filtration Rate) field to bookings table
-- GFR is required for TAC (CT) exams with contrast medium

ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS gfr_value DOUBLE PRECISION;

-- Add comment to document the column purpose
COMMENT ON COLUMN bookings.gfr_value IS 'GFR (Glomerular Filtration Rate) value in mL/min/1.73m² - required for TAC exams with contrast';
