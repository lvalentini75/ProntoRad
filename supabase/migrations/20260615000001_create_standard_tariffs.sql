-- Create standard_tariffs table for system-wide base pricing
-- Each organization can override these with their own tariffs

CREATE TABLE IF NOT EXISTS public.standard_tariffs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_type_id UUID NOT NULL REFERENCES public.exam_types(id) ON DELETE CASCADE,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Each exam type can have only one standard tariff
    CONSTRAINT unique_exam_standard_tariff UNIQUE (exam_type_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_standard_tariffs_exam_type_id ON public.standard_tariffs(exam_type_id);

-- Enable RLS
ALTER TABLE public.standard_tariffs ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- All authenticated users can read standard tariffs
CREATE POLICY "authenticated_read_standard_tariffs"
ON public.standard_tariffs
FOR SELECT
TO authenticated
USING (true);

-- Super admins can insert, update, delete
CREATE POLICY "super_admins_write_standard_tariffs"
ON public.standard_tariffs
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role = 'super_admin'
    )
);

CREATE POLICY "super_admins_update_standard_tariffs"
ON public.standard_tariffs
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role = 'super_admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role = 'super_admin'
    )
);

CREATE POLICY "super_admins_delete_standard_tariffs"
ON public.standard_tariffs
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE users.id = auth.uid()
        AND users.role = 'super_admin'
    )
);

-- Grant permissions
GRANT SELECT ON public.standard_tariffs TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.standard_tariffs TO authenticated;

-- Add comment
COMMENT ON TABLE public.standard_tariffs IS 'System-wide standard tariffs for exam types. Organizations can override these with their own prices.';
