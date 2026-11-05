// ─────────────────────────────────────────────────────────────────────────────
// SupabaseConfig
//
// Central place for Supabase connection settings.
//
// HOW TO CONFIGURE:
//   1. Open your project at https://supabase.com/dashboard
//   2. Go to Project Settings → API
//   3. Copy the "Project URL" into SUPABASE_URL
//   4. Copy the anon/public "API Key" into SUPABASE_ANON_KEY
//
// SECURITY NOTE: the anon key is safe to embed in a client app ONLY when
// Row Level Security policies limit what it can access. See
// supabase_schema.sql at the repository root.
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://dhmcldrthntnahlfhbzf.supabase.co';
  static const String anonKey =
      'sb_publishable_z0BtmRbQHrOO7PekL4eyPg_ye6uoMtj';

  /// True when real credentials have been provided.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
