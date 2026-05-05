export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  public: {
    Tables: {
      audit_logs: {
        Row: {
          action: string
          changes: Json | null
          created_at: string
          id: string
          record_id: string
          table_name: string
          user_id: string | null
        }
        Insert: {
          action: string
          changes?: Json | null
          created_at?: string
          id?: string
          record_id: string
          table_name: string
          user_id?: string | null
        }
        Update: {
          action?: string
          changes?: Json | null
          created_at?: string
          id?: string
          record_id?: string
          table_name?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users_internal"
            referencedColumns: ["id"]
          },
        ]
      }
      availability_slots: {
        Row: {
          booking_id: string | null
          created_at: string | null
          day_of_week: number | null
          end_time: string
          exam_category: string | null
          exam_type_id: string | null
          facility_id: string | null
          id: string
          is_active: boolean | null
          is_available: boolean | null
          max_bookings: number | null
          notes: string | null
          organization_id: string | null
          specific_date: string | null
          staff_user_id: string | null
          start_time: string
          updated_at: string | null
        }
        Insert: {
          booking_id?: string | null
          created_at?: string | null
          day_of_week?: number | null
          end_time: string
          exam_category?: string | null
          exam_type_id?: string | null
          facility_id?: string | null
          id?: string
          is_active?: boolean | null
          is_available?: boolean | null
          max_bookings?: number | null
          notes?: string | null
          organization_id?: string | null
          specific_date?: string | null
          staff_user_id?: string | null
          start_time: string
          updated_at?: string | null
        }
        Update: {
          booking_id?: string | null
          created_at?: string | null
          day_of_week?: number | null
          end_time?: string
          exam_category?: string | null
          exam_type_id?: string | null
          facility_id?: string | null
          id?: string
          is_active?: boolean | null
          is_available?: boolean | null
          max_bookings?: number | null
          notes?: string | null
          organization_id?: string | null
          specific_date?: string | null
          staff_user_id?: string | null
          start_time?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "availability_slots_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_slots_exam_type_id_fkey"
            columns: ["exam_type_id"]
            isOneToOne: false
            referencedRelation: "exam_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_slots_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_slots_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      bookings: {
        Row: {
          booking_date: string
          booking_time: string
          confirmed_at: string | null
          confirmed_by: string | null
          created_at: string
          exam_type_id: string | null
          facility_id: string | null
          gfr_value: number | null
          id: string
          is_home_service: boolean | null
          needs_transport: boolean | null
          notes: string | null
          operator_notes: string | null
          organization_id: string | null
          package_id: string | null
          parent_booking_id: string | null
          price: number
          rejected_reason: string | null
          slot_id: string | null
          status: string
          updated_at: string
          urgency_level: string
          user_id: string
        }
        Insert: {
          booking_date: string
          booking_time: string
          confirmed_at?: string | null
          confirmed_by?: string | null
          created_at?: string
          exam_type_id?: string | null
          facility_id?: string | null
          gfr_value?: number | null
          id?: string
          is_home_service?: boolean | null
          needs_transport?: boolean | null
          notes?: string | null
          operator_notes?: string | null
          organization_id?: string | null
          package_id?: string | null
          parent_booking_id?: string | null
          price: number
          rejected_reason?: string | null
          slot_id?: string | null
          status?: string
          updated_at?: string
          urgency_level?: string
          user_id: string
        }
        Update: {
          booking_date?: string
          booking_time?: string
          confirmed_at?: string | null
          confirmed_by?: string | null
          created_at?: string
          exam_type_id?: string | null
          facility_id?: string | null
          gfr_value?: number | null
          id?: string
          is_home_service?: boolean | null
          needs_transport?: boolean | null
          notes?: string | null
          operator_notes?: string | null
          organization_id?: string | null
          package_id?: string | null
          parent_booking_id?: string | null
          price?: number
          rejected_reason?: string | null
          slot_id?: string | null
          status?: string
          updated_at?: string
          urgency_level?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bookings_confirmed_by_fkey"
            columns: ["confirmed_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_confirmed_by_fkey"
            columns: ["confirmed_by"]
            isOneToOne: false
            referencedRelation: "users_internal"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_exam_type_id_fkey"
            columns: ["exam_type_id"]
            isOneToOne: false
            referencedRelation: "exam_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_package_id_fkey"
            columns: ["package_id"]
            isOneToOne: false
            referencedRelation: "exam_packages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_parent_booking_id_fkey"
            columns: ["parent_booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_slot_id_fkey"
            columns: ["slot_id"]
            isOneToOne: false
            referencedRelation: "availability_slots"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_slot_id_fkey"
            columns: ["slot_id"]
            isOneToOne: false
            referencedRelation: "availability_slots_with_org"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users_internal"
            referencedColumns: ["id"]
          },
        ]
      }
      exam_compatibility: {
        Row: {
          compatibility_type: string
          created_at: string
          exam_id_1: string
          exam_id_2: string
          id: string
          is_active: boolean
          notes: string | null
          organization_id: string | null
          time_gap_minutes: number
          updated_at: string
        }
        Insert: {
          compatibility_type?: string
          created_at?: string
          exam_id_1: string
          exam_id_2: string
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id?: string | null
          time_gap_minutes?: number
          updated_at?: string
        }
        Update: {
          compatibility_type?: string
          created_at?: string
          exam_id_1?: string
          exam_id_2?: string
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id?: string | null
          time_gap_minutes?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "exam_compatibility_exam_id_1_fkey"
            columns: ["exam_id_1"]
            isOneToOne: false
            referencedRelation: "exam_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "exam_compatibility_exam_id_2_fkey"
            columns: ["exam_id_2"]
            isOneToOne: false
            referencedRelation: "exam_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "exam_compatibility_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      exam_packages: {
        Row: {
          created_at: string
          description: string | null
          exam_ids: string[]
          id: string
          is_active: boolean
          is_cumulative: boolean
          name: string
          organization_id: string | null
          package_price: number | null
          total_duration_minutes: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          exam_ids?: string[]
          id?: string
          is_active?: boolean
          is_cumulative?: boolean
          name: string
          organization_id?: string | null
          package_price?: number | null
          total_duration_minutes?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          exam_ids?: string[]
          id?: string
          is_active?: boolean
          is_cumulative?: boolean
          name?: string
          organization_id?: string | null
          package_price?: number | null
          total_duration_minutes?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "exam_packages_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      exam_types: {
        Row: {
          body_district: string
          category: string
          created_at: string
          description: string
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          body_district: string
          category: string
          created_at?: string
          description: string
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          body_district?: string
          category?: string
          created_at?: string
          description?: string
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      facilities: {
        Row: {
          address: string
          available_exam_ids: string[]
          base_price: number
          city: string
          created_at: string
          id: string
          latitude: number
          longitude: number
          name: string
          organization_id: string | null
          province: string
          region: string
          type: string
          updated_at: string
        }
        Insert: {
          address: string
          available_exam_ids?: string[]
          base_price: number
          city: string
          created_at?: string
          id?: string
          latitude: number
          longitude: number
          name: string
          organization_id?: string | null
          province: string
          region: string
          type: string
          updated_at?: string
        }
        Update: {
          address?: string
          available_exam_ids?: string[]
          base_price?: number
          city?: string
          created_at?: string
          id?: string
          latitude?: number
          longitude?: number
          name?: string
          organization_id?: string | null
          province?: string
          region?: string
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "facilities_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      facility_exam_offerings: {
        Row: {
          created_at: string
          duration_minutes: number
          exam_type_id: string
          facility_id: string
          id: string
          is_available: boolean
          max_daily_bookings: number
          preparation_notes: string | null
          price: number
          ssn_price: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          duration_minutes?: number
          exam_type_id: string
          facility_id: string
          id?: string
          is_available?: boolean
          max_daily_bookings?: number
          preparation_notes?: string | null
          price?: number
          ssn_price?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          duration_minutes?: number
          exam_type_id?: string
          facility_id?: string
          id?: string
          is_available?: boolean
          max_daily_bookings?: number
          preparation_notes?: string | null
          price?: number
          ssn_price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "facility_exam_offerings_exam_type_id_fkey"
            columns: ["exam_type_id"]
            isOneToOne: false
            referencedRelation: "exam_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "facility_exam_offerings_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          booking_id: string | null
          created_at: string
          id: string
          is_read: boolean
          message: string
          title: string
          type: string
          user_id: string
        }
        Insert: {
          booking_id?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          message: string
          title: string
          type?: string
          user_id: string
        }
        Update: {
          booking_id?: string | null
          created_at?: string
          id?: string
          is_read?: boolean
          message?: string
          title?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users_internal"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          address: string | null
          city: string | null
          created_at: string
          email: string | null
          id: string
          latitude: number | null
          logo_url: string | null
          longitude: number | null
          name: string
          notes: string | null
          onboarding_completed: boolean
          org_type: string
          phone: string | null
          postal_code: string | null
          province: string | null
          region: string | null
          updated_at: string
          vat_number: string | null
          website: string | null
        }
        Insert: {
          address?: string | null
          city?: string | null
          created_at?: string
          email?: string | null
          id?: string
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          name: string
          notes?: string | null
          onboarding_completed?: boolean
          org_type: string
          phone?: string | null
          postal_code?: string | null
          province?: string | null
          region?: string | null
          updated_at?: string
          vat_number?: string | null
          website?: string | null
        }
        Update: {
          address?: string | null
          city?: string | null
          created_at?: string
          email?: string | null
          id?: string
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          name?: string
          notes?: string | null
          onboarding_completed?: boolean
          org_type?: string
          phone?: string | null
          postal_code?: string | null
          province?: string | null
          region?: string | null
          updated_at?: string
          vat_number?: string | null
          website?: string | null
        }
        Relationships: []
      }
      standard_tariffs: {
        Row: {
          created_at: string
          currency: string
          exam_type_id: string
          id: string
          price: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          currency?: string
          exam_type_id: string
          id?: string
          price?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          currency?: string
          exam_type_id?: string
          id?: string
          price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "standard_tariffs_exam_type_id_fkey"
            columns: ["exam_type_id"]
            isOneToOne: true
            referencedRelation: "exam_types"
            referencedColumns: ["id"]
          },
        ]
      }
      tariffs: {
        Row: {
          created_at: string
          currency: string
          exam_type_id: string
          id: string
          organization_id: string
          price: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          currency?: string
          exam_type_id: string
          id?: string
          organization_id: string
          price: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          currency?: string
          exam_type_id?: string
          id?: string
          organization_id?: string
          price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tariffs_exam_type_id_fkey"
            columns: ["exam_type_id"]
            isOneToOne: false
            referencedRelation: "exam_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tariffs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          auth_user_id: string | null
          created_at: string
          date_of_birth: string | null
          email: string
          first_name: string
          fiscal_code: string | null
          id: string
          last_name: string
          organization_id: string | null
          phone_number: string
          role: string
          updated_at: string
        }
        Insert: {
          auth_user_id?: string | null
          created_at?: string
          date_of_birth?: string | null
          email: string
          first_name: string
          fiscal_code?: string | null
          id?: string
          last_name: string
          organization_id?: string | null
          phone_number: string
          role?: string
          updated_at?: string
        }
        Update: {
          auth_user_id?: string | null
          created_at?: string
          date_of_birth?: string | null
          email?: string
          first_name?: string
          fiscal_code?: string | null
          id?: string
          last_name?: string
          organization_id?: string | null
          phone_number?: string
          role?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "users_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      availability_slots_with_org: {
        Row: {
          booking_id: string | null
          created_at: string | null
          day_of_week: number | null
          end_time: string | null
          exam_body_district: string | null
          exam_category: string | null
          exam_category_resolved: string | null
          exam_name: string | null
          exam_type_id: string | null
          facility_id: string | null
          id: string | null
          is_active: boolean | null
          is_available: boolean | null
          max_bookings: number | null
          notes: string | null
          organization_id: string | null
          organization_name: string | null
          organization_type: string | null
          specific_date: string | null
          staff_user_id: string | null
          start_time: string | null
          updated_at: string | null
        }
        Relationships: [
          {
            foreignKeyName: "availability_slots_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_slots_exam_type_id_fkey"
            columns: ["exam_type_id"]
            isOneToOne: false
            referencedRelation: "exam_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_slots_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "availability_slots_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      users_internal: {
        Row: {
          auth_user_id: string | null
          created_at: string | null
          date_of_birth: string | null
          email: string | null
          first_name: string | null
          fiscal_code: string | null
          id: string | null
          last_name: string | null
          organization_id: string | null
          phone_number: string | null
          role: string | null
          updated_at: string | null
        }
        Insert: {
          auth_user_id?: string | null
          created_at?: string | null
          date_of_birth?: string | null
          email?: string | null
          first_name?: string | null
          fiscal_code?: string | null
          id?: string | null
          last_name?: string | null
          organization_id?: string | null
          phone_number?: string | null
          role?: string | null
          updated_at?: string | null
        }
        Update: {
          auth_user_id?: string | null
          created_at?: string | null
          date_of_birth?: string | null
          email?: string | null
          first_name?: string | null
          fiscal_code?: string | null
          id?: string | null
          last_name?: string | null
          organization_id?: string | null
          phone_number?: string | null
          role?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "users_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      admin_create_user_profile: {
        Args: {
          p_auth_user_id: string
          p_email: string
          p_first_name: string
          p_fiscal_code?: string
          p_last_name: string
          p_organization_id?: string
          p_phone_number?: string
          p_role?: string
        }
        Returns: string
      }
      can_access_organization: {
        Args: { target_org_id: string }
        Returns: boolean
      }
      check_slot_overlap: {
        Args: {
          p_end_time: string
          p_exclude_slot_id?: string
          p_staff_user_id: string
          p_start_time: string
        }
        Returns: boolean
      }
      check_user_exists_by_email: {
        Args: { user_email: string }
        Returns: {
          auth_id: string
          exists_in_users: boolean
          user_id: string
          user_role: string
        }[]
      }
      create_booking_bypass_rls: {
        Args: {
          p_booking_date?: string
          p_booking_time?: string
          p_exam_type_id?: string
          p_notes?: string
          p_organization_id?: string
          p_price?: number
          p_slot_id?: string
          p_urgency_level?: string
          p_user_id: string
        }
        Returns: Json
      }
      create_facility_exam_offering: {
        Args: {
          p_exam_type_id: string
          p_facility_id: string
          p_price?: number
          p_ssn_price?: number
        }
        Returns: Json
      }
      current_user_organization_id: { Args: never; Returns: string }
      delete_facility_exam_offering: {
        Args: { p_offering_id: string }
        Returns: boolean
      }
      get_booking_with_user: { Args: { p_booking_id: string }; Returns: Json }
      get_current_user_role: {
        Args: never
        Returns: {
          org_id: string
          user_id: string
          user_role: string
        }[]
      }
      get_my_organization_id: { Args: never; Returns: string }
      get_my_role: { Args: never; Returns: string }
      get_organization_facility_id: {
        Args: { org_id: string }
        Returns: string
      }
      get_user_profile_by_auth_id: {
        Args: { p_auth_user_id: string }
        Returns: {
          auth_user_id: string
          created_at: string
          email: string
          first_name: string
          fiscal_code: string
          id: string
          last_name: string
          organization_id: string
          phone_number: string
          role: string
          updated_at: string
        }[]
      }
      is_admin_user: { Args: never; Returns: boolean }
      is_org_admin: { Args: never; Returns: boolean }
      is_super_admin: { Args: never; Returns: boolean }
      link_user_to_organization: {
        Args: { p_organization_id: string; p_user_id: string }
        Returns: undefined
      }
      user_has_booking_at_organization: {
        Args: { p_org_id: string; p_user_id: string }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
