import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

interface PatientPayload {
  id?: string;
  first_name: string;
  last_name: string;
  email: string;
  phone_number?: string;
  organization_id?: string;
  role?: string;
  auth_user_id?: string; // NEW: link to auth.users.id
  force_update_org?: boolean; // Force update organization_id even if already set
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    // Use service role to bypass RLS
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const payload: PatientPayload = await req.json();
    
    const { id, first_name, last_name, email, phone_number, organization_id, role, auth_user_id, force_update_org } = payload;

    // Validate required fields
    if (!first_name || !last_name || !email) {
      return new Response(
        JSON.stringify({ error: 'first_name, last_name, and email are required' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    let user;

    // Check if user already exists by email
    const { data: existingByEmail } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .maybeSingle();

    if (existingByEmail) {
      // Update existing user
      // Use force_update_org to override existing organization_id
      const newOrgId = force_update_org && organization_id 
        ? organization_id 
        : (organization_id || existingByEmail.organization_id);
      
      console.log(`[ensure_patient] Updating user ${existingByEmail.id}, force_update_org=${force_update_org}, org_id: ${existingByEmail.organization_id} -> ${newOrgId}`);
      
      const { data: updated, error: updateError } = await supabase
        .from('users')
        .update({
          first_name,
          last_name,
          phone_number: phone_number || existingByEmail.phone_number,
          organization_id: newOrgId,
          role: role || existingByEmail.role,
          auth_user_id: auth_user_id || existingByEmail.auth_user_id,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existingByEmail.id)
        .select()
        .single();

      if (updateError) {
        console.error('Update error:', updateError);
        return new Response(
          JSON.stringify({ error: updateError.message }),
          { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }
      console.log(`[ensure_patient] User updated successfully, new org_id: ${updated.organization_id}`);
      user = updated;
    } else if (id) {
      // Check if user exists by ID
      const { data: existingById } = await supabase
        .from('users')
        .select('*')
        .eq('id', id)
        .maybeSingle();

      if (existingById) {
        // Update existing user by ID
        // Use force_update_org to override existing organization_id
        const newOrgId = force_update_org && organization_id 
          ? organization_id 
          : (organization_id || existingById.organization_id);
        
        console.log(`[ensure_patient] Updating user by ID ${id}, force_update_org=${force_update_org}, org_id: ${existingById.organization_id} -> ${newOrgId}`);
        
        const { data: updated, error: updateError } = await supabase
          .from('users')
          .update({
            first_name,
            last_name,
            email,
            phone_number: phone_number || existingById.phone_number,
            organization_id: newOrgId,
            role: role || existingById.role,
            auth_user_id: auth_user_id || existingById.auth_user_id,
            updated_at: new Date().toISOString(),
          })
          .eq('id', id)
          .select()
          .single();

        if (updateError) {
          console.error('Update by ID error:', updateError);
          return new Response(
            JSON.stringify({ error: updateError.message }),
            { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
          );
        }
        console.log(`[ensure_patient] User updated by ID successfully, new org_id: ${updated.organization_id}`);
        user = updated;
      } else {
        // Create new user with provided ID
        const { data: created, error: createError } = await supabase
          .from('users')
          .insert({
            id,
            first_name,
            last_name,
            email,
            phone_number,
            organization_id,
            role: role || 'end_user',
            auth_user_id,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .select()
          .single();

        if (createError) {
          console.error('Create with ID error:', createError);
          return new Response(
            JSON.stringify({ error: createError.message }),
            { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
          );
        }
        user = created;
      }
    } else {
      // Create new user without ID (let DB generate)
      const { data: created, error: createError } = await supabase
        .from('users')
        .insert({
          first_name,
          last_name,
          email,
          phone_number,
          organization_id,
          role: role || 'end_user',
          auth_user_id,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (createError) {
        console.error('Create error:', createError);
        return new Response(
          JSON.stringify({ error: createError.message }),
          { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }
      user = created;
    }

    return new Response(
      JSON.stringify({ user }),
      { status: 200, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }
});
