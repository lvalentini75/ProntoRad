# ProntoRad - Documentazione Funzionalità

## Indice
1. [Panoramica Generale](#panoramica-generale)
2. [Autenticazione e Ruoli](#autenticazione-e-ruoli)
3. [App Mobile (End User)](#app-mobile-end-user)
4. [Dashboard Web (Amministrazione)](#dashboard-web-amministrazione)
5. [Gestione Prenotazioni](#gestione-prenotazioni)
6. [Gestione Esami](#gestione-esami)
7. [Gestione Strutture/Organizzazioni](#gestione-struttureorganizzazioni)
8. [Sistema Tariffe](#sistema-tariffe)
9. [Gestione Disponibilità](#gestione-disponibilità)
10. [Analytics e KPI](#analytics-e-kpi)
11. [Gestione Utenti](#gestione-utenti)
12. [Audit Log](#audit-log)
13. [Supporto e Assistenza](#supporto-e-assistenza)

---

## Panoramica Generale

**ProntoRad** è un'applicazione cross-platform (Android, iOS, Web) per la prenotazione di esami radiologici in Italia.

### Tecnologie Utilizzate
- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL + Auth + Edge Functions + RLS)
- **Navigazione**: go_router
- **Package**: xraynow

### Piattaforme Target
- **Mobile**: App nativa per end user (Android, iOS)
- **Web**: Dashboard amministrativa per super_admin e org_admin

### Tipologie di Esami Supportati
- **RM** (Risonanza Magnetica)
- **TAC** (Tomografia Assiale Computerizzata)
- **ECO** (Ecografia)
- **RX** (Radiografia)

### Distretti Corporei
- Testa
- Torace
- Addome
- Estremità

---

## Autenticazione e Ruoli

### Sistema di Autenticazione
- **Provider**: Supabase Auth con PKCE flow
- **Metodi supportati**: Email/Password
- **Gestione**: `SupabaseAuthManager` singleton
- **Cache profilo**: Profilo utente e organizzazione salvati in cache per performance ottimali

### Ruoli Utente

#### 1. **Super Admin** (`super_admin`)
- **Accesso completo** a tutte le funzionalità della piattaforma
- **Gestione globale** di utenti, organizzazioni, esami, tariffe
- **Analytics e KPI** di tutto il sistema
- **Email configurate**: `admin@prontorad.demo`

#### 2. **Organization Admin** (`org_admin`)
- **Gestione della propria struttura ospedaliera**
- **Prenotazioni**: visualizza e gestisce solo le prenotazioni della propria organizzazione
- **Offerte esami**: configura quali esami offre la struttura
- **Tariffe personalizzate**: imposta prezzi specifici per i propri esami
- **Disponibilità**: gestisce gli slot disponibili
- **Email configurate**: `ospedale@prontorad.demo`

#### 3. **End User** (`end_user`)
- **Prenotazione esami** tramite app mobile
- **Visualizzazione storico** delle proprie prenotazioni
- **Profilo personale**: gestione dati anagrafici
- **Supporto**: accesso a FAQ e contatti

### Policy Ruoli
I ruoli sono enforced tramite email mapping in `lib/config/role_policies.dart`:
```dart
static final Map<String, String> enforcedEmailRoles = {
  'admin@prontorad.demo': 'super_admin',
  'ospedale@prontorad.demo': 'org_admin',
};
```

### Row Level Security (RLS)
Tutte le tabelle Supabase utilizzano politiche RLS per garantire che:
- Gli utenti vedano solo i propri dati
- Gli org_admin vedano solo i dati della propria organizzazione
- I super_admin abbiano accesso completo

---

## App Mobile (End User)

### Navigazione Bottom Bar
L'app mobile utilizza una bottom navigation bar con 4 sezioni principali:

#### 1. **Home** (`/home`)
- **Schermata principale** con 4 categorie di esami visualizzate come card:
  - RM (Risonanza Magnetica)
  - TAC (Tomografia)
  - ECO (Ecografia)
  - RX (Radiografia)
- **Design**: Card colorate con icone e descrizioni
- **Azione**: Tap su categoria avvia il flusso di prenotazione

#### 2. **Le Mie Prenotazioni** (`/bookings`)
- **Lista completa** delle prenotazioni dell'utente
- **Ordinamento**: Per data (più recenti prima)
- **Informazioni visualizzate**:
  - Tipo esame
  - Struttura ospedaliera
  - Data e ora
  - Stato (badge colorato)
  - Prezzo
- **Filtri**:
  - Tutte
  - In Attesa
  - Confermate
  - Completate
  - Annullate
  - Rifiutate
- **Azioni**:
  - Tap per vedere dettagli
  - Annulla prenotazione (se in attesa)

#### 3. **Profilo** (`/profile`)
- **Dati personali**:
  - Nome e Cognome
  - Email (non modificabile, usata per login)
  - Telefono
  - Data di nascita
  - Genere
  - Indirizzo completo
  - Codice fiscale
- **Azioni**:
  - Modifica informazioni
  - Logout

#### 4. **Supporto** (`/support`)
- **FAQ**: Domande frequenti categorizzate
- **Contatti**: Email, telefono, orari
- **Chat**: Link a supporto via chat (futuro)

### Flusso di Prenotazione

Il processo di prenotazione è guidato e suddiviso in 5 step:

#### Step 1: Selezione Categoria
- **Schermata**: `HomeScreen`
- **Azione**: Utente seleziona categoria esame (RM, TAC, ECO, RX)

#### Step 2: Selezione Esame Specifico
- **Schermata**: `ExamSelectionScreen`
- **Contenuto**: Lista esami filtrati per categoria selezionata
- **Informazioni**: Nome esame, distretto corporeo, descrizione
- **Ricerca**: Campo di ricerca per filtrare esami

#### Step 3: Selezione Località
- **Schermata**: `LocationSelectionScreen`
- **Selezione geografica**:
  - Regione (dropdown)
  - Provincia (dropdown dinamico basato su regione)
  - Città (dropdown dinamico basato su provincia)
- **Geolocalizzazione**: Opzione per usare posizione corrente
- **Dati**: Località italiane complete in `lib/data/italian_locations.dart`

#### Step 4: Selezione Struttura
- **Schermata**: `FacilityListScreen`
- **Lista strutture** che:
  - Offrono l'esame selezionato
  - Sono nella località scelta
- **Informazioni per struttura**:
  - Nome ospedale
  - Indirizzo completo
  - Distanza (se geolocalizzazione attiva)
  - Valutazione (stelle)
  - Prezzo esame
  - Slot disponibili più vicini
- **Ordinamento**:
  - Per distanza
  - Per prezzo
  - Per disponibilità
- **Filtri**:
  - Solo strutture con disponibilità immediata
  - Range di prezzo

#### Step 5: Conferma Prenotazione
- **Schermata**: `BookingConfirmationScreen`
- **Riepilogo**:
  - Esame selezionato
  - Struttura
  - Data e ora
  - Prezzo finale
- **Opzioni aggiuntive**:
  - **Livello di urgenza**:
    - Normale
    - Urgente
    - Molto Urgente
  - **Servizi extra**:
    - Necessità trasporto
    - Servizio a domicilio
  - **Note**: Campo libero per comunicazioni
- **Form dati paziente**:
  - Nome e cognome (precompilati dal profilo)
  - Codice fiscale
  - Telefono
  - Email
- **Azione**: Conferma e crea prenotazione

#### Step 6: Stato Prenotazione
- **Schermata**: `BookingStatusScreen`
- **Visualizzazione dettagliata**:
  - Numero prenotazione (ID univoco)
  - Stato attuale con badge colorato
  - Timeline degli stati
  - Dettagli esame
  - Dettagli struttura con mappa
  - Informazioni di contatto
- **Azioni disponibili**:
  - Scarica PDF riepilogo
  - Aggiungi a calendario
  - Condividi prenotazione
  - Annulla (se ancora in attesa)
  - Contatta struttura

---

## Dashboard Web (Amministrazione)

### Accesso Dashboard
- **URL**: `/dashboard/login` o `/dashboard/login1`
- **Rilevamento automatico**: Desktop web redirect automatico al login dashboard
- **Protezione**: Solo `super_admin` e `org_admin` possono accedere

### Layout Dashboard
- **Sidebar sinistra**: Navigazione principale
- **Header**: Informazioni utente e ruolo
- **Contenuto principale**: Area di lavoro dinamica
- **Design**: Responsive, ottimizzato per desktop

### Menu Navigazione per Super Admin

#### Dashboard & Analytics
- **Panoramica** (`/dashboard`)
  - Overview sistema
  - Statistiche principali
  - Grafici in tempo reale
  - Attività recenti

- **KPI & Report** (`/dashboard/kpi`)
  - Key Performance Indicators
  - Report esportabili
  - Analisi trends
  - Grafici personalizzabili

#### Gestione Risorse
- **Utenti** (`/dashboard/users`)
- **Ospedali** (`/dashboard/organizations`)
- **Registry Esami** (`/dashboard/exams`)
- **Tariffe Standard** (`/dashboard/tariffs`)

#### Prenotazioni
- **Tutte** (`/dashboard/bookings`)
- **In Attesa** (`/dashboard/bookings/pending`)
- **Confermate** (`/dashboard/bookings/confirmed`)
- **Crea Nuova** (`/dashboard/bookings/create`)

#### Sistema
- **Audit Log** (`/dashboard/audit`)
- **Impostazioni** (`/dashboard/settings`)

### Menu Navigazione per Org Admin

#### Dashboard
- **Panoramica**: Vista delle prenotazioni della propria struttura

#### Gestione
- **Prenotazioni**:
  - Tutte (solo della propria organizzazione)
  - In Attesa
  - Confermate
  - Crea Nuova
- **Offerte Esami** (`/dashboard/offerings`)
- **Tariffe** (`/dashboard/tariffs`)
- **Disponibilità** (`/dashboard/availability`)

#### Impostazioni
- **Profilo Ospedale** (`/dashboard/settings`)

---

## Gestione Prenotazioni

### Stati Prenotazione

#### 1. **Requested (In Attesa)**
- **Colore**: Arancione (`#FFA000`)
- **Descrizione**: Prenotazione appena creata, in attesa di conferma da parte della struttura
- **Azioni possibili**:
  - Conferma (org_admin/super_admin)
  - Rifiuta (org_admin/super_admin)
  - Annulla (utente)

#### 2. **Confirmed (Confermata)**
- **Colore**: Verde (`#4CAF50`)
- **Descrizione**: Prenotazione confermata dalla struttura
- **Informazioni aggiuntive**:
  - Data/ora conferma
  - Operatore che ha confermato
  - Note operatore
- **Azioni possibili**:
  - Completa (dopo l'esame)
  - Annulla (con motivazione)

#### 3. **Rejected (Rifiutata)**
- **Colore**: Rosso (`#F44336`)
- **Descrizione**: Prenotazione rifiutata dalla struttura
- **Informazioni aggiuntive**:
  - Motivo rifiuto
  - Operatore che ha rifiutato
- **Notifica**: Utente riceve notifica con motivo

#### 4. **Cancelled (Annullata)**
- **Colore**: Grigio (`#9E9E9E`)
- **Descrizione**: Prenotazione annullata dall'utente o dalla struttura
- **Informazioni aggiuntive**:
  - Chi ha annullato
  - Quando è stata annullata
  - Motivo (opzionale)

#### 5. **Completed (Completata)**
- **Colore**: Blu (`#2196F3`)
- **Descrizione**: Esame effettuato
- **Informazioni aggiuntive**:
  - Data completamento
  - Eventuali note post-esame
- **Azioni possibili**:
  - Scarica referto (se disponibile)
  - Lascia recensione

### Schermata Gestione Prenotazioni (Admin)

**Path**: `/dashboard/bookings`

#### Funzionalità Principali

##### 1. **Visualizzazione Lista**
- **Tabella completa** con colonne:
  - ID Prenotazione
  - Data/Ora esame
  - Paziente (nome, telefono, email)
  - Tipo esame
  - Struttura (solo per super_admin)
  - Stato (badge colorato)
  - Urgenza (badge)
  - Prezzo
  - Data creazione
  - Azioni

##### 2. **Filtri**
- **Per Stato**:
  - Tutte
  - In Attesa (requested)
  - Confermate (confirmed)
  - Completate (completed)
  - Annullate (cancelled)
  - Rifiutate (rejected)
- **Per Data**:
  - Oggi
  - Questa settimana
  - Questo mese
  - Range personalizzato
- **Per Struttura** (solo super_admin):
  - Tutte le strutture
  - Selezione singola struttura
- **Per Esame**:
  - Tutti i tipi
  - Categoria specifica
  - Esame specifico

##### 3. **Ricerca**
- **Campo di ricerca** per:
  - Nome paziente
  - Codice fiscale
  - Email
  - Telefono
  - ID prenotazione

##### 4. **Ordinamento**
- **Colonne ordinabili**:
  - Data esame (default: più recenti)
  - Data creazione
  - Paziente (alfabetico)
  - Prezzo
  - Stato

##### 5. **Azioni su Singola Prenotazione**

###### Per prenotazioni "In Attesa":
- **✅ Conferma**:
  - Dialog con selezione slot disponibile
  - Campo note operatore
  - Conferma con tracking (chi e quando)
  - Email notifica al paziente
  
- **❌ Rifiuta**:
  - Dialog con motivo rifiuto obbligatorio
  - Tracking operatore
  - Email notifica al paziente

###### Per prenotazioni "Confermate":
- **✓ Completa**:
  - Segna come completata
  - Campo note post-esame
  
- **🗑️ Annulla**:
  - Dialog conferma
  - Campo motivo annullamento
  - Liberazione slot

###### Azioni comuni:
- **👁️ Visualizza Dettagli**:
  - Modal/pagina con tutti i dettagli
  - Storico modifiche
  - Log audit trail
  
- **✏️ Modifica**:
  - Cambio data/ora (se slot disponibile)
  - Modifica note
  - Aggiornamento dati paziente

- **📄 Stampa PDF**:
  - Riepilogo prenotazione
  - QR code per check-in
  - Istruzioni pre-esame

##### 6. **Azioni Bulk** (Multiple Selection)
- **Selezione multipla** via checkbox
- **Conferma in blocco** (solo requested)
- **Esporta selezionate** (CSV/PDF)
- **Cambia stato** in blocco

##### 7. **Export Dati**
- **Formati supportati**:
  - CSV
  - Excel
  - PDF Report
- **Filtri applicati** all'export
- **Colonne personalizzabili**

### Menu Dedicati per Filtri Rapidi

#### `/dashboard/bookings/pending`
- **Lista pre-filtrata**: Solo prenotazioni in attesa
- **Focus**: Gestione rapida delle nuove richieste
- **Ordinamento**: Per data creazione (più recenti)
- **Notifica**: Badge con numero prenotazioni in attesa

#### `/dashboard/bookings/confirmed`
- **Lista pre-filtrata**: Solo prenotazioni confermate
- **Focus**: Prenotazioni da completare
- **Ordinamento**: Per data esame (prossime)
- **Vista calendario**: Opzione vista calendario settimanale/mensile

### Creazione Prenotazione da Admin

**Path**: `/dashboard/bookings/create`

#### Flusso Creazione Manuale
Utile per prenotazioni telefoniche o walk-in.

##### Step 1: Selezione Paziente
- **Ricerca paziente esistente** (email, codice fiscale, telefono)
- **O crea nuovo paziente**:
  - Nome, Cognome
  - Codice Fiscale
  - Email
  - Telefono
  - Data nascita
  - Indirizzo

##### Step 2: Selezione Esame
- **Categoria**: RM, TAC, ECO, RX
- **Esame specifico**: Dropdown esami disponibili
- **Descrizione**: Visualizzazione dettagli esame

##### Step 3: Selezione Struttura
- **Filtro**: Solo strutture che offrono l'esame
- **Visualizzazione**:
  - Nome struttura
  - Indirizzo
  - Prezzo per l'esame
  - Disponibilità slot

##### Step 4: Selezione Data/Ora
- **Calendario**: Vista mensile con slot disponibili
- **Orari**: Lista slot giornalieri
- **Urgenza**: Normale, Urgente, Molto Urgente

##### Step 5: Opzioni Aggiuntive
- **Servizi**:
  - Necessita trasporto
  - Servizio a domicilio
- **Note**: Campo testo libero
- **Prezzo**: Modifica prezzo (con motivazione)

##### Step 6: Conferma
- **Riepilogo completo**
- **Stato iniziale**: Selezione tra "In Attesa" o "Confermata"
- **Notifiche**: Opzione invio email/SMS al paziente
- **Salva e stampa**: Opzione stampa immediata PDF

---

## Gestione Esami

### Registry Esami (Super Admin)

**Path**: `/dashboard/exams`

#### Funzionalità

##### 1. **Visualizzazione Catalogo Esami**
- **Tabella completa** con:
  - Nome esame
  - Categoria (RM, TAC, ECO, RX)
  - Distretto corporeo
  - Descrizione
  - Numero strutture che lo offrono
  - Data creazione/aggiornamento
  - Azioni

##### 2. **Filtri**
- **Per Categoria**: RM, TAC, ECO, RX
- **Per Distretto**: Testa, Torace, Addome, Estremità
- **Ricerca**: Nome o descrizione esame

##### 3. **Crea Nuovo Esame**
- **Form**:
  - Nome esame (required)
  - Categoria (dropdown)
  - Distretto corporeo (dropdown)
  - Descrizione dettagliata (textarea)
- **Validazione**:
  - Nome univoco
  - Campi obbligatori
- **Salvataggio**: Crea in database + audit log

##### 4. **Modifica Esame**
- **Dialog/Modal** con form pre-compilato
- **Campi editabili**: tutti tranne ID
- **Tracking modifiche**: Audit log automatico

##### 5. **Elimina Esame**
- **Controllo dipendenze**:
  - Verifica se esame è usato in prenotazioni
  - Verifica se offerto da strutture
- **Protezione**: Non elimina se ci sono prenotazioni
- **Opzione**: Disattiva invece di eliminare

### Offerte Esami per Struttura (Org Admin)

**Path**: `/dashboard/offerings`

#### Funzionalità

##### 1. **Visualizzazione Offerte Attive**
- **Lista esami offerti** dalla struttura dell'admin loggato
- **Informazioni**:
  - Nome esame
  - Categoria
  - Prezzo personalizzato (se impostato)
  - Prezzo standard (di default)
  - Disponibilità attiva
  - Numero prenotazioni totali
  - Azioni

##### 2. **Aggiungi Nuova Offerta**
- **Selezione esame** da catalogo globale
- **Configurazione**:
  - Prezzo (usa tariff standard o personalizzato)
  - Attivo/Disattivo
  - Note interne
- **Validazione**: Esame non già offerto

##### 3. **Modifica Offerta**
- **Cambio prezzo**: Override tariff standard
- **Attiva/Disattiva**: Toggle senza eliminare
- **Note**: Campo per annotazioni interne

##### 4. **Rimuovi Offerta**
- **Controllo**: Verifica prenotazioni attive
- **Protezione**: Non rimuove se ci sono prenotazioni pending/confirmed
- **Soft delete**: Disattiva invece di eliminare

##### 5. **Gestione Tariffe Associate**
- **Visualizza tariff standard** per esame
- **Crea override personalizzato**: Prezzo specifico per la struttura
- **Storico prezzi**: Log modifiche prezzi nel tempo

### Pacchetti Esami (Esami Multipli)

**Path**: `/dashboard/exam-packages`

#### Funzionalità

##### 1. **Visualizzazione Pacchetti**
- **Lista pacchetti** predefiniti per l'organizzazione
- **Informazioni**:
  - Nome pacchetto (es. "RM Colonna Completa")
  - Descrizione
  - Numero esami inclusi
  - Durata totale (minuti)
  - Tipo calcolo tempo (Cumulativo o Slot singolo)
  - Prezzo pacchetto (opzionale)
  - Stato attivo/inattivo

##### 2. **Crea Nuovo Pacchetto**
- **Form**:
  - Nome pacchetto (required)
  - Descrizione (optional)
  - Selezione esami da includere (checkbox multipli raggruppati per categoria)
  - Durata totale in minuti
  - Tipo calcolo: 
    - **Cumulativo**: I tempi degli esami si sommano (es. RM Cervicale 30min + RM Dorsale 30min = 60min)
    - **Slot singolo**: Usano lo slot più lungo (es. TAC multi-distretto)
  - Prezzo pacchetto (opzionale, può essere scontato rispetto alla somma singoli)

##### 3. **Modifica/Elimina Pacchetto**
- Modifica tutti i campi
- Toggle attivo/inattivo senza eliminare
- Eliminazione con conferma

##### 4. **Import/Export JSON**
- **Esporta**: Genera JSON con tutti i pacchetti
- **Importa**: Carica pacchetti da file JSON (utile per replicare configurazioni)

### Compatibilità Esami

**Path**: `/dashboard/exam-compatibility`

#### Funzionalità

##### 1. **Tipi di Compatibilità**
- **Stesso Slot** (`same_slot`): Esami nello stesso slot temporale (es. TAC multi-distretto)
- **Sequenziale** (`sequential`): Esami consecutivi, stessa sala (tempi sommati)
- **Sale Diverse** (`different_room`): Esami in sale diverse con intervallo (es. mammografia + eco mammaria)

##### 2. **Crea Regola di Compatibilità**
- **Form**:
  - Esame 1 (dropdown)
  - Tipo compatibilità (radio buttons)
  - Esame 2 (dropdown)
  - Intervallo tra esami in minuti (solo per `different_room`)
  - Note (opzionale)

##### 3. **Visualizzazione Regole**
- Card con visualizzazione grafica esame1 ↔ esame2
- Icona e colore per tipo compatibilità
- Intervallo tempo mostrato per `different_room`
- Toggle attivo/inattivo

##### 4. **Import/Export JSON**
- **Esporta**: Genera JSON con tutte le regole
- **Importa**: Carica regole da file JSON

##### 5. **Calcolo Automatico Durata**
- Il servizio `ExamPackageService` calcola automaticamente:
  - Durata totale per lista di esami
  - Considera regole `same_slot` (usa durata maggiore)
  - Considera regole `sequential` (somma durate)
  - Considera regole `different_room` (aggiunge time_gap)

---

## Gestione Strutture/Organizzazioni

### Gestione Organizzazioni (Super Admin)

**Path**: `/dashboard/organizations`

#### Funzionalità

##### 1. **Lista Organizzazioni**
- **Tabella con**:
  - Nome organizzazione
  - Tipo (Ospedale Pubblico, Privato, Clinica, etc.)
  - Indirizzo completo
  - Telefono
  - Email
  - Numero esami offerti
  - Numero prenotazioni totali
  - Stato (Attiva/Sospesa)
  - Data registrazione
  - Azioni

##### 2. **Filtri**
- **Per Tipo**: Pubblico, Privato, Clinica
- **Per Regione**: Dropdown regioni italiane
- **Per Stato**: Attive, Sospese, Tutte
- **Ricerca**: Nome, città, email

##### 3. **Crea Nuova Organizzazione**
- **Form Dati Generali**:
  - Nome organizzazione
  - Tipo struttura
  - Partita IVA
  - Codice univoco
  
- **Indirizzo**:
  - Via
  - Numero civico
  - CAP
  - Città
  - Provincia
  - Regione
  - Coordinate GPS (opzionale)

- **Contatti**:
  - Telefono principale
  - Telefono secondario (opzionale)
  - Email principale
  - Email prenotazioni
  - Sito web (opzionale)

- **Impostazioni**:
  - Orario apertura/chiusura
  - Giorni chiusura settimanale
  - Festività
  - Tempo medio per slot

##### 4. **Modifica Organizzazione**
- **Tutti i campi editabili**
- **Upload logo**: Immagine struttura
- **Galleria foto**: Multiple immagini struttura
- **Certificazioni**: Upload documenti accreditamenti

##### 5. **Assegnazione Admin**
- **Assegna org_admin** a organizzazione
- **Form**:
  - Ricerca utente esistente (email)
  - O crea nuovo utente admin
- **Email invito**: Automatica con credenziali

##### 6. **Sospendi/Riattiva**
- **Sospendi organizzazione**:
  - Nasconde da ricerche utenti
  - Non accetta nuove prenotazioni
  - Mantiene prenotazioni esistenti
- **Riattiva**: Torna visibile

##### 7. **Statistiche Organizzazione**
- **Dashboard mini**:
  - Prenotazioni mese corrente
  - Revenue mese
  - Tasso conferma
  - Rating medio
  - Tempo medio risposta

### Profilo Ospedale (Org Admin)

**Path**: `/dashboard/settings`

#### Funzionalità

##### 1. **Informazioni Generali**
- **Visualizzazione e modifica**:
  - Nome struttura (non modificabile)
  - Descrizione breve
  - Descrizione completa
  - Servizi offerti (checkbox multipli)
  - Convenzioni (SSN, assicurazioni)

##### 2. **Dati Contatto**
- **Modifica**:
  - Telefono
  - Email
  - Sito web
  - Social media (Facebook, Instagram, etc.)

##### 3. **Indirizzo e Posizione**
- **Visualizzazione mappa**: Google Maps embed
- **Indicazioni stradali**: Link a Google Maps
- **Parcheggio**: Info disponibilità

##### 4. **Orari e Disponibilità**
- **Orari apertura**:
  - Per giorno della settimana
  - Orario continuato/spezzato
  - Festività e chiusure straordinarie
  
- **Gestione emergenze**:
  - Accesso h24
  - Pronto soccorso

##### 5. **Documenti e Certificazioni**
- **Upload**:
  - Accreditamenti
  - Certificazioni qualità
  - Assicurazioni
- **Visualizzazione**: Lista documenti con date scadenza

##### 6. **Immagini e Media**
- **Logo**: Upload logo struttura
- **Foto**: Galleria immagini (sale, macchinari, struttura)
- **Video**: Link video presentazione (YouTube)

##### 7. **Impostazioni Prenotazioni**
- **Configurazione**:
  - Anticipo minimo prenotazione (ore)
  - Anticipo massimo (giorni)
  - Tempo slot standard (minuti)
  - Max prenotazioni simultanee
  - Auto-conferma (si/no)
  - Richiedi prepagamento (si/no)

##### 8. **Notifiche**
- **Email notifications**:
  - Nuova prenotazione
  - Prenotazione annullata
  - Promemoria esami giorno dopo
- **Destinatari**: Email amministratori

---

## Sistema Tariffe

### Tariffe Standard (Super Admin)

**Path**: `/dashboard/tariffs`

#### Funzionalità

##### 1. **Visualizzazione Tariffe Standard**
- **Tabella**:
  - Esame
  - Categoria
  - Prezzo base (€)
  - Prezzo urgente (€)
  - Prezzo molto urgente (€)
  - Data ultimo aggiornamento
  - Azioni

##### 2. **Crea Tariffa Standard**
- **Form**:
  - Selezione esame (dropdown)
  - Prezzo base (required)
  - Prezzo urgente (opzionale, default: base * 1.5)
  - Prezzo molto urgente (opzionale, default: base * 2)
  - Note
- **Validazione**: Esame non deve avere già una tariffa standard

##### 3. **Modifica Tariffa**
- **Campi editabili**: Tutti i prezzi
- **Storico modifiche**: Log prezzi precedenti con date
- **Notifica**: Opzione notifica strutture che usano la tariffa

##### 4. **Elimina Tariffa**
- **Controllo**: Verifica se usata da strutture
- **Protezione**: Avviso prima di eliminare

### Tariffe Personalizzate (Org Admin)

**Path**: `/dashboard/tariffs`

#### Funzionalità

##### 1. **Visualizzazione Tariffe**
- **Due sezioni**:
  
  **A) Tariffe Standard Applicate**
  - Esami offerti che usano prezzo standard
  - Possibilità di override
  
  **B) Tariffe Personalizzate**
  - Esami con prezzo custom
  - Differenza vs standard
  - % sconto/maggiorazione

##### 2. **Crea Override Prezzo**
- **Selezione esame** tra quelli offerti
- **Prezzi personalizzati**:
  - Prezzo base custom
  - Prezzo urgente custom
  - Prezzo molto urgente custom
- **Validità**: Date inizio/fine (opzionale)
- **Note**: Motivazione cambio prezzo

##### 3. **Promozioni Temporanee**
- **Crea promozione**:
  - Esami inclusi (multipli)
  - Sconto % o fisso (€)
  - Date validità
  - Codice promo (opzionale)
  - Limite utilizzi
- **Gestione attive**: Lista promozioni attive/scadute

##### 4. **Storico Prezzi**
- **Timeline** modifiche prezzi
- **Grafici**: Andamento prezzo nel tempo
- **Export**: CSV storico per contabilità

---

## Gestione Disponibilità

**Path**: `/dashboard/availability`

### Funzionalità

#### 1. **Vista Calendario**
- **Visualizzazioni**:
  - Giorno (slot orari)
  - Settimana
  - Mese
- **Colori**:
  - Verde: Slot disponibili
  - Giallo: Slot parzialmente occupati
  - Rosso: Slot pieni
  - Grigio: Slot non attivi

#### 2. **Creazione Slot**

##### A) Slot Singolo
- **Data**: Selezione data
- **Ora inizio**: HH:MM
- **Ora fine**: HH:MM
- **Esami**: Quali esami accettano questo slot (multipli)
- **Capacità**: Numero max prenotazioni simultanee
- **Note**: Annotazioni interne

##### B) Slot Ricorrenti
- **Pattern ripetizione**:
  - Giornaliero
  - Settimanale (seleziona giorni)
  - Mensile (stesso giorno del mese)
- **Range date**: Data inizio - data fine
- **Orario**: Stesso orario per tutti
- **Esami**: Selezione multipla
- **Esclusioni**: Festività, chiusure

##### C) Template Settimanale
- **Crea template** tipo:
  - Lunedì-Venerdì: 08:00-18:00
  - Sabato: 08:00-13:00
  - Domenica: Chiuso
- **Applica template** a range date
- **Salva template** per riuso futuro

#### 3. **Modifica Slot**
- **Singolo**: Cambio orario, capacità
- **Serie**: Modifica tutti gli slot ricorrenti
- **Cancellazione**: Cancella singolo o serie

#### 4. **Gestione Eccezioni**
- **Chiusure straordinarie**:
  - Festività
  - Manutenzione
  - Ferie
- **Date**: Range o singole date
- **Effetto**: Disabilita tutti gli slot

#### 5. **Prenotazioni su Slot**
- **Visualizza occupazione**: Click su slot mostra prenotazioni
- **Dettagli**:
  - Chi ha prenotato
  - Che esame
  - Stato prenotazione
- **Azioni rapide**:
  - Conferma
  - Sposta ad altro slot
  - Annulla

#### 6. **Statistiche Disponibilità**
- **Tasso occupazione**: % slot occupati vs disponibili
- **Ore di punta**: Orari più richiesti
- **Giorni critici**: Giorni con più richieste
- **Suggerimenti**: AI suggerisce quando creare più slot

---

## Analytics e KPI

### Dashboard KPI (Super Admin)

**Path**: `/dashboard/kpi`

#### Metriche Visualizzate

##### 1. **Overview Generale**
- **Card principali** (periodo selezionabile):
  
  **Prenotazioni**
  - Totali
  - In attesa
  - Confermate
  - Completate
  - Tasso conversione

  **Revenue**
  - Fatturato totale
  - Fatturato medio per prenotazione
  - Trend vs mese precedente
  - Proiezione mensile

  **Strutture**
  - Totale organizzazioni attive
  - Nuove registrazioni periodo
  - Tasso attivazione

  **Utenti**
  - Totale end users
  - Nuove registrazioni
  - Utenti attivi (con almeno 1 prenotazione)
  - Tasso retention

##### 2. **Grafici Temporali**

**A) Prenotazioni nel Tempo**
- **Tipo**: Line chart
- **Asse X**: Tempo (giorno/settimana/mese)
- **Asse Y**: Numero prenotazioni
- **Serie multiple**:
  - Totali
  - Per stato
  - Per categoria esame

**B) Revenue nel Tempo**
- **Tipo**: Area chart
- **Breakdowns**:
  - Per categoria esame
  - Per struttura (top 10)
  - Per regione

**C) Tasso Conversione**
- **Tipo**: Funnel chart
- **Steps**:
  - Visite homepage
  - Selezione esame
  - Selezione struttura
  - Conferma prenotazione
  - Esame completato

##### 3. **Classifiche**

**Top Esami**
- Più prenotati
- Maggior revenue
- Tasso conversione più alto

**Top Strutture**
- Più prenotazioni
- Fatturato più alto
- Rating più alto
- Tempo risposta più veloce

**Top Regioni**
- Più prenotazioni
- Crescita maggiore

##### 4. **Analisi Geografica**
- **Mappa Italia**: Heatmap prenotazioni per regione
- **Dettaglio province**: Drill-down su regione
- **Copertura**: Aree scoperte da servizio

##### 5. **Analisi Utenti**

**Comportamento**
- Tempo medio completamento prenotazione
- Abbandoni per step (dove lasciano)
- Orari preferiti prenotazione
- Device utilizzati (mobile vs web)

**Demografia**
- Distribuzione età
- Distribuzione geografica
- Genere

##### 6. **Performance Strutture**

**Metriche**
- Tempo medio conferma prenotazione
- Tasso conferma vs rifiuto
- Tasso completamento
- Tasso cancellazione
- Rating medio

**Comparazione**
- Benchmark vs media nazionale
- Trend nel tempo

##### 7. **Export e Report**
- **Formati**: PDF, Excel, CSV
- **Report schedulati**: Email automatica settimanale/mensile
- **Report personalizzati**: Selezione metriche custom

### Dashboard Panoramica (Org Admin)

**Path**: `/dashboard`

#### Metriche (Solo Propria Organizzazione)

##### Card KPI
- Prenotazioni oggi
- Prenotazioni settimana
- In attesa conferma (con alert)
- Revenue mese
- Rating medio
- Tempo medio risposta

##### Grafici
- Prenotazioni ultime 4 settimane
- Revenue per categoria esame
- Distribuzione stati prenotazioni

##### Attività Recenti
- Ultime 10 prenotazioni
- Azioni richieste (pending)
- Prossimi esami (oggi/domani)

---

## Gestione Utenti

**Path**: `/dashboard/users`  
**Accesso**: Solo super_admin

### Funzionalità

#### 1. **Lista Utenti**
- **Tabella con**:
  - Nome completo
  - Email
  - Telefono
  - Ruolo (badge colorato)
  - Organizzazione (se org_admin)
  - Numero prenotazioni
  - Data registrazione
  - Ultimo accesso
  - Stato (Attivo/Sospeso)
  - Azioni

#### 2. **Filtri**
- **Per Ruolo**: Super Admin, Org Admin, End User
- **Per Stato**: Attivi, Sospesi, Tutti
- **Per Organizzazione** (org_admins)
- **Ricerca**: Nome, email, telefono

#### 3. **Crea Utente**
- **Form**:
  - Ruolo (dropdown)
  - Email (required, unique)
  - Password temporanea
  - Nome, Cognome
  - Telefono
  - Se org_admin: Selezione organizzazione
- **Email benvenuto**: Inviata automaticamente

#### 4. **Modifica Utente**
- **Campi editabili**:
  - Dati anagrafici
  - Ruolo (con conferma)
  - Organizzazione (org_admin)
  - Reset password
  
#### 5. **Cambio Ruolo**
- **Protezione**: Conferma richiesta
- **Validazione**:
  - Da end_user a org_admin: Richiede selezione organizzazione
  - Da org_admin a end_user: Verifica prenotazioni pending
- **Audit log**: Traccia cambio ruolo

#### 6. **Sospendi/Riattiva**
- **Sospendi**:
  - Blocca accesso
  - Non può creare nuove prenotazioni
  - Mantiene prenotazioni esistenti
- **Riattiva**: Ripristina accesso

#### 7. **Elimina Utente**
- **Controllo dipendenze**:
  - Prenotazioni attive
  - Organizzazione assegnata (org_admin)
- **Protezione**: Non elimina se ci sono prenotazioni pending/confirmed
- **Soft delete**: Disattiva invece di eliminare
- **GDPR**: Anonimizza dati se richiesto

#### 8. **Dettagli Utente**
- **View completa**:
  - Dati anagrafici completi
  - Storico prenotazioni
  - Storico accessi
  - Azioni amministrative su di lui (audit log)
  - Note admin

#### 9. **Azioni Bulk**
- **Selezione multipla**
- **Azioni**:
  - Export CSV
  - Invio email di massa
  - Sospendi/Riattiva in blocco

---

## Audit Log

**Path**: `/dashboard/audit`  
**Accesso**: Solo super_admin

### Funzionalità

#### 1. **Tracciamento Azioni**
Tutte le azioni amministrative sono loggate:

**Azioni Tracciate**:
- Login/Logout
- Creazione/Modifica/Eliminazione utenti
- Creazione/Modifica organizzazioni
- Conferma/Rifiuto/Annullamento prenotazioni
- Modifica esami e tariffe
- Cambio ruoli
- Modifica impostazioni sistema

**Informazioni Loggata**:
- Chi (utente)
- Cosa (azione)
- Quando (timestamp)
- Su cosa (entità target)
- Dettagli (JSON con before/after)
- IP address
- User agent

#### 2. **Visualizzazione Log**
- **Tabella cronologica**:
  - Data/Ora
  - Utente
  - Azione
  - Entità
  - Dettagli
  - IP

#### 3. **Filtri**
- **Per Utente**: Chi ha fatto azione
- **Per Tipo Azione**: Create, Update, Delete, Login, etc.
- **Per Entità**: Users, Bookings, Organizations, etc.
- **Per Data**: Range date
- **Per IP**: Specifico IP address

#### 4. **Ricerca**
- **Full-text search** in dettagli JSON
- **Ricerca avanzata** con operatori AND/OR

#### 5. **Export**
- **CSV**: Per analisi esterna
- **JSON**: Per backup o integrazione
- **Retention**: Log conservati per X mesi (configurabile)

---

## Supporto e Assistenza

### Schermata Supporto (End User)

**Path**: `/support`

#### Sezioni

##### 1. **FAQ (Domande Frequenti)**

**Categorie**:

**A) Prenotazioni**
- Come prenotare un esame?
- Posso modificare una prenotazione?
- Come annullare una prenotazione?
- Cosa significa "In Attesa"?
- Quanto tempo ci vuole per la conferma?
- Posso scegliere l'orario?

**B) Pagamenti**
- Come funziona il pagamento?
- Posso pagare alla struttura?
- Accettate carta di credito?
- Ho diritto a rimborsi?
- Prezzi con SSN/assicurazione?

**C) Esami**
- Quali esami posso prenotare?
- Serve impegnativa medica?
- Devo fare preparazione?
- Quanto dura l'esame?
- Quando ricevo i risultati?

**D) Account**
- Come creare account?
- Password dimenticata?
- Come modificare dati personali?
- Come eliminare account (GDPR)?

**E) Tecnico**
- App non funziona
- Non ricevo email
- Errori durante prenotazione
- Problemi con mappa/GPS

**Formato**:
- **Accordion**: Domanda (click per espandere risposta)
- **Ricerca**: Campo per filtrare FAQ
- **Feedback**: "È stata utile?" (Sì/No)

##### 2. **Contatti Supporto**

**Email**:
- supporto@prontorad.it
- Tempo risposta: 24-48h

**Telefono**:
- Numero verde: 800-XXX-XXX
- Orari: Lun-Ven 9:00-18:00

**Chat** (futuro):
- Chat live durante orari ufficio
- Chatbot AI per domande comuni

##### 3. **Documentazione**

**Guide**:
- Guida rapida prenotazione (PDF)
- Video tutorial (YouTube embed)
- Guida utilizzo app

**Termini e Privacy**:
- Termini e Condizioni
- Privacy Policy (GDPR compliant)
- Cookie Policy

##### 4. **Segnala Problema**

**Form**:
- Tipo problema (dropdown):
  - Bug tecnico
  - Prenotazione
  - Pagamento
  - Struttura
  - Altro
- Descrizione dettagliata (textarea)
- Screenshot (upload opzionale)
- Dati prenotazione (se applicabile)
- Email risposta
- Priorità

**Invio**: Email al team supporto + creazione ticket

##### 5. **Feedback App**

**Valutazione**:
- Stelle (1-5)
- Cosa ti piace
- Cosa migliorare
- Suggerimenti

**Recensioni**: Link a store (Play Store, App Store)

### Sistema Ticketing (Admin)

**Path**: `/dashboard/support` (futuro)

Gestione ticket supporto con:
- Assegnazione operatori
- Stati (Aperto, In lavorazione, Risolto, Chiuso)
- Priorità
- SLA tracking
- Knowledge base interna

---

## Funzionalità Tecniche Trasversali

### 1. **Logging e Debug**
- **Debug Console**: `LogsViewerScreen` (`/logs`)
- **Debug Print**: Tutti i servizi loggano azioni
- **Formato**: `[ServiceName] emoji message`
- **Emoji indicators**:
  - ✅ Successo
  - ❌ Errore
  - ⚠️ Warning
  - ℹ️ Info
  - 🚀 Start operazione
  - 🔍 Debug dettaglio

### 2. **Notifiche**
- **Email**: Inviate via Supabase Edge Functions
- **Push** (futuro): Firebase Cloud Messaging
- **In-app**: Badge, banner, toast

### 3. **PDF Generation**
- **Libreria**: `pdf` package
- **Report supportati**:
  - Riepilogo prenotazione
  - Conferma esame
  - Report KPI
  - Export dati

### 4. **Geolocalizzazione**
- **Permessi**: Android (AndroidManifest.xml), iOS (Info.plist)
- **Uso**: Calcolo distanza strutture, ordinamento per vicinanza
- **Fallback**: Se permessi negati, usa solo selezione manuale località

### 5. **Responsive Design**
- **Mobile**: Ottimizzato per touch, bottom navigation
- **Tablet**: Layout adattivo
- **Desktop Web**: Dashboard con sidebar, layout multi-colonna

### 6. **Temi**
- **Light mode**: Default
- **Dark mode**: Supportato
- **Personalizzazione**: Colori in `lib/theme.dart`

### 7. **Internazionalizzazione**
- **Lingua**: Italiano (UI)
- **Codice**: Inglese (variabili, commenti)
- **Preparato per i18n**: Struttura permette aggiunta altre lingue

### 8. **Sicurezza**
- **Autenticazione**: Supabase Auth con PKCE
- **RLS**: Row Level Security su tutte le tabelle
- **API**: Protette da auth token
- **CORS**: Configurato per domini autorizzati
- **Sanitizzazione**: Input utente sanitizzato
- **GDPR**: Compliance privacy, diritto cancellazione dati

### 9. **Performance**
- **Caching**: Profilo e organizzazione in cache
- **Optimized queries**: JOIN invece di N+1 queries
- **Lazy loading**: Immagini e dati caricati on-demand
- **Pagination**: Liste lunghe con infinite scroll

### 10. **Error Handling**
- **Try-catch**: Tutti i servizi wrappano chiamate DB
- **Fallback**: Valori di default se caricamento fallisce
- **User feedback**: Snackbar/Dialog per errori utente-facing
- **Logging**: Errori loggati per debug

---

## Roadmap Funzionalità Future

### A Breve Termine
- [ ] Chat supporto live
- [ ] Push notifications
- [ ] Pagamento online integrato (Stripe/PayPal)
- [ ] Recensioni e rating strutture
- [ ] Promemoria esame (email/SMS 24h prima)

### Medio Termine
- [ ] App strutture mobile (per org_admin)
- [ ] QR code check-in
- [ ] Referto online (upload da struttura)
- [ ] Telemedicina (consultazione online)
- [ ] Integrazione calendari (Google Calendar, iCal)

### Lungo Termine
- [ ] AI suggerimenti esami (basato su sintomi)
- [ ] Marketplace servizi aggiuntivi
- [ ] Abbonamenti premium
- [ ] Partnership assicurazioni
- [ ] Espansione internazionale

---

## Contatti e Supporto Sviluppo

**Package**: xraynow  
**Flutter Version**: Latest (May 2025+)  
**Backend**: Supabase  
**Repository**: `/hologram/data/workspace/project`

**Documentazione Tecnica**:
- `AGENTS.md`: Guidelines per AI agents
- `lib/nav.dart`: Routing e navigazione
- `lib/theme.dart`: Design system
- `supabase/migrations/`: Schema database

---

*Documento generato il: 2025*  
*Versione applicazione: 1.0.0*  
*Ultimo aggiornamento: Menu filtri prenotazioni (In Attesa, Confermate)*
