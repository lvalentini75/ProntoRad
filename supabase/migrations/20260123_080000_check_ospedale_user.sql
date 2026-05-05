-- Verifica l'utente ospedale@prontorad.demo

SELECT 
    u.id,
    u.email,
    u.first_name,
    u.last_name,
    u.role,
    u.organization_id,
    o.name as organization_name,
    o.org_type,
    o.onboarding_completed
FROM users u
LEFT JOIN organizations o ON u.organization_id = o.id
WHERE u.email = 'ospedale@prontorad.demo';
