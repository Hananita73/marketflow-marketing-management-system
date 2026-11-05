-- ============================================================================
-- PRODUCTION RLS — 2026-08-24
-- ============================================================================
-- Fixes security holes in the dev RLS policies:
--
--   1. users table: removes the permissive INSERT policy that let any
--      authenticated user create application profiles.
--   2. users table: replaces auth.jwt() ->> 'role' (which doesn't work
--      because 'role' is NOT in the JWT claims) with a security-definer
--      function that reads the role from public.users.
--   3. Data tables: upgrades from 'anon' to 'authenticated' so only
--      logged-in users can access application data.
--   4. Adds a get_my_role() helper for use in RLS policies.
-- ============================================================================


-- ── 0. HELPER: get_my_role() ──────────────────────────────────────────────
-- Security-definer function that returns the current user's role from
-- public.users. This is needed because auth.jwt() ->> 'role' does NOT
-- reflect the application role stored in public.users.
--
-- SECURITY: This function runs with the privileges of the function owner
-- (typically postgres), bypassing RLS. It only reads the role for the
-- current auth.uid(), so it cannot be abused to read other users' roles.

create or replace function public.get_my_role()
returns text
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select role from public.users where id = auth.uid()),
    'viewer'
  );
$$;

comment on function public.get_my_role() is
  'Returns the application role for the current authenticated user. '
  'Used in RLS policies as a replacement for auth.jwt() ->> ''role'' '
  'which does not reflect the public.users.role column.';


-- ── 1. DROP EXISTING USERS TABLE POLICIES ─────────────────────────────────

do $$ begin
  drop policy if exists "users: select"         on public.users;
  drop policy if exists "users: insert"         on public.users;
  drop policy if exists "users: update own"     on public.users;
  drop policy if exists "users: update admin"   on public.users;
  drop policy if exists "users: delete admin"   on public.users;
exception when others then null;
end $$;


-- ── 2. RECREATE USERS TABLE POLICIES (Production) ─────────────────────────

-- SELECT: any authenticated user can read all profiles (shared workspace).
create policy "users: select"
  on public.users for select
  to authenticated
  using (true);

-- INSERT: REMOVED — profiles are created via the database trigger on
-- auth.users signup, or by an admin using service_role. Regular
-- authenticated users must NOT be able to insert arbitrary profiles.
--
-- If you need admin-only inserts, use service_role key on the server side.
-- The Flutter app uses the anon key and should never insert into public.users
-- directly.

-- UPDATE: users can update their own profile (limited fields via app logic).
-- Admins can update anyone.
create policy "users: update own"
  on public.users for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "users: update admin"
  on public.users for update
  to authenticated
  using (public.get_my_role() = 'admin')
  with check (public.get_my_role() = 'admin');

-- DELETE: only admins.
create policy "users: delete admin"
  on public.users for delete
  to authenticated
  using (public.get_my_role() = 'admin');


-- ── 3. UPGRADE DATA TABLE POLICIES ────────────────────────────────────────
-- Drop the old 'anon' dev policies and replace with 'authenticated' policies.
-- This ensures only logged-in users can access application data.

do $$
declare
  t text;
  each_policy record;
  tables text[] := array[
    'campaigns','customers','leads','opportunities',
    'budgets','promotions','influencers','content_items'
  ];
begin
  foreach t in array tables loop
    -- Remove every existing policy, including policies created by an earlier
    -- partial/manual deployment. The policy names are not consistent across
    -- the historical migrations, so removing only the old dev names is not
    -- sufficient for an idempotent production migration.
    for each_policy in (
      select policyname
      from pg_policies
      where schemaname = 'public' and tablename = t
    ) loop
      execute format(
        'drop policy if exists %I on public.%I;',
        each_policy.policyname, t
      );
    end loop;

    -- SELECT: authenticated users can read all rows (shared workspace).
    execute format(
      'create policy "app: select %I" on public.%I
         for select to authenticated using (true);', t, t);

    -- INSERT: authenticated users can create rows.
    execute format(
      'create policy "app: insert %I" on public.%I
         for insert to authenticated with check (true);', t, t);

    -- UPDATE: authenticated users can update rows.
    execute format(
      'create policy "app: update %I" on public.%I
         for update to authenticated using (true) with check (true);', t, t);

    -- DELETE: only admins can delete rows.
    execute format(
      'create policy "app: delete %I" on public.%I
         for delete to authenticated
         using (public.get_my_role() = ''admin'');', t, t);
  end loop;
end $$;


-- ── 4. REMOVE ANON ACCESS TO PUBLIC SCHEMA ────────────────────────────────
-- Prevent anon from accessing any application data.

do $$ begin
  revoke select, insert, update, delete
    on all tables in schema public
    from anon;
exception when others then null;
end $$;


-- ── 5. REVOKE INFORMATION_SCHEMA FROM ANON ────────────────────────────────
-- Extra hardening: prevent anon from reading schema metadata.

revoke all on all tables in schema information_schema from anon;
revoke all on all tables in schema pg_catalog from anon;


-- ── 6. VERIFY ─────────────────────────────────────────────────────────────
-- Run after applying to confirm:
--   - users table: 4 policies (select, update own, update admin, delete admin)
--   - data tables: 4 policies each (select, insert, update, delete)
--   - No anon policies remain
--
-- select
--   schemaname, tablename, policyname, roles, cmd
-- from pg_policies
-- where schemaname = 'public'
-- order by tablename, cmd;
