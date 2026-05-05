// supabase/functions/ensure_patient/index.ts
// Securely ensure a patient exists in the `users` table (insert/update) using service role.
// This is used by the web admin flow when RLS prevents client-side inserts.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.44.4";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  }

  try {
    const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = Deno.env.toObject();
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: "Missing Supabase env" }), { status: 500, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
    }
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } });

    const body = await req.json().catch(() => ({}));
    const id = typeof body.id === "string" && body.id.trim().length > 0 ? body.id.trim() : undefined;
    const first_name = (body.first_name ?? "").toString();
    const last_name = (body.last_name ?? "").toString();
    const email = (body.email ?? "").toString();
    const phone_number = (body.phone_number ?? "").toString();
    const organization_id = typeof body.organization_id === "string" && body.organization_id.length > 0 ? body.organization_id : null;
    const role = (body.role ?? "end_user").toString();

    if (!email) {
      return new Response(JSON.stringify({ error: "email is required" }), { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
    }

    // Try by id first
    let existing: any = null;
    if (id) {
      const { data, error } = await supabase.from("users").select("*").eq("id", id).maybeSingle();
      if (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
      }
      existing = data;
    }

    if (!existing) {
      const { data, error } = await supabase.from("users").select("*").eq("email", email).maybeSingle();
      if (error && error.code !== "PGRST116") { // ignore Row not found
        return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
      }
      existing = data;
    }

    const now = new Date().toISOString();

    if (existing) {
      // Update existing
      const patch: Record<string, any> = {
        updated_at: now,
      };
      if (first_name) patch.first_name = first_name;
      if (last_name) patch.last_name = last_name;
      if (phone_number) patch.phone_number = phone_number;
      if (organization_id) patch.organization_id = organization_id;
      if (role) patch.role = role;

      const { data, error } = await supabase.from("users").update(patch).eq("id", existing.id).select().single();
      if (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
      }
      return new Response(JSON.stringify({ user: data }), { status: 200, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
    }

    // Insert new
    const row: Record<string, any> = {
      first_name,
      last_name,
      email,
      phone_number,
      role,
      created_at: now,
      updated_at: now,
    };
    if (id) row.id = id;
    if (organization_id) row.organization_id = organization_id;

    const { data, error } = await supabase.from("users").insert(row).select().single();
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
    }
    return new Response(JSON.stringify({ user: data }), { status: 200, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  }
});
