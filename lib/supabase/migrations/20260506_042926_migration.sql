-- Migration: Add tariffs and availability slots for Swiss hospitals
-- Date: 2026-05-06
-- Description: Swiss hospitals exist but have no tariffs/slots - this is why they don't appear in search

-- Step 1: Insert tariffs for all Swiss hospitals for all exam types (CHF currency)
DO $$
DECLARE
  org_rec RECORD;
  exam_rec RECORD;
  inserted_tariffs INTEGER := 0;
  inserted_slots INTEGER := 0;
  bellinzona_id UUID;
BEGIN
  RAISE NOTICE '==========================================';
  RAISE NOTICE 'STARTING: Swiss hospitals tariffs & slots';
  RAISE NOTICE '==========================================';

  -- Get Bellinzona ID for later use
  SELECT id INTO bellinzona_id
  FROM organizations
  WHERE name = 'Ospedale Regionale di Bellinzona'
  LIMIT 1;
  
  RAISE NOTICE 'Bellinzona ID: %', bellinzona_id;

  -- Loop through all Swiss hospitals
  FOR org_rec IN 
    SELECT id, name 
    FROM organizations 
    WHERE country = 'Svizzera'
  LOOP
    RAISE NOTICE 'Processing: % (ID: %)', org_rec.name, org_rec.id;
    
    -- Insert tariffs for each exam type
    FOR exam_rec IN 
      SELECT id, name, category 
      FROM exam_types
    LOOP
      -- Insert tariff if not exists
      INSERT INTO tariffs (
        id,
        exam_type_id,
        organization_id,
        price,
        currency,
        created_at,
        updated_at
      ) 
      SELECT
        gen_random_uuid(),
        exam_rec.id,
        org_rec.id,
        CASE 
          WHEN exam_rec.category = 'RM' THEN 450.00 + (random() * 100)::numeric(10,2)
          WHEN exam_rec.category = 'TAC' THEN 350.00 + (random() * 80)::numeric(10,2)
          WHEN exam_rec.category = 'ECO' THEN 150.00 + (random() * 50)::numeric(10,2)
          WHEN exam_rec.category = 'RX' THEN 80.00 + (random() * 30)::numeric(10,2)
          ELSE 200.00
        END,
        'CHF',
        NOW(),
        NOW()
      WHERE NOT EXISTS (
        SELECT 1 FROM tariffs 
        WHERE exam_type_id = exam_rec.id 
        AND organization_id = org_rec.id
      );
      
      IF FOUND THEN
        inserted_tariffs := inserted_tariffs + 1;
      END IF;
    END LOOP;
  END LOOP;
  
  RAISE NOTICE 'Inserted % tariffs for Swiss hospitals', inserted_tariffs;
  
  -- Step 2: Insert availability slots for Ospedale Regionale di Bellinzona
  -- Create slots for the next 30 days for all exam categories
  IF bellinzona_id IS NOT NULL THEN
    RAISE NOTICE 'Creating availability slots for Bellinzona...';
    
    -- Insert RM slots (9:00-12:00, 14:00-17:00 for next 30 days)
    FOR i IN 0..29 LOOP
      -- Morning slot 9:00-12:00
      INSERT INTO availability_slots (
        id,
        organization_id,
        exam_category,
        specific_date,
        day_of_week,
        start_time,
        end_time,
        max_bookings,
        is_active,
        notes,
        created_at,
        updated_at
      ) VALUES (
        gen_random_uuid(),
        bellinzona_id,
        'RM',
        CURRENT_DATE + i,
        EXTRACT(DOW FROM CURRENT_DATE + i)::int,
        '09:00:00',
        '12:00:00',
        3,
        TRUE,
        'Slot RM mattina',
        NOW(),
        NOW()
      ) ON CONFLICT DO NOTHING;
      
      -- Afternoon slot 14:00-17:00
      INSERT INTO availability_slots (
        id,
        organization_id,
        exam_category,
        specific_date,
        day_of_week,
        start_time,
        end_time,
        max_bookings,
        is_active,
        notes,
        created_at,
        updated_at
      ) VALUES (
        gen_random_uuid(),
        bellinzona_id,
        'RM',
        CURRENT_DATE + i,
        EXTRACT(DOW FROM CURRENT_DATE + i)::int,
        '14:00:00',
        '17:00:00',
        3,
        TRUE,
        'Slot RM pomeriggio',
        NOW(),
        NOW()
      ) ON CONFLICT DO NOTHING;
      
      inserted_slots := inserted_slots + 2;
    END LOOP;
    
    -- Insert TAC slots
    FOR i IN 0..29 LOOP
      INSERT INTO availability_slots (
        id,
        organization_id,
        exam_category,
        specific_date,
        day_of_week,
        start_time,
        end_time,
        max_bookings,
        is_active,
        notes,
        created_at,
        updated_at
      ) VALUES (
        gen_random_uuid(),
        bellinzona_id,
        'TAC',
        CURRENT_DATE + i,
        EXTRACT(DOW FROM CURRENT_DATE + i)::int,
        '08:00:00',
        '18:00:00',
        5,
        TRUE,
        'Slot TAC giornaliero',
        NOW(),
        NOW()
      ) ON CONFLICT DO NOTHING;
      
      inserted_slots := inserted_slots + 1;
    END LOOP;
    
    -- Insert ECO slots
    FOR i IN 0..29 LOOP
      INSERT INTO availability_slots (
        id,
        organization_id,
        exam_category,
        specific_date,
        day_of_week,
        start_time,
        end_time,
        max_bookings,
        is_active,
        notes,
        created_at,
        updated_at
      ) VALUES (
        gen_random_uuid(),
        bellinzona_id,
        'ECO',
        CURRENT_DATE + i,
        EXTRACT(DOW FROM CURRENT_DATE + i)::int,
        '08:30:00',
        '17:30:00',
        8,
        TRUE,
        'Slot Ecografia giornaliero',
        NOW(),
        NOW()
      ) ON CONFLICT DO NOTHING;
      
      inserted_slots := inserted_slots + 1;
    END LOOP;
    
    -- Insert RX slots
    FOR i IN 0..29 LOOP
      INSERT INTO availability_slots (
        id,
        organization_id,
        exam_category,
        specific_date,
        day_of_week,
        start_time,
        end_time,
        max_bookings,
        is_active,
        notes,
        created_at,
        updated_at
      ) VALUES (
        gen_random_uuid(),
        bellinzona_id,
        'RX',
        CURRENT_DATE + i,
        EXTRACT(DOW FROM CURRENT_DATE + i)::int,
        '07:00:00',
        '19:00:00',
        15,
        TRUE,
        'Slot Radiografia giornaliero',
        NOW(),
        NOW()
      ) ON CONFLICT DO NOTHING;
      
      inserted_slots := inserted_slots + 1;
    END LOOP;
    
    RAISE NOTICE 'Inserted % availability slots for Bellinzona', inserted_slots;
  ELSE
    RAISE NOTICE 'WARNING: Bellinzona hospital not found!';
  END IF;
  
  -- Step 3: Diagnostic - show final status
  RAISE NOTICE '==========================================';
  RAISE NOTICE 'DIAGNOSTIC: Organizations with tariffs';
  RAISE NOTICE '==========================================';
  
  FOR org_rec IN 
    SELECT 
      o.name, 
      o.country,
      COUNT(DISTINCT t.exam_type_id) as tariff_count,
      COUNT(DISTINCT s.id) as slot_count
    FROM organizations o
    LEFT JOIN tariffs t ON t.organization_id = o.id
    LEFT JOIN availability_slots s ON s.organization_id = o.id AND s.is_active = TRUE
    GROUP BY o.id, o.name, o.country
    ORDER BY o.country, o.name
  LOOP
    RAISE NOTICE '  % (%): % tariffs, % active slots', 
                 org_rec.name, org_rec.country, org_rec.tariff_count, org_rec.slot_count;
  END LOOP;
  
  RAISE NOTICE '==========================================';
  RAISE NOTICE 'MIGRATION COMPLETED SUCCESSFULLY';
  RAISE NOTICE '==========================================';
END $$;
