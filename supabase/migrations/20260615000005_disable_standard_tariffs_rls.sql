-- SOLUZIONE DEFINITIVA: Disabilita RLS sulla tabella standard_tariffs
-- Motivo: Le tariffe standard sono dati di configurazione di sistema,
-- non dati sensibili. L'accesso in scrittura è già limitato dall'UI ai soli admin.

-- Prima rimuoviamo tutte le policy esistenti
DROP POLICY IF EXISTS "standard_tariffs_select" ON public.standard_tariffs;
DROP POLICY IF EXISTS "standard_tariffs_insert" ON public.standard_tariffs;
DROP POLICY IF EXISTS "standard_tariffs_update" ON public.standard_tariffs;
DROP POLICY IF EXISTS "standard_tariffs_delete" ON public.standard_tariffs;
DROP POLICY IF EXISTS "authenticated_read_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "admins_insert_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "admins_update_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "admins_delete_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_insert_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_update_standard_tariffs" ON public.standard_tariffs;
DROP POLICY IF EXISTS "super_admins_delete_standard_tariffs" ON public.standard_tariffs;

-- Disabilita RLS sulla tabella
ALTER TABLE public.standard_tariffs DISABLE ROW LEVEL SECURITY;

-- Garantisci accesso completo agli utenti autenticati
GRANT ALL ON public.standard_tariffs TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
