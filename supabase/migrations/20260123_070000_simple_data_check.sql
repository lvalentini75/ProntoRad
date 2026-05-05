-- Check dei dati - Verifica semplice con SELECT che restituisce risultati

-- Check 1: Conta tutti i dati
SELECT 
    'exam_types' as tabella,
    COUNT(*) as totale_record
FROM exam_types
UNION ALL
SELECT 
    'organizations' as tabella,
    COUNT(*) as totale_record
FROM organizations
UNION ALL
SELECT 
    'tariffs' as tabella,
    COUNT(*) as totale_record
FROM tariffs
UNION ALL
SELECT 
    'availability_slots' as tabella,
    COUNT(*) as totale_record
FROM availability_slots
UNION ALL
SELECT 
    'bookings' as tabella,
    COUNT(*) as totale_record
FROM bookings
UNION ALL
SELECT 
    'users' as tabella,
    COUNT(*) as totale_record
FROM users
ORDER BY tabella;
