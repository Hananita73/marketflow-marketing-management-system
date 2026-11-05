import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { Client } from 'pg';

const here = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(here, '..', '..');

const files = [
  'supabase_schema.sql',
  'supabase/migrations/20260824_add_users_table.sql',
  'supabase/migrations/20260824_production_rls.sql',
  'supabase/migrations/20260825_signup_trigger.sql',
  'supabase/migrations/20260826_seed_auth_users.sql',
];

const connectionString = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;

if (!connectionString) {
  console.error('Missing SUPABASE_DB_URL (or DATABASE_URL) in backend/.env');
  process.exit(1);
}

const client = new Client({
  connectionString,
  ssl: { rejectUnauthorized: false },
});

await client.connect();

try {
  for (const file of files) {
    const sql = await readFile(path.join(projectRoot, file), 'utf8');
    console.log(`Applying ${file} ...`);
    await client.query('begin');
    try {
      await client.query(sql);
      await client.query('commit');
      console.log(`Applied ${file}`);
    } catch (error) {
      await client.query('rollback');
      throw new Error(`${file} failed: ${error.message}`);
    }
  }

  const { rows } = await client.query(
    `select table_name
       from information_schema.tables
      where table_schema = 'public'
      order by table_name`,
  );
  console.log(`Public tables (${rows.length}): ${rows.map((row) => row.table_name).join(', ')}`);
} finally {
  await client.end();
}
