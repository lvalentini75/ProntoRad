-- Migration: Remove duplicate hospital "Ospedale Regionale di Bellinzona, San Giovanni"
-- Created: 2026-05-06
-- Description: Remove the duplicate Swiss hospital entry

-- First, let's identify and delete the duplicate
DO $$
DECLARE
    duplicate_id UUID;
    deleted_count INT := 0;
BEGIN
    -- Find the duplicate hospital (San Giovanni variant)
    SELECT id INTO duplicate_id
    FROM organizations
    WHERE name ILIKE '%Bellinzona%San Giovanni%'
    LIMIT 1;
    
    IF duplicate_id IS NOT NULL THEN
        -- Delete related records first (foreign key constraints)
        
        -- Delete availability_slots
        DELETE FROM availability_slots WHERE organization_id = duplicate_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'Deleted % availability_slots', deleted_count;
        
        -- Delete tariffs
        DELETE FROM tariffs WHERE organization_id = duplicate_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'Deleted % tariffs', deleted_count;
        
        -- Delete facility_exam_offerings for facilities of this organization
        DELETE FROM facility_exam_offerings 
        WHERE facility_id IN (SELECT id FROM facilities WHERE organization_id = duplicate_id);
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'Deleted % facility_exam_offerings', deleted_count;
        
        -- Delete bookings for facilities of this organization
        DELETE FROM bookings 
        WHERE facility_id IN (SELECT id FROM facilities WHERE organization_id = duplicate_id);
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'Deleted % bookings', deleted_count;
        
        -- Delete facilities
        DELETE FROM facilities WHERE organization_id = duplicate_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'Deleted % facilities', deleted_count;
        
        -- Update users to remove organization_id reference
        UPDATE users SET organization_id = NULL WHERE organization_id = duplicate_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'Updated % users (removed org reference)', deleted_count;
        
        -- Finally delete the organization
        DELETE FROM organizations WHERE id = duplicate_id;
        RAISE NOTICE 'Deleted duplicate organization: Ospedale Regionale di Bellinzona, San Giovanni (ID: %)', duplicate_id;
    ELSE
        RAISE NOTICE 'No duplicate hospital found with name containing Bellinzona San Giovanni';
    END IF;
END $$;

-- Verify remaining Swiss hospitals
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE '--- Remaining Swiss Hospitals ---';
    FOR rec IN 
        SELECT name, city, province 
        FROM organizations 
        WHERE country = 'Svizzera'
        ORDER BY name
    LOOP
        RAISE NOTICE 'Hospital: % - % (Canton: %)', rec.name, rec.city, rec.province;
    END LOOP;
END $$;
