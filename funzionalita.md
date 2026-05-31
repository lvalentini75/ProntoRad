# ProntoRad - Funzionalità Implementate

> Documento di riepilogo delle funzionalità dell'applicazione ProntoRad, piattaforma cross-platform (Mobile + Web) per la prenotazione di esami radiologici.

---

## 🏛️ Architettura Generale

- **Frontend**: Flutter (Android, iOS, Web)
- **Backend**: Supabase (Auth, PostgreSQL, RLS, Edge Functions)
- **Navigazione**: `go_router` con due shell:
  - `MobileAppShell` (bottom navigation, mobile)
  - `AppShell` (sidebar, dashboard web)
- **Lingua UI**: Italiano | **Lingua codice**: Inglese
- **Stato**: Servizi singleton + chiamate dirette a Supabase

---

## 🔐 Autenticazione & Ruoli

- **Supabase Auth** con flusso PKCE
- `SupabaseAuthManager` singleton con cache di profilo e organizzazione
- **Ruoli supportati**:
  - `super_admin` — gestione globale piattaforma
  - `org_admin` — gestione singolo ospedale/struttura
  - `end_user` — paziente/utente finale
- `RolePolicies` per il mapping email → ruolo (es. `ospedale@prontorad.demo` → `org_admin`)
- Schermate dedicate:
  - Login mobile (`login_screen.dart`)
  - Login web (`web_login_screen.dart`)
  - Signup (`signup_screen.dart`)
  - Splash con auto-routing in base al ruolo

---

## 📱 Lato Mobile (Utente Finale)

### Flusso di Prenotazione
1. **Home** — riepilogo prenotazioni attive e accesso rapido
2. **Selezione Location** — scelta città/regione (dati italiani)
3. **Selezione Struttura** — lista ospedali/cliniche disponibili
4. **Selezione Esame** — catalogo esami offerti dalla struttura
5. **Selezione Pacchetto / Esami Multipli** — possibilità di prenotare più esami insieme
6. **Selezione Slot Orario** (`TimeSlotSheet`) con:
   - ⚠️ **Gestione Prerequisiti Obbligatori**: rilevamento automatico di esami propedeutici (es. RX prima di RM con MdC), ricerca slot disponibile, box informativo verde/arancione
   - 🟠 **Avviso Sale Diverse**: box arancione se prerequisito e esame principale si svolgono in sale differenti (regola di compatibilità `different_room`)
7. **Conferma Prenotazione** con PDF di riepilogo
8. **Stato Prenotazione** con timeline

### Altre Schermate Mobile
- **Bookings** — storico prenotazioni utente
- **Notifications** — centro notifiche
- **Profile** — dati personali e impostazioni
- **Support** — assistenza

---

## 🖥️ Dashboard Web

### Super Admin
- **Dashboard globale** con KPI di sistema
- **Gestione Organizzazioni** (ospedali/cliniche)
- **Gestione Utenti** (tutti gli utenti della piattaforma)
- **Anagrafica Esami** standard (`exams_registry_screen`)
- **Tariffe Standard** di riferimento

### Org Admin (Ospedale)
- **Profilo Ospedale** — dati, contatti, branding
- **Strutture/Facility** — sedi multiple per organizzazione
- **Esami Offerti** (`exam_offerings_screen`) — selezione esami erogati con tariffe custom
- **Esami Multipli** (ex "Pacchetti Esami") — bundle di esami prenotabili insieme
- **Compatibilità / Relazione Esami** (`exam_compatibility_screen`) con due tab:
  - **Tab "Relazione"** — regole tra esami (es. `different_room`, `same_room`, `sequential`)
  - **Tab "Prerequisiti"** — esami propedeutici obbligatori/opzionali
- **Gestione Tariffe** specifiche dell'ospedale
- **Gestione Disponibilità** (`availability_management_screen`) — slot orari per sala
- **Gestione Prenotazioni** (`bookings_admin_screen`)
- **Creazione Prenotazione Manuale** (`create_booking_admin_screen`)
- **KPI Ospedale** — metriche operative
- **🗓️ Planning Sale** (`planning_rooms_screen`) — **NUOVO**

### Planning Sale (Calendar Multi-Room)
Vista calendario giornaliera multi-sala, ispirata ai sistemi RIS ospedalieri:
- **Colonne**: una per ogni sala (es. `OCL_04_ANGIO_NEURO_01`, `OCL_05_US_01`)
- **Righe**: fasce orarie configurabili (default 15 min)
- **Orario lavorativo configurabile** per organizzazione (default 07:00–20:00)
- **Drag & Drop** delle prenotazioni tra sale e orari
- **Resize** della durata slot trascinando il bordo
- **Editing inline** delle prenotazioni
- **Configurazione per organizzazione**:
  - `planning_start_hour`
  - `planning_end_hour`
  - `planning_slot_minutes`

---

## 🗄️ Modello Dati (Supabase)

### Tabelle Principali
- `users` — anagrafica utenti con `role` e `organization_id`
- `organizations` — ospedali/cliniche + config planning
- `facilities` — sedi fisiche delle organizzazioni
- `rooms` — **NUOVO** — sale/macchinari fisici (con colore e codice)
- `exam_types` — anagrafica esami standard
- `facility_exam_offerings` — esami offerti per struttura
- `exam_packages` — esami multipli (bundle)
- `exam_prerequisites` — prerequisiti tra esami
- `exam_compatibility` — regole di relazione tra esami
- `availability_slots` — slot di disponibilità (con `room_id`)
- `bookings` — prenotazioni (con `room_id`)
- `standard_tariffs` / `tariffs` — tariffe standard e personalizzate
- `notifications` — notifiche utenti
- `audit_logs` — log azioni sensibili

### Sicurezza
- **Row Level Security (RLS)** su tutte le tabelle
- Funzioni helper SQL: `get_user_organization_id()`, `is_super_admin()`, etc.

---

## 🔧 Servizi Implementati

`lib/services/`:
- `user_service` · `organization_service` · `facility_service`
- `room_service` — **NUOVO**
- `exam_service` · `exam_package_service` · `exam_prerequisite_service`
- `facility_exam_offering_service`
- `availability_service` · `booking_service`
- `tariff_service` · `standard_tariff_service`
- `notification_service` · `audit_log_service`
- `profile_sync_service` · `debug_log_service`
- `demo_data_seeder` — popolamento dati dimostrativi

---

## 🌱 Dati Demo

Migrazioni dedicate alla creazione di dati dimostrativi:
- Utenti demo per ruoli (`paziente@prontorad.demo`, `ospedale@prontorad.demo`, `admin@prontorad.demo`)
- Associazione `ospedale@prontorad.demo` → **Ospedale Regionale di Bellinzona**
- Seed Planning Sale: 5 sale per organizzazione
  - 🔵 Risonanza Magnetica 1 (`SALA_RM_01`)
  - 🟢 TAC 1 (`SALA_TAC_01`)
  - 🟡 Ecografia 1 (`SALA_ECO_01`)
  - 🔴 Radiologia 1 (`SALA_RX_01`)
  - 🟣 Angiografia 1 (`SALA_ANGIO_01`)

---

## 📊 Utilità

- **PDF Reports** (`utils/pdf_reports.dart`) — generazione PDF conferma prenotazione
- **App Logger** (`utils/app_logger.dart`) — logging strutturato
- **Debug Log Viewer** — visualizzatore log in-app
- **Audit Logs** — tracciamento azioni critiche

---

## 🧭 Routing Principali

| Path | Schermata | Ruolo |
|------|-----------|-------|
| `/login` | Login mobile | tutti |
| `/web-login` | Login web | tutti |
| `/home` | Home mobile | end_user |
| `/bookings` | Storico prenotazioni | end_user |
| `/profile` | Profilo | end_user |
| `/dashboard` | Dashboard | super_admin / org_admin |
| `/dashboard/planning` | Planning Sale | org_admin |
| `/dashboard/bookings` | Prenotazioni admin | org_admin |
| `/dashboard/availability` | Disponibilità | org_admin |
| `/dashboard/exam-offerings` | Esami Offerti | org_admin |
| `/dashboard/exam-packages` | Esami Multipli | org_admin |
| `/dashboard/exam-compatibility` | Relazione/Prerequisiti | org_admin |
| `/dashboard/tariffs` | Tariffe | org_admin |
| `/dashboard/users` | Utenti | super_admin / org_admin |
| `/dashboard/organizations` | Organizzazioni | super_admin |
| `/dashboard/exams-registry` | Anagrafica Esami | super_admin |
| `/dashboard/kpi` | KPI | org_admin |

---

## 📌 Ultime Modifiche Rilevanti

1. ✅ Associazione `ospedale@prontorad.demo` → Ospedale Regionale di Bellinzona
2. ✅ Gestione prerequisiti obbligatori nello slot picker mobile
3. ✅ Box arancione "Sale Diverse" nel riepilogo prenotazione
4. ✅ Rinomina tab "Compatibilità" → "Relazione"
5. ✅ Rinomina "Pacchetti Esami" → "Esami Multipli"
6. ✅ **Nuova area Planning Sale** con drag & drop e resize
7. ✅ Tabella `rooms` + `room_id` su `availability_slots` e `bookings`
8. ✅ Configurazione planning per organizzazione (orari + slot minutes)
9. ✅ Seed dati dimostrativi Planning Sale (5 sale per organizzazione)

---

*Ultimo aggiornamento: generato automaticamente dall'agent Hologram.*
