-- Bootstrap profile for the one Administrator account requested by MarketFlow.
--
-- Supabase Auth passwords must be created through Authentication Admin/API;
-- SQL migrations must not contain a plaintext password. First create/confirm
-- hani@gmail.com in Supabase Authentication with the requested password, then
-- run this migration to attach the application Administrator profile.

-- This file runs alphabetically before the general user-management migration.
-- Add the bootstrap columns here as well so the seed is order-independent.
alter table public.users add column if not exists phone text not null default '';
alter table public.users add column if not exists is_system_admin boolean not null default false;

insert into public.users
  (id, full_name, email, phone, role, department, status, is_system_admin)
select
  id,
  'Hani',
  email,
  '',
  'admin',
  'IT',
  'active',
  true
from auth.users
where lower(email) = 'hani@gmail.com'
on conflict (id) do update set
  full_name = excluded.full_name,
  email = excluded.email,
  role = 'admin',
  status = 'active',
  is_system_admin = true;
