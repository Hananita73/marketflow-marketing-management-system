import { config } from './config.js';
import { supabase } from './supabase.js';

const MISSING_TABLE_CODES = new Set(['PGRST205', '42P01']);

export async function verifyDatabase() {
  const startedAt = Date.now();

  const tables = await Promise.all(
    config.tables.map(async (table) => {
      const tableStartedAt = Date.now();
      const { count, error } = await supabase
        .from(table)
        .select('*', { count: 'exact' })
        .limit(1);

      const missing = Boolean(error && MISSING_TABLE_CODES.has(error.code));

      return {
        table,
        exists: !missing,
        accessible: !error,
        count: error ? null : count,
        latencyMs: Date.now() - tableStartedAt,
        error: error ? { code: error.code, message: error.message } : null,
      };
    }),
  );

  return {
    ok: tables.every((entry) => entry.exists),
    projectUrl: config.supabase.url,
    keyType: config.supabase.usingSecretKey ? 'secret' : 'publishable',
    checkedAt: new Date().toISOString(),
    latencyMs: Date.now() - startedAt,
    tables,
  };
}
