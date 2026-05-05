-- ProntoRad - Demo Data Seed (idempotent)
-- Esegui questo script nello SQL Editor di Supabase (Project > SQL) con ruolo service.
-- Crea (se mancanti) tabelle di supporto e popola dati dimostrativi realistici:
-- - organizations (ospedali/istituti)
-- - facilities collegate all'organizzazione con exam set coerenti
-- - exam_types principali (inserimento protetto)
-- - tariffs per coppia (organization, exam_type)
-- - users applicativi (super_admin, org_admin, end_user) con link ad auth.users se l'email esiste
-- - bookings coerenti con facility ed exam disponibili

-- Safety: estensioni utili
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Safety: rimuovi un eventuale vincolo FK errato su public.users(id)
-- Alcuni ambienti possono avere un vincolo "users_id_fkey" che rende impossibile inserire nuove righe
-- perché l'ID di users viene forzato a referenziare un'altra tabella/si stesso.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_id_fkey'
  ) THEN
    BEGIN
      ALTER TABLE public.users DROP CONSTRAINT users_id_fkey;
    EXCEPTION WHEN others THEN NULL; END;
  END IF;
END $$;

-- Safety: assicurati che public.users.id abbia un default UUID se la tabella esiste ma è priva del default
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='users' AND column_name='id' AND column_default IS NULL
  ) THEN
    BEGIN
      ALTER TABLE public.users ALTER COLUMN id SET DEFAULT gen_random_uuid();
    EXCEPTION WHEN others THEN
      -- fallback: nessuna azione (alcuni ambienti potrebbero non consentire ALTER);
      -- in ogni caso gli INSERT sottostanti assegnano esplicitamente un UUID
      NULL;
    END;
  END IF;
END $$;

-- Safety: assicurati che le colonne fondamentali su users esistano
ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS role text;
-- Imposta default/NOT NULL su role in maniera sicura
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='users' AND column_name='role'
  ) THEN
    BEGIN
      ALTER TABLE public.users ALTER COLUMN role SET DEFAULT 'end_user';
      UPDATE public.users SET role = 'end_user' WHERE role IS NULL;
      ALTER TABLE public.users ALTER COLUMN role SET NOT NULL;
      -- opzionale: vincolo di check sul dominio dei ruoli
      IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_role_check') THEN
        ALTER TABLE public.users
          ADD CONSTRAINT users_role_check CHECK (role IN ('super_admin','org_admin','end_user'));
      END IF;
    EXCEPTION WHEN others THEN NULL; END;
  END IF;
END $$;

ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS organization_id uuid NULL;

ALTER TABLE IF EXISTS public.users
  ADD COLUMN IF NOT EXISTS auth_user_id uuid NULL;

-- Safety: assicurati che l'FK corretto colleghi users.auth_user_id -> auth.users(id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_auth_user_id_fkey'
  ) THEN
    BEGIN
      ALTER TABLE public.users
        ADD CONSTRAINT users_auth_user_id_fkey
        FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
    EXCEPTION WHEN others THEN NULL; END;
  END IF;
END $$;

-- 0) Tabella audit_logs (se non esiste)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name text NOT NULL,
  record_id text NOT NULL,
  action text NOT NULL CHECK (action IN ('create','update','delete')),
  user_id uuid NULL REFERENCES public.users(id) ON DELETE SET NULL,
  changes jsonb NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table ON public.audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.audit_logs(created_at);

-- 0b) Tabella tariffs (se non esiste)
CREATE TABLE IF NOT EXISTS public.tariffs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  exam_type_id uuid NOT NULL REFERENCES public.exam_types(id) ON DELETE CASCADE,
  price double precision NOT NULL,
  currency text NOT NULL DEFAULT 'EUR',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tariffs_org_exam_unique UNIQUE (organization_id, exam_type_id)
);
CREATE INDEX IF NOT EXISTS idx_tariffs_org ON public.tariffs(organization_id);
CREATE INDEX IF NOT EXISTS idx_tariffs_exam ON public.tariffs(exam_type_id);

-- 1) Exam types di base (insert protetto per nome)
WITH src(name, category, body_district, description) AS (
  VALUES
    ('RM Cervello', 'rm', 'testa', 'Risonanza magnetica encefalo'),
    ('RM Colonna Lombare', 'rm', 'estremita', 'Risonanza magnetica colonna lombare'),
    ('TAC Torace', 'tac', 'torace', 'Tomografia del torace ad alta risoluzione'),
    ('TAC Addome Completo', 'tac', 'addome', 'Tomografia addome completo con contrasto'),
    ('ECO Addome', 'eco', 'addome', 'Ecografia addome completo'),
    ('ECO Tiroide', 'eco', 'testa', 'Ecografia tiroide e collo'),
    ('RX Torace', 'rx', 'torace', 'Radiografia torace PA e LL'),
    ('RX Mano', 'rx', 'estremita', 'Radiografia mano in 2 proiezioni')
)
INSERT INTO public.exam_types (name, category, body_district, description)
SELECT s.name, s.category, s.body_district, s.description
FROM src s
WHERE NOT EXISTS (
  SELECT 1 FROM public.exam_types e WHERE lower(e.name) = lower(s.name)
);

-- 2) Organizations di esempio
WITH src(name, org_type, address, city, province, region) AS (
  VALUES
    ('Ospedale San Carlo', 'hospital', 'Via San Carlo 10', 'Milano', 'Milano', 'Lombardia'),
    ('Istituto Medico Aurora', 'institute', 'Viale Aurora 22', 'Roma', 'Roma', 'Lazio'),
    ('Policlinico Vesuvio', 'hospital', 'Via Vesuvio 8', 'Napoli', 'Napoli', 'Campania'),
    ('Centro Diagnostico Po', 'institute', 'Lungo Po 12', 'Torino', 'Torino', 'Piemonte'),
    ('Clinica Ionica', 'institute', 'Via Ionica 5', 'Taranto', 'Taranto', 'Puglia'),
    ('Ospedale Arno', 'hospital', 'Lungarno 45', 'Firenze', 'Firenze', 'Toscana')
)
INSERT INTO public.organizations (name, org_type, address, city, province, region)
SELECT s.name, s.org_type, s.address, s.city, s.province, s.region
FROM src s
WHERE NOT EXISTS (
  SELECT 1 FROM public.organizations o WHERE lower(o.name) = lower(s.name)
);

-- Safety: aggiungi FK users.organization_id -> organizations.id se manca
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_organization_id_fkey'
  ) THEN
    BEGIN
      ALTER TABLE public.users
        ADD CONSTRAINT users_organization_id_fkey
        FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE SET NULL;
    EXCEPTION WHEN others THEN NULL; END;
  END IF;
END $$;

-- 3) Facilities per organizzazione, con set di esami disponibili coerenti
-- Utility: array di id esami per categoria
WITH rm_ids AS (
  SELECT array_agg(id::text) AS ids FROM public.exam_types WHERE category = 'rm'
), tac_ids AS (
  SELECT array_agg(id::text) AS ids FROM public.exam_types WHERE category = 'tac'
), eco_ids AS (
  SELECT array_agg(id::text) AS ids FROM public.exam_types WHERE category = 'eco'
), rx_ids AS (
  SELECT array_agg(id::text) AS ids FROM public.exam_types WHERE category = 'rx'
),
src(name, address, city, province, region, latitude, longitude, type, base_price, organization_name, exam_set) AS (
  VALUES
    ('San Carlo Radiologia - Milano', 'Via Torino 5', 'Milano', 'Milano', 'Lombardia', 45.4642, 9.1900, 'public', 120.0, 'Ospedale San Carlo', 'rm+rx'),
    ('Aurora Imaging - Roma', 'Via Appia 100', 'Roma', 'Roma', 'Lazio', 41.9028, 12.4964, 'private', 140.0, 'Istituto Medico Aurora', 'tac+eco+rx'),
    ('Vesuvio Diagnostica', 'Via Foria 31', 'Napoli', 'Napoli', 'Campania', 40.8518, 14.2681, 'public', 110.0, 'Policlinico Vesuvio', 'rm+tac'),
    ('Centro Po Imaging', 'Corso Francia 20', 'Torino', 'Torino', 'Piemonte', 45.0703, 7.6869, 'private', 135.0, 'Centro Diagnostico Po', 'eco+rx'),
    ('Clinica Ionica - Taranto', 'Via Plateja 18', 'Taranto', 'Taranto', 'Puglia', 40.4644, 17.2470, 'private', 125.0, 'Clinica Ionica', 'tac+rx'),
    ('Arno Radiology', 'Viale dei Colli 7', 'Firenze', 'Firenze', 'Toscana', 43.7696, 11.2558, 'public', 118.0, 'Ospedale Arno', 'rm+eco')
)
INSERT INTO public.facilities (name, address, city, province, region, latitude, longitude, type, base_price, organization_id, available_exam_ids, parent_facility_id)
SELECT s.name, s.address, s.city, s.province, s.region, s.latitude, s.longitude, s.type, s.base_price,
       (SELECT id FROM public.organizations WHERE name = s.organization_name),
       CASE 
         WHEN s.exam_set = 'rm+rx' THEN (SELECT (SELECT ids FROM rm_ids) || (SELECT ids FROM rx_ids))
         WHEN s.exam_set = 'tac+eco+rx' THEN (SELECT (SELECT ids FROM tac_ids) || (SELECT ids FROM eco_ids) || (SELECT ids FROM rx_ids))
         WHEN s.exam_set = 'rm+tac' THEN (SELECT (SELECT ids FROM rm_ids) || (SELECT ids FROM tac_ids))
         WHEN s.exam_set = 'eco+rx' THEN (SELECT (SELECT ids FROM eco_ids) || (SELECT ids FROM rx_ids))
         WHEN s.exam_set = 'tac+rx' THEN (SELECT (SELECT ids FROM tac_ids) || (SELECT ids FROM rx_ids))
         WHEN s.exam_set = 'rm+eco' THEN (SELECT (SELECT ids FROM rm_ids) || (SELECT ids FROM eco_ids))
         ELSE ARRAY[]::text[]
       END,
       NULL -- seed: main facilities (no parent)
FROM src s
WHERE NOT EXISTS (
  SELECT 1 FROM public.facilities f WHERE lower(f.name) = lower(s.name)
);

-- 3b) Fix province abbreviations to full names (for existing data)
UPDATE public.facilities SET province = 'Milano' WHERE province = 'MI';
UPDATE public.facilities SET province = 'Roma' WHERE province = 'RM';
UPDATE public.facilities SET province = 'Napoli' WHERE province = 'NA';
UPDATE public.facilities SET province = 'Torino' WHERE province = 'TO';
UPDATE public.facilities SET province = 'Taranto' WHERE province = 'TA';
UPDATE public.facilities SET province = 'Firenze' WHERE province = 'FI';

UPDATE public.organizations SET province = 'Milano' WHERE province = 'MI';
UPDATE public.organizations SET province = 'Roma' WHERE province = 'RM';
UPDATE public.organizations SET province = 'Napoli' WHERE province = 'NA';
UPDATE public.organizations SET province = 'Torino' WHERE province = 'TO';
UPDATE public.organizations SET province = 'Taranto' WHERE province = 'TA';
UPDATE public.organizations SET province = 'Firenze' WHERE province = 'FI';

-- 4) Tariffs per (organization, exam_type)
-- Strategia: per ogni organization, genera prezzi coerenti per tutti gli exam_types
-- Prezzi: base per eco/rx 60–90€, tac 120–180€, rm 180–260€ (variazione leggera per istituto vs ospedale)
INSERT INTO public.tariffs (organization_id, exam_type_id, price, currency, created_at, updated_at)
SELECT o.id, e.id,
       CASE e.category
         WHEN 'eco' THEN 60 + (random() * 30)
         WHEN 'rx' THEN 55 + (random() * 25)
         WHEN 'tac' THEN 120 + (random() * 60)
         WHEN 'rm' THEN 180 + (random() * 80)
       END * CASE WHEN o.org_type = 'institute' THEN 1.05 ELSE 1.00 END,
       'EUR', now(), now()
FROM public.organizations o
CROSS JOIN public.exam_types e
WHERE NOT EXISTS (
  SELECT 1 FROM public.tariffs t WHERE t.organization_id = o.id AND t.exam_type_id = e.id
);

-- 5) Users applicativi: super_admin, alcuni org_admin, e utenti finali
-- 5a) Super admin specifico
INSERT INTO public.users (id, first_name, last_name, email, phone_number, role, created_at, updated_at)
SELECT gen_random_uuid(), 'Admin', 'ProntoRad', 'admin@prontorad.demo', '+39 0287 123456', 'super_admin', now(), now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.users u WHERE lower(u.email) = lower('admin@prontorad.demo')
);

-- 5b) Org admin associati a prime 3 organizzazioni
WITH orgs AS (
  SELECT id, name, row_number() OVER (ORDER BY name) AS rn FROM public.organizations
)
INSERT INTO public.users (id, first_name, last_name, email, phone_number, role, organization_id, created_at, updated_at)
SELECT gen_random_uuid(), 'Responsabile', split_part(o.name, ' ', 1),
       lower(replace(split_part(o.name, ' ', 1),'à','a')) || '.admin@demo.prontorad.it',
       '+39 06 ' || lpad((floor(random()*9000000)+1000000)::text, 7, '0'),
       'org_admin', o.id, now(), now()
FROM orgs o
WHERE o.rn <= 3
  AND NOT EXISTS (
    SELECT 1 FROM public.users u WHERE u.organization_id = o.id AND u.role = 'org_admin'
  );

-- 5c) 25 end_user dimostrativi
DO $$
DECLARE i int;
BEGIN
  FOR i IN 1..25 LOOP
    INSERT INTO public.users (id, first_name, last_name, email, phone_number, role, created_at, updated_at)
    SELECT gen_random_uuid(), 'Utente', 'Demo' || i::text, 'utente.demo' || i::text || '@example.com', '+39 333 ' || lpad((100000+i)::text, 7, '0'), 'end_user', now(), now()
    WHERE NOT EXISTS (
      SELECT 1 FROM public.users u WHERE lower(u.email) = lower('utente.demo' || i::text || '@example.com')
    );
  END LOOP;
END $$;

-- 5d) Link automatico a auth.users dove l'email coincide
UPDATE public.users u
SET auth_user_id = au.id,
    updated_at = now()
FROM auth.users au
WHERE u.auth_user_id IS NULL
  AND lower(u.email) = lower(au.email);

-- 6) Bookings dimostrative
-- Per ogni end_user, crea 2 prenotazioni scegliendo facility compatibile con exam_type
DO $$
DECLARE rec record; b int; chosen_fac uuid; chosen_exam uuid; price numeric;
BEGIN
  FOR rec IN (
    SELECT id AS user_id FROM public.users WHERE role = 'end_user' ORDER BY created_at LIMIT 25
  ) LOOP
    FOR b IN 1..2 LOOP
      -- scegli una facility casuale
      SELECT f.id INTO chosen_fac FROM public.facilities f ORDER BY random() LIMIT 1;
      -- scegli un exam_type compatibile con la facility
      SELECT e.id INTO chosen_exam
      FROM public.exam_types e
      WHERE e.id::text IN (
        SELECT unnest(f.available_exam_ids)
        FROM public.facilities f
        WHERE f.id = chosen_fac
      )
      ORDER BY random() LIMIT 1;
      IF chosen_exam IS NULL THEN
        CONTINUE;
      END IF;
      -- determina il prezzo: tariffa dell'organizzazione, altrimenti base_price facility
      SELECT t.price INTO price
      FROM public.tariffs t
      JOIN public.facilities f ON f.organization_id = t.organization_id
      WHERE f.id = chosen_fac AND t.exam_type_id = chosen_exam
      LIMIT 1;
      IF price IS NULL THEN
        SELECT base_price::numeric INTO price FROM public.facilities WHERE id = chosen_fac;
      END IF;
      INSERT INTO public.bookings (
        user_id, exam_type_id, facility_id,
        booking_date, booking_time, status, urgency_level, price,
        needs_transport, is_home_service, notes, created_at, updated_at
      )
      VALUES (
        rec.user_id, chosen_exam, chosen_fac,
        now() + (interval '1 day' * (1 + (random()*20)::int)),
        now() + (interval '1 day' * (1 + (random()*20)::int)),
        CASE WHEN random() < 0.2 THEN 'confirmed' ELSE 'requested' END,
        CASE WHEN random() < 0.1 THEN 'veryUrgent' WHEN random() < 0.3 THEN 'urgent' ELSE 'normal' END,
        round(price::numeric, 2),
        (random() < 0.1),
        (random() < 0.05),
        'Prenotazione demo', now(), now()
      );
    END LOOP;
  END LOOP;
END $$;

-- 7) Audit dei seed principali (facoltativo, crea una riga log per ogni organizzazione)
INSERT INTO public.audit_logs (table_name, record_id, action, user_id, changes, created_at)
SELECT 'organizations', o.id::text, 'create', NULL, jsonb_build_object('name', o.name), now()
FROM public.organizations o
WHERE NOT EXISTS (
  SELECT 1 FROM public.audit_logs a WHERE a.table_name = 'organizations' AND a.record_id = o.id::text AND a.action = 'create'
);

-- 8) facility_exam_offerings: collegamento esami disponibili per struttura con prezzi specifici
CREATE TABLE IF NOT EXISTS public.facility_exam_offerings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id uuid NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  exam_type_id uuid NOT NULL REFERENCES public.exam_types(id) ON DELETE CASCADE,
  price double precision NOT NULL,
  ssn_price double precision DEFAULT 0,
  duration_minutes int NOT NULL DEFAULT 30,
  preparation_notes text NULL,
  is_available boolean NOT NULL DEFAULT true,
  max_daily_bookings int NOT NULL DEFAULT 10,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT facility_exam_offerings_unique UNIQUE (facility_id, exam_type_id)
);
CREATE INDEX IF NOT EXISTS idx_feo_facility ON public.facility_exam_offerings(facility_id);
CREATE INDEX IF NOT EXISTS idx_feo_exam ON public.facility_exam_offerings(exam_type_id);

-- Popola facility_exam_offerings dalle facility esistenti
INSERT INTO public.facility_exam_offerings (facility_id, exam_type_id, price, ssn_price, duration_minutes, preparation_notes, is_available, max_daily_bookings)
SELECT 
  f.id,
  e.id,
  CASE e.category
    WHEN 'eco' THEN 70 + (random() * 30)
    WHEN 'rx' THEN 50 + (random() * 20)
    WHEN 'tac' THEN 150 + (random() * 50)
    WHEN 'rm' THEN 200 + (random() * 80)
  END * CASE WHEN f.type = 'private' THEN 1.2 ELSE 1.0 END,
  CASE e.category
    WHEN 'eco' THEN 20
    WHEN 'rx' THEN 15
    WHEN 'tac' THEN 36
    WHEN 'rm' THEN 56
  END,
  CASE e.category
    WHEN 'eco' THEN 20
    WHEN 'rx' THEN 15
    WHEN 'tac' THEN 45
    WHEN 'rm' THEN 60
  END,
  CASE e.category
    WHEN 'rm' THEN 'Rimuovere tutti gli oggetti metallici. Non mangiare 4 ore prima.'
    WHEN 'tac' THEN 'Se con mezzo di contrasto: digiuno da 6 ore. Portare esami precedenti.'
    WHEN 'eco' THEN 'Per ecografia addominale: digiuno da 8 ore, vescica piena.'
    ELSE 'Portare documentazione clinica precedente.'
  END,
  true,
  CASE e.category
    WHEN 'rm' THEN 6
    WHEN 'tac' THEN 10
    ELSE 15
  END
FROM public.facilities f
CROSS JOIN public.exam_types e
WHERE e.id::text = ANY(f.available_exam_ids)
  AND NOT EXISTS (
    SELECT 1 FROM public.facility_exam_offerings feo 
    WHERE feo.facility_id = f.id AND feo.exam_type_id = e.id
  );

-- 9) availability_slots: slot temporali per le prenotazioni
CREATE TABLE IF NOT EXISTS public.availability_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id uuid NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  exam_type_id uuid NULL REFERENCES public.exam_types(id) ON DELETE SET NULL,
  day_of_week int NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0=dom, 1=lun...6=sab
  specific_date date NULL,
  start_time time NOT NULL,
  end_time time NOT NULL,
  max_bookings int NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  notes text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT slot_has_day_or_date CHECK (day_of_week IS NOT NULL OR specific_date IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS idx_slots_facility ON public.availability_slots(facility_id);
CREATE INDEX IF NOT EXISTS idx_slots_day ON public.availability_slots(day_of_week);
CREATE INDEX IF NOT EXISTS idx_slots_date ON public.availability_slots(specific_date);

-- Popola slot ricorrenti settimanali per ogni facility (lun-ven, mattina e pomeriggio)
DO $$
DECLARE 
  fac record;
  d int;
BEGIN
  FOR fac IN (SELECT id FROM public.facilities) LOOP
    FOR d IN 1..5 LOOP -- lun(1) a ven(5)
      -- Slot mattutini
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '08:00'::time, '08:30'::time, 2, 'Slot mattutino'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '08:00'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '08:30'::time, '09:00'::time, 2, 'Slot mattutino'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '08:30'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '09:00'::time, '09:30'::time, 2, 'Slot mattutino'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '09:00'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '09:30'::time, '10:00'::time, 2, 'Slot mattutino'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '09:30'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '10:00'::time, '10:30'::time, 2, 'Slot mattutino'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '10:00'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '10:30'::time, '11:00'::time, 2, 'Slot mattutino'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '10:30'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '11:00'::time, '11:30'::time, 2, 'Slot mattutino'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '11:00'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '11:30'::time, '12:00'::time, 2, 'Slot mattutino'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '11:30'::time
      );
      -- Slot pomeridiani
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '14:00'::time, '14:30'::time, 2, 'Slot pomeridiano'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '14:00'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '14:30'::time, '15:00'::time, 2, 'Slot pomeridiano'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '14:30'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '15:00'::time, '15:30'::time, 2, 'Slot pomeridiano'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '15:00'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '15:30'::time, '16:00'::time, 2, 'Slot pomeridiano'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '15:30'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '16:00'::time, '16:30'::time, 2, 'Slot pomeridiano'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '16:00'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '16:30'::time, '17:00'::time, 2, 'Slot pomeridiano'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '16:30'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '17:00'::time, '17:30'::time, 2, 'Slot pomeridiano'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '17:00'::time
      );
      INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
      SELECT fac.id, d, '17:30'::time, '18:00'::time, 2, 'Slot pomeridiano'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.availability_slots s 
        WHERE s.facility_id = fac.id AND s.day_of_week = d AND s.start_time = '17:30'::time
      );
    END LOOP;
    -- Sabato solo mattina
    INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
    SELECT fac.id, 6, '08:30'::time, '09:00'::time, 2, 'Sabato mattina'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.availability_slots s 
      WHERE s.facility_id = fac.id AND s.day_of_week = 6 AND s.start_time = '08:30'::time
    );
    INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
    SELECT fac.id, 6, '09:00'::time, '09:30'::time, 2, 'Sabato mattina'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.availability_slots s 
      WHERE s.facility_id = fac.id AND s.day_of_week = 6 AND s.start_time = '09:00'::time
    );
    INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
    SELECT fac.id, 6, '09:30'::time, '10:00'::time, 2, 'Sabato mattina'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.availability_slots s 
      WHERE s.facility_id = fac.id AND s.day_of_week = 6 AND s.start_time = '09:30'::time
    );
    INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
    SELECT fac.id, 6, '10:00'::time, '10:30'::time, 2, 'Sabato mattina'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.availability_slots s 
      WHERE s.facility_id = fac.id AND s.day_of_week = 6 AND s.start_time = '10:00'::time
    );
    INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
    SELECT fac.id, 6, '10:30'::time, '11:00'::time, 2, 'Sabato mattina'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.availability_slots s 
      WHERE s.facility_id = fac.id AND s.day_of_week = 6 AND s.start_time = '10:30'::time
    );
    INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
    SELECT fac.id, 6, '11:00'::time, '11:30'::time, 2, 'Sabato mattina'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.availability_slots s 
      WHERE s.facility_id = fac.id AND s.day_of_week = 6 AND s.start_time = '11:00'::time
    );
    INSERT INTO public.availability_slots (facility_id, day_of_week, start_time, end_time, max_bookings, notes)
    SELECT fac.id, 6, '11:30'::time, '12:00'::time, 2, 'Sabato mattina'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.availability_slots s 
      WHERE s.facility_id = fac.id AND s.day_of_week = 6 AND s.start_time = '11:30'::time
    );
  END LOOP;
END $$;

-- Fine: dati demo creati. Esecuzione idempotente (puoi rilanciare senza duplicati principali)

-- 10) RLS: politiche di lettura pubblica per mostrare i dati in app
-- Nota: queste policy sono idempotenti e si applicano solo se mancanti.

-- Helper: crea policy di sola lettura per anon+authenticated se non esiste
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['exam_types','facilities','organizations','tariffs','bookings','facility_exam_offerings','availability_slots'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=t AND policyname='read_all'
    ) THEN
      EXECUTE format('CREATE POLICY read_all ON public.%I FOR SELECT TO anon, authenticated USING (true)', t);
    END IF;
  END LOOP;
END $$;

-- Policy minime su users per permettere al client di leggere/creare il proprio profilo
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='users' AND policyname='select_own'
  ) THEN
    CREATE POLICY select_own ON public.users FOR SELECT TO authenticated USING (
      (auth.uid() IS NOT NULL AND auth.uid() = auth_user_id)
      OR (lower(email) = lower(current_setting('request.jwt.claims', true)::json->>'email'))
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='users' AND policyname='insert_self'
  ) THEN
    CREATE POLICY insert_self ON public.users FOR INSERT TO authenticated WITH CHECK (
      (auth.uid() IS NOT NULL AND auth.uid() = auth_user_id)
      OR (lower(email) = lower(current_setting('request.jwt.claims', true)::json->>'email'))
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='users' AND policyname='update_self'
  ) THEN
    CREATE POLICY update_self ON public.users FOR UPDATE TO authenticated USING (
      (auth.uid() IS NOT NULL AND auth.uid() = auth_user_id)
      OR (lower(email) = lower(current_setting('request.jwt.claims', true)::json->>'email'))
    ) WITH CHECK (
      (auth.uid() IS NOT NULL AND auth.uid() = auth_user_id)
      OR (lower(email) = lower(current_setting('request.jwt.claims', true)::json->>'email'))
    );
  END IF;
END $$;
