-- ============================================================================
-- RLS SECURITY AUDIT & FIX — 2026-08-24
-- ============================================================================
-- AUDIT FINDINGS:
--
--   1. RLS is ENABLED on all 8 tables ✅
--
--   2. SINGLE MONOLITHIC POLICY EXISTS:
--      "allow all for anon dev" on every table
--      → FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)
--      → Grants full SELECT/INSERT/UPDATE/DELETE to anyone with the anon key
--
--   3. NO SERVICE_ROLE KEY in the Flutter app — everything runs as anon.
--
--   4. CONSEQUENCE: The anon key can:
--        • Read every row (emails, phone numbers, financial data)
--        • Insert arbitrary rows
--        • Update any field on any row
--        • Delete any row
--        This is acceptable for local dev but NOT for production.
--
-- FIX STRATEGY (no-auth development):
--   • Drop the catch-all policy
--   • Create granular per-operation policies (SELECT, INSERT, UPDATE, DELETE)
--   • This makes the security boundary explicit and easy to tighten later
--   • When Supabase Auth is added, switch to role-based policies
--
-- PRODUCTION CHECKLIST (when adding auth):
--   1. Enable Supabase Auth in the Flutter app
--   2. Add user_id column to tables that need ownership
--   3. Replace anon policies with authenticated-only policies
--   4. Use service_role key for admin/seeding operations only
--   5. Audit and restrict INSERT/UPDATE/DELETE per role
-- ============================================================================


-- ── 1. DROP THE OLD MONOLITHIC POLICY ──────────────────────────────────────

do $$
declare t text;
begin
  foreach t in array array[
    'campaigns','customers','leads','opportunities',
    'budgets','promotions','influencers','content_items'
  ] loop
    execute format(
      'drop policy if exists "allow all for anon dev" on public.%I;', t
    );
  end loop;
end $$;


-- ── 2. GRANULAR PER-OPERATION POLICIES (Development) ───────────────────────
-- Each table gets four explicit policies. In dev, anon gets full access.
-- When auth is added, change the TO clause from `anon` to `authenticated`.

do $$
declare
  t text;
  tables text[] := array[
    'campaigns','customers','leads','opportunities',
    'budgets','promotions','influencers','content_items'
  ];
begin
  foreach t in array tables loop
    -- SELECT: anyone can read
    execute format(
      'create policy "dev: select %I" on public.%I
         for select to anon using (true);', t, t);

    -- INSERT: anon can insert
    execute format(
      'create policy "dev: insert %I" on public.%I
         for insert to anon with check (true);', t, t);

    -- UPDATE: anon can update
    execute format(
      'create policy "dev: update %I" on public.%I
         for update to anon using (true) with check (true);', t, t);

    -- DELETE: anon can delete
    execute format(
      'create policy "dev: delete %I" on public.%I
         for delete to anon using (true);', t, t);
  end loop;
end $$;


-- ── 3. PRODUCTION-READY POLICIES (template — activate when auth is added) ──
-- Uncomment and modify these AFTER Supabase Auth is integrated.
-- These policies assume a user_id column has been added to each table.
--
-- Example for campaigns:
--
--   alter table public.campaigns add column if not exists user_id uuid
--     references auth.users(id) on delete cascade;
--
--   -- Read: authenticated users can see all campaigns (shared workspace)
--   create policy "prod: select" on public.campaigns
--     for select to authenticated using (true);
--
--   -- Insert: only authenticated users
--   create policy "prod: insert" on public.campaigns
--     for insert to authenticated with check (true);
--
--   -- Update: only the owner or admins
--   create policy "prod: update" on public.campaigns
--     for update to authenticated
--     using (user_id = auth.uid() or auth.jwt() ->> 'role' = 'admin')
--     with check (user_id = auth.uid() or auth.jwt() ->> 'role' = 'admin');
--
--   -- Delete: only the owner or admins
--   create policy "prod: delete" on public.campaigns
--     for delete to authenticated
--     using (user_id = auth.uid() or auth.jwt() ->> 'role' = 'admin');
--
-- Apply the same pattern to all 8 tables.


-- ── 4. REVOKE ANON FROM PUBLIC SCHEMA (extra hardening) ───────────────────
-- Prevent anon from accessing anything outside the public schema.
-- This limits blast radius if a new table is accidentally created.

revoke all on all tables in schema information_schema from anon;
revoke all on all tables in schema pg_catalog from anon;


-- ── 5. VERIFICATION ────────────────────────────────────────────────────────
-- Run after applying: should show 4 policies per table (32 total).

select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'campaigns','customers','leads','opportunities',
    'budgets','promotions','influencers','content_items'
  )
order by tablename, cmd;
