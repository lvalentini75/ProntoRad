-- Verifica le RLS policies attive

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('exam_types', 'organizations', 'tariffs', 'availability_slots', 'bookings')
ORDER BY tablename, policyname;
