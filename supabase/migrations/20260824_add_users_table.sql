-- ============================================================================
-- ADD USERS TABLE — 2026-08-24
-- ============================================================================
-- Links Supabase Auth users to application profiles (role, department, status).
-- The 8 seed users are inserted below. Replace the placeholder UUIDs with the
-- real auth.users UUIDs after creating the accounts in the Supabase dashboard.
-- ============================================================================


-- ── 1. CREATE TABLE ─────────────────────────────────────────────────────────
create table if not exists public.users (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text not null,
  email      text unique not null,
  role       text not null default 'viewer',
  department text not null default 'General',
  status     text not null default 'pending_assignment',
  created_at timestamptz not null default now()
);

-- Refresh any existing legacy profile constraints before inserting the
-- current seed data. This migration can run against an older users table.
alter table public.users drop constraint if exists users_role_check;
alter table public.users drop constraint if exists users_status_check;

update public.users
set role = 'viewer'
where role = 'analyst';

update public.users
set status = case status
  when 'inactive' then 'deactivated'
  when 'pending' then 'pending_assignment'
  else status
end
where status in ('inactive', 'pending');

alter table public.users add constraint users_role_check
  check (nullif(trim(role), '') is not null);
alter table public.users add constraint users_status_check
  check (status in ('active', 'deactivated', 'pending_assignment'));

comment on table  public.users is 'Application user profiles, linked to Supabase Auth.';
comment on column public.users.role is 'Application role key managed in public.app_roles.';


-- ── 2. RLS ──────────────────────────────────────────────────────────────────
-- Authenticated users can read all profiles (shared workspace).
-- Only admins can update roles/status. Users can update their own name.
alter table public.users enable row level security;

-- Drop old dev policies if present
drop policy if exists "dev: select users"  on public.users;
drop policy if exists "dev: insert users"  on public.users;
drop policy if exists "dev: update users"  on public.users;
drop policy if exists "dev: delete users"  on public.users;
drop policy if exists "users: select"       on public.users;
drop policy if exists "users: insert"       on public.users;
drop policy if exists "users: update own"   on public.users;
drop policy if exists "users: update admin" on public.users;
drop policy if exists "users: delete admin" on public.users;

-- READ: any authenticated user can see all profiles
create policy "users: select"
  on public.users for select
  to authenticated
  using (true);

-- INSERT: authenticated users can create profiles (admin invites)
create policy "users: insert"
  on public.users for insert
  to authenticated
  with check (true);

-- UPDATE: users can update their own profile; admins can update anyone
create policy "users: update own"
  on public.users for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "users: update admin"
  on public.users for update
  to authenticated
  using (auth.jwt() ->> 'role' = 'admin')
  with check (auth.jwt() ->> 'role' = 'admin');

-- DELETE: only admins
create policy "users: delete admin"
  on public.users for delete
  to authenticated
  using (auth.jwt() ->> 'role' = 'admin');


-- ── 3. HELPER FUNCTION ──────────────────────────────────────────────────────
-- Returns the current user's profile row (used after login).
create or replace function public.get_my_profile()
returns public.users
language sql
security definer
set search_path = public
as $$
  select * from public.users where id = auth.uid();
$$;


-- ── 4. SEED DATA ────────────────────────────────────────────────────────────
-- IMPORTANT: Replace the UUIDs below with the real auth.users UUIDs.
-- To find them after creating accounts:
--   select id, email from auth.users order by created_at;
--
-- For development, you can use these placeholder UUIDs and update later.

insert into public.users (id, full_name, email, role, department, status)
select v.id::uuid, v.full_name, v.email, v.role, v.department, v.status
from (values
  (
    '2f23a362-57b0-4f4a-a4c8-94bf8b9cdbb3',
    'Hana Tsegaye',
    'hana.tsegaye@marketflow.et',
    'marketing_manager',
    'Marketing',
    'active'
  ),
  (
    '68cdb0f0-e5af-4662-b353-c6adaf881814',
    'Biruk Alemu',
    'biruk.alemu@marketflow.et',
    'admin',
    'IT',
    'active'
  ),
  (
    '9ae1694b-638e-4854-9241-fddf07294f99',
    'Tigist Bekele',
    'tigist.bekele@marketflow.et',
    'viewer',
    'Analytics',
    'active'
  ),
  (
    '318aad56-0e07-4b64-a287-a74b10dfc8ea',
    'Dawit Haile',
    'dawit.haile@marketflow.et',
    'marketing_clerk',
    'Marketing',
    'deactivated'
  ),
  (
    'a5cf2c3a-e0c9-47e5-b9e6-83b23106e20d',
    'Selamawit Girma',
    'selamawit.girma@marketflow.et',
    'viewer',
    'Sales',
    'active'
  ),
  (
    'b67e142b-c0a0-4ad9-8e2c-0936b204ea9a',
    'Yohannes Tadesse',
    'yohannes.tadesse@marketflow.et',
    'marketing_manager',
    'Growth',
    'pending_assignment'
  ),
  (
    'dc21ecc0-77a7-4eff-9345-3b19c3c4ad05',
    'Marta Desta',
    'marta.desta@marketflow.et',
    'viewer',
    'Analytics',
    'pending_assignment'
  ),
  (
    '9bcb3150-8d31-4214-8ef9-9a1ef3dc2901',
    'Robel Tesfaye',
    'robel.tesfaye@marketflow.et',
    'marketing_clerk',
    'Creative',
    'active'
  )
) as v(id, full_name, email, role, department, status)
where exists (select 1 from auth.users au where au.id = v.id::uuid)
on conflict (id) do nothing;

