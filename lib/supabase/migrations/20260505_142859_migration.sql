-- Migration: Add notifications table for booking status updates
-- Date: 2026-05-05

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'info',
    booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster user notification queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(user_id, is_read);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own notifications
CREATE POLICY notifications_select_own ON notifications
    FOR SELECT
    USING (
        user_id IN (
            SELECT id FROM users WHERE auth_user_id = auth.uid()
        )
    );

-- Policy: Users can update their own notifications (mark as read)
CREATE POLICY notifications_update_own ON notifications
    FOR UPDATE
    USING (
        user_id IN (
            SELECT id FROM users WHERE auth_user_id = auth.uid()
        )
    )
    WITH CHECK (true);

-- Policy: Users can delete their own notifications
CREATE POLICY notifications_delete_own ON notifications
    FOR DELETE
    USING (
        user_id IN (
            SELECT id FROM users WHERE auth_user_id = auth.uid()
        )
    );

-- Policy: Service role and org_admin can insert notifications for any user
CREATE POLICY notifications_insert_service ON notifications
    FOR INSERT
    WITH CHECK (true);

-- Add comment
COMMENT ON TABLE notifications IS 'User notifications for booking status changes and alerts';
