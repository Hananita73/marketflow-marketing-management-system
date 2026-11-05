import 'dotenv/config';

function requireEnv(name, fallback) {
  const value = String(process.env[name] || fallback || '').trim();
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const config = {
  port: Number(process.env.PORT || 8080),
  corsOrigin: process.env.CORS_ORIGIN || '*',
  supabase: {
    url: requireEnv('SUPABASE_URL'),
    key: requireEnv(
      'SUPABASE_SECRET_KEY',
      process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY,
    ),
    usingSecretKey: Boolean(process.env.SUPABASE_SECRET_KEY),
  },
  resend: {
    apiKey: process.env.RESEND_API_KEY || '',
    from: process.env.RESEND_FROM || 'MarkFlow <onboarding@resend.dev>',
  },
  admin: {
    email: process.env.ADMIN_EMAIL || '',
    apiToken: process.env.ADMIN_API_TOKEN || '',
  },
  // Scoped token used by the Flutter app to report events to /api/alerts.
  // Deliberately separate from admin.apiToken (which can send raw email).
  alerts: {
    token: process.env.ALERTS_API_TOKEN || '',
  },
  tables: [
    'campaigns',
    'customers',
    'leads',
    'opportunities',
    'budgets',
    'promotions',
    'influencers',
    'content_items',
    'users',
  ],
};
