-- Migration: Add parent_booking_id to link package bookings together
-- When booking a package, one booking is created per exam, all linked via parent_booking_id

-- Add parent_booking_id column to bookings table
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS parent_booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL;

-- Create index for efficient queries on parent_booking_id
CREATE INDEX IF NOT EXISTS idx_bookings_parent_booking_id ON bookings(parent_booking_id);

-- Add comment for documentation
COMMENT ON COLUMN bookings.parent_booking_id IS 'Links child bookings to parent booking when created from a package';
