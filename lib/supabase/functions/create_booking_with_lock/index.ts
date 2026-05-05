// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import postgres from "https://deno.land/x/postgresjs@v3.4.4/mod.js";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

export const handler = async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers: { ...CORS_HEADERS, "content-type": "application/json" } });

  let body: any;
  try {
    body = await req.json();
  } catch (_e) {
    return new Response(JSON.stringify({ error: "invalid_json" }), { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  }

  const {
    user_id,
    facility_id: facility_id_in,
    exam_type_id,
    booking_date, // YYYY-MM-DD
    booking_time, // ISO string
    slot_id,
    urgency_level,
    price,
    notes,
  } = body || {};

  if (!user_id || !exam_type_id || !booking_date || !booking_time || !urgency_level || typeof price !== "number") {
    return new Response(JSON.stringify({ error: "missing_params" }), { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const dbUrl = Deno.env.get("SUPABASE_DB_URL")!;
  const supabase = createClient(supabaseUrl, supabaseKey, { auth: { persistSession: false } });
  const sql = postgres(dbUrl, { prepare: true, connection: { application_name: "create_booking_with_lock" } });

  const now = new Date().toISOString();
  const timeIso = new Date(booking_time).toISOString();

  try {
    // Resolve facility_id if missing
    let facility_id = facility_id_in as string | null | undefined;
    const timeIso = new Date(booking_time).toISOString();
    const orgRow = await sql`select organization_id from public.users where id = ${user_id} limit 1`;
    const organization_id: string | null = orgRow?.[0]?.organization_id ?? null;

    if (!facility_id) {
      // 1) Try offering for the exam within same organization
      if (organization_id) {
        const offering = await sql`
          select feo.facility_id
          from public.facility_exam_offerings feo
          join public.facilities f on f.id = feo.facility_id
          where feo.exam_type_id = ${exam_type_id}
            and feo.is_available = true
            and f.organization_id = ${organization_id}
          limit 1`;
        if (offering.length) facility_id = offering[0].facility_id as string;
      }
      // 2) Any facility of the organization
      if (!facility_id && organization_id) {
        const fac = await sql`select id from public.facilities where organization_id = ${organization_id} limit 1`;
        if (fac.length) facility_id = fac[0].id as string;
      }
      // 3) Create minimal facility as last resort
      if (!facility_id && organization_id) {
        const nowIso = new Date().toISOString();
        const created = await sql`
          insert into public.facilities (organization_id, name, created_at, updated_at)
          values (${organization_id}, 'Struttura Principale', ${nowIso}::timestamptz, ${nowIso}::timestamptz)
          returning id`;
        if (created.length) facility_id = created[0].id as string;
      }
    }
    if (!facility_id) {
      throw Object.assign(new Error("facility_unresolved"), { status: 422 });
    }
    const result = await sql.begin(async (trx) => {
      // Optional: verify offering availability
      const offering = await trx`
        select is_available from public.facility_exam_offerings
        where facility_id = ${facility_id} and exam_type_id = ${exam_type_id}
        limit 1
      `;
      if (offering.length && offering[0].is_available === false) {
        throw Object.assign(new Error("offering_unavailable"), { status: 409 });
      }

      if (slot_id) {
        const slots = await trx`
          select id, is_active, max_bookings from public.availability_slots
          where id = ${slot_id}
          for update
        `;
        if (!slots.length) throw Object.assign(new Error("slot_not_found"), { status: 404 });
        const slot = slots[0];
        if (!slot.is_active) throw Object.assign(new Error("slot_inactive"), { status: 409 });

        const counts = await trx`
          select count(*)::int as c from public.bookings
          where slot_id = ${slot_id} and booking_date::date = ${booking_date}::date and status != 'cancelled'
        `;
        const current = counts[0].c as number;
        if (current >= slot.max_bookings) throw Object.assign(new Error("slot_full"), { status: 409 });
      }

      // Insert booking
      const inserted = await trx`
        insert into public.bookings (
          user_id, exam_type_id, facility_id, booking_date, booking_time, status, urgency_level, price, needs_transport, is_home_service, notes, slot_id, created_at, updated_at
        ) values (
          ${user_id}, ${exam_type_id}, ${facility_id}, ${booking_date}::date, ${timeIso}::timestamptz, 'requested', ${urgency_level}, ${price}, false, false, ${notes ?? null}, ${slot_id ?? null}, ${now}::timestamptz, ${now}::timestamptz
        )
        returning *
      `;
      return inserted[0];
    });

    return new Response(JSON.stringify(result), { status: 200, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  } catch (e: any) {
    const status = e?.status ?? 500;
    const code = e?.message || "server_error";
    return new Response(JSON.stringify({ error: code }), { status, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  } finally {
    await sql.end({ timeout: 5 });
  }
};

// Default export for Supabase Edge Functions runtime
export default handler;
