// supabase/functions/seed_demo_users/index.ts
// Edge Function: Seed 3 demo users with roles and a sample organization
// - super_admin, org_admin (linked to organization), end_user
// - Idempotent: safe to run multiple times
// - Requires no auth (verify_jwt disabled in config); includes CORS

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CORS_HEADERS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-max-age': '86400',
};

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

// Service role client (bypasses RLS, needed for auth admin)
const adminClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});
// DB client
const db = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } });

interface DemoUserSpec {
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  phone_number: string;
  role: 'super_admin' | 'org_admin' | 'end_user';
  organization_name?: string | null;
}

async function ensureOrganization(name: string) {
  const { data: existing, error: selErr } = await db
    .from('organizations')
    .select('id, name')
    .eq('name', name)
    .maybeSingle();
  if (selErr && selErr.code !== 'PGRST116') throw selErr; // ignore no rows
  if (existing) return existing;
  const { data, error } = await db
    .from('organizations')
    .insert({ name, created_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .select('id, name')
    .single();
  if (error) throw error;
  return data;
}

async function getAuthUserByEmail(email: string) {
  // Try to create; if exists, fallback to listUsers with email filter
  const created = await adminClient.auth.admin.createUser({ email, password: crypto.randomUUID(), email_confirm: true });
  if (!created.error && created.data?.user) return created.data.user;
  // If already exists or other error, search by email
  const list = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (list.error) throw list.error;
  const found = list.data.users.find((u: any) => u.email?.toLowerCase() === email.toLowerCase());
  if (!found) throw new Error(`Auth user not found or cannot be created for email ${email}`);
  return found;
}

async function createOrLinkAuthUser(spec: DemoUserSpec) {
  // Ensure auth user exists with known password
  // 1) Check if a user already exists
  const list = await adminClient.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (list.error) throw list.error;
  let authUser = list.data.users.find((u: any) => u.email?.toLowerCase() === spec.email.toLowerCase());

  if (!authUser) {
    const created = await adminClient.auth.admin.createUser({
      email: spec.email,
      password: spec.password,
      email_confirm: true,
    });
    if (created.error) throw created.error;
    authUser = created.data.user;
  } else {
    // Ensure password is set (update if needed)
    await adminClient.auth.admin.updateUserById(authUser.id, { password: spec.password });
  }
  return authUser;
}

async function upsertAppUser(authUserId: string, spec: DemoUserSpec, orgId?: string | null) {
  const now = new Date().toISOString();
  // Check existing app user by email
  const { data: existing, error: selErr } = await db
    .from('users')
    .select('id, email, auth_user_id, role, organization_id')
    .eq('email', spec.email)
    .maybeSingle();
  if (selErr && selErr.code !== 'PGRST116') throw selErr;

  if (!existing) {
    const { data, error } = await db
      .from('users')
      .insert({
        first_name: spec.first_name,
        last_name: spec.last_name,
        email: spec.email,
        phone_number: spec.phone_number,
        created_at: now,
        updated_at: now,
        auth_user_id: authUserId,
        role: spec.role,
        organization_id: orgId ?? null,
      })
      .select('id, email, role')
      .single();
    if (error) throw error;
    return data;
  }

  // Update role/org/auth_user_id if missing or different
  const patch: Record<string, any> = { updated_at: now };
  if (!existing.auth_user_id) patch.auth_user_id = authUserId;
  if (existing.role !== spec.role) patch.role = spec.role;
  if ((existing.organization_id || null) !== (orgId || null)) patch.organization_id = orgId ?? null;

  if (Object.keys(patch).length > 1) {
    const { data, error } = await db
      .from('users')
      .update(patch)
      .eq('id', existing.id)
      .select('id, email, role')
      .single();
    if (error) throw error;
    return data;
  }
  return existing;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { ...CORS_HEADERS } });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Use POST' }), { status: 405, headers: { 'content-type': 'application/json', ...CORS_HEADERS } });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const orgName = body.organization_name || 'Istituto Demo ProntoRad';

    // Ensure org for org_admin
    const org = await ensureOrganization(orgName);

    const demoUsers: DemoUserSpec[] = [
      {
        email: 'admin@prontorad.demo',
        password: 'password123',
        first_name: 'Giulia',
        last_name: 'Bianchi',
        phone_number: '+39 02 1234 5678',
        role: 'super_admin',
      },
      {
        email: 'ospedale@prontorad.demo',
        password: 'password123',
        first_name: 'Luca',
        last_name: 'Rossi',
        phone_number: '+39 06 9876 5432',
        role: 'org_admin',
        organization_name: org.name,
      },
      {
        email: 'utente@prontorad.demo',
        password: 'password123',
        first_name: 'Sara',
        last_name: 'Verdi',
        phone_number: '+39 011 4455 667',
        role: 'end_user',
      },
    ];

    const results: any[] = [];

    for (const spec of demoUsers) {
      const authUser = await createOrLinkAuthUser(spec);
      const orgId = spec.role === 'org_admin' ? org.id : null;
      const profile = await upsertAppUser(authUser.id, spec, orgId);
      results.push({ email: spec.email, role: spec.role, profile_id: profile.id });
    }

    return new Response(
      JSON.stringify({ status: 'ok', created: results, organization: org }),
      { status: 200, headers: { 'content-type': 'application/json; charset=utf-8', ...CORS_HEADERS } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: (e as any)?.message ?? String(e) }),
      { status: 500, headers: { 'content-type': 'application/json; charset=utf-8', ...CORS_HEADERS } },
    );
  }
});
