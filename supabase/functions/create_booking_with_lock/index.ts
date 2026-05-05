import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

interface BookingPayload {
  user_id: string;
  organization_id?: string | null; // Organization ID (Struttura = Organizzazione)
  exam_type_id: string;
  booking_date: string;
  booking_time: string;
  slot_id?: string;
  urgency_level: string;
  price: number;
  notes?: string;
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

    const payload: BookingPayload = await req.json();
    console.log('Received booking payload:', JSON.stringify(payload));
    
    const { 
      user_id, 
      organization_id, 
      exam_type_id, 
      booking_date, 
      booking_time, 
      slot_id, 
      urgency_level, 
      price, 
      notes 
    } = payload;

    // Validate required fields
    if (!user_id || !exam_type_id || !booking_date || !booking_time) {
      return new Response(
        JSON.stringify({ error: 'user_id, exam_type_id, booking_date, and booking_time are required' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // If slot_id is provided, check if slot is still available
    if (slot_id) {
      const { data: slot, error: slotError } = await supabase
        .from('availability_slots')
        .select('*')
        .eq('id', slot_id)
        .maybeSingle();

      if (slotError) {
        console.error('Slot lookup error:', slotError);
        return new Response(
          JSON.stringify({ error: `Slot lookup failed: ${slotError.message}` }),
          { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      if (!slot) {
        return new Response(
          JSON.stringify({ error: 'Slot not found' }),
          { status: 404, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }

      if (!slot.is_available || !slot.is_active) {
        return new Response(
          JSON.stringify({ error: 'Slot is no longer available' }),
          { status: 409, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
        );
      }
    }

    const now = new Date().toISOString();

    // Build booking data - use organization_id (Struttura = Organizzazione)
    const bookingData: Record<string, unknown> = {
      user_id,
      exam_type_id,
      booking_date,
      booking_time,
      slot_id,
      urgency_level: urgency_level || 'normal',
      price: price || 0,
      notes,
      status: 'requested',
      needs_transport: false,
      is_home_service: false,
      created_at: now,
      updated_at: now,
    };
    
    // Only include organization_id if provided and not empty
    if (organization_id && organization_id.trim() !== '') {
      bookingData.organization_id = organization_id;
    }

    // Create the booking
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .insert(bookingData)
      .select()
      .single();

    if (bookingError) {
      console.error('Booking creation error:', bookingError);
      return new Response(
        JSON.stringify({ error: `Booking creation failed: ${bookingError.message}` }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    console.log('Booking created successfully:', booking.id);

    // Mark the slot as unavailable if slot_id was provided
    if (slot_id) {
      const { error: updateSlotError } = await supabase
        .from('availability_slots')
        .update({ 
          is_available: false, 
          is_active: false,
          updated_at: now 
        })
        .eq('id', slot_id);

      if (updateSlotError) {
        console.error('Slot update warning (booking still created):', updateSlotError);
        // Don't fail the booking if slot update fails
      } else {
        console.log('Slot marked as unavailable:', slot_id);
      }
    }

    return new Response(
      JSON.stringify(booking),
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
