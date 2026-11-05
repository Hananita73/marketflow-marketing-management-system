-- ============================================================================
-- SEED AUTH USERS — 2026-08-26
-- ============================================================================
-- Creates Supabase Auth accounts for every sample user and assigns the
-- matching application role in public.users.
--
-- Password for every seed account: Marketflow2026!
-- Change these passwords after the first login.
-- ============================================================================

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  v.id::uuid,
  'authenticated',
  'authenticated',
  v.email,
  extensions.crypt('Marketflow2026!', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('full_name', v.full_name, 'department', v.department),
  now(),
  now(),
  '',
  '',
  '',
  ''
from (values
  ('2f23a362-57b0-4f4a-a4c8-94bf8b9cdbb3', 'hana.tsegaye@marketflow.et',    'Hana Tsegaye',    'Marketing'),
  ('68cdb0f0-e5af-4662-b353-c6adaf881814', 'biruk.alemu@marketflow.et',     'Biruk Alemu',     'IT'),
  ('9ae1694b-638e-4854-9241-fddf07294f99', 'tigist.bekele@marketflow.et',   'Tigist Bekele',   'Analytics'),
  ('318aad56-0e07-4b64-a287-a74b10dfc8ea', 'dawit.haile@marketflow.et',     'Dawit Haile',     'Marketing'),
  ('a5cf2c3a-e0c9-47e5-b9e6-83b23106e20d', 'selamawit.girma@marketflow.et', 'Selamawit Girma', 'Sales'),
  ('b67e142b-c0a0-4ad9-8e2c-0936b204ea9a', 'yohannes.tadesse@marketflow.et','Yohannes Tadesse','Growth'),
  ('dc21ecc0-77a7-4eff-9345-3b19c3c4ad05', 'marta.desta@marketflow.et',     'Marta Desta',     'Analytics'),
  ('9bcb3150-8d31-4214-8ef9-9a1ef3dc2901', 'robel.tesfaye@marketflow.et',   'Robel Tesfaye',   'Creative')
) as v(id, email, full_name, department)
where not exists (
  select 1 from auth.users existing where lower(existing.email) = lower(v.email)
);

insert into auth.identities (
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  u.id,
  u.id::text,
  jsonb_build_object(
    'sub', u.id::text,
    'email', u.email,
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  now(),
  now(),
  now()
from auth.users u
where lower(u.email) in (
  'hana.tsegaye@marketflow.et',
  'biruk.alemu@marketflow.et',
  'tigist.bekele@marketflow.et',
  'dawit.haile@marketflow.et',
  'selamawit.girma@marketflow.et',
  'yohannes.tadesse@marketflow.et',
  'marta.desta@marketflow.et',
  'robel.tesfaye@marketflow.et'
)
on conflict do nothing;

insert into public.users (id, full_name, email, role, department, status)
select
  u.id,
  v.full_name,
  v.email,
  v.role,
  v.department,
  v.status
from (values
  ('hana.tsegaye@marketflow.et',    'Hana Tsegaye',    'marketing_manager', 'Marketing', 'active'),
  ('biruk.alemu@marketflow.et',     'Biruk Alemu',     'admin',             'IT',        'active'),
  ('tigist.bekele@marketflow.et',   'Tigist Bekele',   'viewer',             'Analytics', 'active'),
  ('dawit.haile@marketflow.et',     'Dawit Haile',     'marketing_clerk',   'Marketing', 'active'),
  ('selamawit.girma@marketflow.et', 'Selamawit Girma', 'viewer',            'Sales',     'active'),
  ('yohannes.tadesse@marketflow.et','Yohannes Tadesse','marketing_manager', 'Growth',    'active'),
  ('marta.desta@marketflow.et',     'Marta Desta',     'viewer',             'Analytics', 'active'),
  ('robel.tesfaye@marketflow.et',   'Robel Tesfaye',   'marketing_clerk',   'Creative',  'active')
) as v(email, full_name, role, department, status)
join auth.users u on lower(u.email) = lower(v.email)
on conflict (id) do update set
  full_name = excluded.full_name,
  email = excluded.email,
  role = excluded.role,
  department = excluded.department,
  status = excluded.status;

select u.email, p.full_name, p.role, p.department, p.status
from auth.users u
join public.users p on p.id = u.id
where lower(u.email) in (
  'hana.tsegaye@marketflow.et',
  'biruk.alemu@marketflow.et',
  'tigist.bekele@marketflow.et',
  'dawit.haile@marketflow.et',
  'selamawit.girma@marketflow.et',
  'yohannes.tadesse@marketflow.et',
  'marta.desta@marketflow.et',
  'robel.tesfaye@marketflow.et'
)
order by u.email;

