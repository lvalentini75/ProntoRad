-- ============================================================
-- Demo data per il Planning Sale (multi-room calendar view)
--   - Crea 5 sale di esempio per ogni organizzazione esistente
--     (solo se non ne ha già)
--   - Assegna room_id alle prenotazioni di oggi (e ne crea alcune
--     se l'organizzazione non ne ha per oggi)
-- ============================================================

DO $$
DECLARE
  v_org RECORD;
  v_room_ids UUID[];
  v_user_id UUID;
  v_exam_id UUID;
  v_facility_id UUID;
  v_existing_today INT;
  v_today_bookings RECORD;
  i INT;
  v_hour INT;
  v_minute INT;
  v_booking_time TIMESTAMPTZ;
  v_status TEXT;
  v_room_palette TEXT[] := ARRAY['#3B82F6','#10B981','#F59E0B','#EF4444','#8B5CF6'];
  v_room_codes  TEXT[] := ARRAY['SALA_RM_01','SALA_TAC_01','SALA_ECO_01','SALA_RX_01','SALA_ANGIO_01'];
  v_room_names  TEXT[] := ARRAY['Risonanza Magnetica 1','TAC 1','Ecografia 1','Radiologia 1','Angiografia 1'];
  v_statuses    TEXT[] := ARRAY['confirmed','requested','confirmed','confirmed','completed'];
BEGIN
  -- Loop su ogni organizzazione
  FOR v_org IN SELECT id, name FROM public.organizations LOOP

    -- ============ 1) ROOMS ============
    -- Crea le sale solo se l'organizzazione non ne ha
    IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE organization_id = v_org.id) THEN
      FOR i IN 1..5 LOOP
        INSERT INTO public.rooms (
          organization_id, name, code, color, description, display_order, is_active
        ) VALUES (
          v_org.id,
          v_room_names[i],
          v_room_codes[i],
          v_room_palette[i],
          'Sala demo per ' || v_org.name,
          i - 1,
          true
        );
      END LOOP;
      RAISE NOTICE 'Created 5 rooms for organization %', v_org.name;
    END IF;

    -- Recupera gli id delle sale di questa org
    SELECT array_agg(id ORDER BY display_order)
      INTO v_room_ids
      FROM public.rooms
     WHERE organization_id = v_org.id AND is_active = true;

    IF v_room_ids IS NULL OR array_length(v_room_ids, 1) = 0 THEN
      CONTINUE;
    END IF;

    -- ============ 2) ASSEGNA room_id a prenotazioni di oggi ============
    -- Round-robin sulle sale, solo se room_id è NULL
    i := 1;
    FOR v_today_bookings IN
      SELECT b.id
        FROM public.bookings b
       WHERE b.organization_id = v_org.id
         AND b.room_id IS NULL
         AND DATE(b.booking_time) = CURRENT_DATE
       ORDER BY b.booking_time
    LOOP
      UPDATE public.bookings
         SET room_id = v_room_ids[((i - 1) % array_length(v_room_ids, 1)) + 1],
             updated_at = NOW()
       WHERE id = v_today_bookings.id;
      i := i + 1;
    END LOOP;

    -- ============ 3) CREA prenotazioni demo per oggi se mancano ============
    SELECT COUNT(*) INTO v_existing_today
      FROM public.bookings
     WHERE organization_id = v_org.id
       AND DATE(booking_time) = CURRENT_DATE;

    IF v_existing_today < 8 THEN
      -- Trova un utente end_user (qualunque) per le prenotazioni demo
      SELECT id INTO v_user_id
        FROM public.users
       WHERE role = 'end_user'
       LIMIT 1;

      -- Trova un facility dell'org (per coerenza)
      SELECT id INTO v_facility_id
        FROM public.facilities
       WHERE organization_id = v_org.id
       LIMIT 1;

      IF v_user_id IS NOT NULL THEN
        -- Inserisci 10 prenotazioni distribuite nella giornata
        FOR i IN 1..10 LOOP
          -- Trova un exam_type tipicamente offerto
          SELECT id INTO v_exam_id
            FROM public.exam_types
            ORDER BY random()
           LIMIT 1;

          IF v_exam_id IS NULL THEN
            EXIT; -- nessun exam_type disponibile
          END IF;

          -- Orari distribuiti dalle 08:00 alle 18:00 ogni ~1h
          v_hour := 8 + ((i - 1) % 10);
          v_minute := CASE WHEN i % 2 = 0 THEN 30 ELSE 0 END;
          v_booking_time := (CURRENT_DATE + (v_hour || ':' || v_minute || ':00')::TIME)::TIMESTAMPTZ;
          v_status := v_statuses[((i - 1) % 5) + 1];

          INSERT INTO public.bookings (
            user_id,
            exam_type_id,
            organization_id,
            facility_id,
            room_id,
            booking_date,
            booking_time,
            status,
            urgency_level,
            price,
            needs_transport,
            is_home_service,
            notes,
            created_at,
            updated_at
          ) VALUES (
            v_user_id,
            v_exam_id,
            v_org.id,
            v_facility_id,
            v_room_ids[((i - 1) % array_length(v_room_ids, 1)) + 1],
            CURRENT_DATE,
            v_booking_time,
            v_status,
            'normal',
            (50 + (random() * 250))::NUMERIC(10,2),
            false,
            false,
            'Prenotazione demo Planning Sale',
            NOW(),
            NOW()
          );
        END LOOP;
        RAISE NOTICE 'Created demo bookings for today for organization %', v_org.name;
      END IF;
    END IF;

  END LOOP;
END $$;

-- ============ 4) SLOT di disponibilità per le sale ============
-- Aggiunge room_id ad alcuni slot ricorrenti esistenti (round-robin per facility)
DO $$
DECLARE
  v_org RECORD;
  v_room_ids UUID[];
  v_slot RECORD;
  i INT;
BEGIN
  FOR v_org IN SELECT id FROM public.organizations LOOP
    SELECT array_agg(id ORDER BY display_order)
      INTO v_room_ids
      FROM public.rooms
     WHERE organization_id = v_org.id AND is_active = true;

    IF v_room_ids IS NULL OR array_length(v_room_ids, 1) = 0 THEN
      CONTINUE;
    END IF;

    i := 1;
    FOR v_slot IN
      SELECT s.id
        FROM public.availability_slots s
        JOIN public.facilities f ON f.id = s.facility_id
       WHERE f.organization_id = v_org.id
         AND s.room_id IS NULL
       LIMIT 30
    LOOP
      UPDATE public.availability_slots
         SET room_id = v_room_ids[((i - 1) % array_length(v_room_ids, 1)) + 1]
       WHERE id = v_slot.id;
      i := i + 1;
    END LOOP;
  END LOOP;
END $$;
