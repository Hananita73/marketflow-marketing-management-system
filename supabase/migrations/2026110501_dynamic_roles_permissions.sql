-- ============================================================================
-- Dynamic roles and named action permissions
-- ============================================================================

create table if not exists public.app_roles (
  role_key text primary key,
  name text not null unique,
  is_system boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.app_permissions (
  permission_key text primary key,
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.role_permissions (
  role_key text not null references public.app_roles(role_key) on delete cascade,
  permission_key text not null references public.app_permissions(permission_key) on delete cascade,
  primary key (role_key, permission_key)
);

-- Roles are data, not a hard-coded five-value constraint.
alter table public.users drop constraint if exists users_role_check;
alter table public.users drop constraint if exists users_role_key_check;
alter table public.users add constraint users_role_key_check
  check (nullif(trim(role), '') is not null);

alter table public.app_roles enable row level security;
alter table public.app_permissions enable row level security;
alter table public.role_permissions enable row level security;

-- The initial Administrator role is the only role seeded by the application.
insert into public.app_roles (role_key, name, is_system)
values ('admin', 'Administrator', true)
on conflict (role_key) do update set name = excluded.name, is_system = true;

insert into public.app_permissions (permission_key, name)
select v.permission_key, v.permission_key
from (values
  ('dashboard.view'),
  ('campaign.view'), ('campaign.add'), ('campaign.edit'), ('campaign.delete'), ('campaign.submit'), ('campaign.approve'),
  ('customer.view'), ('customer.add'), ('customer.edit'), ('customer.delete'),
  ('lead.view'), ('lead.add'), ('lead.edit'), ('lead.delete'),
  ('opportunity.view'), ('opportunity.add'), ('opportunity.edit'), ('opportunity.delete'),
  ('influencer.view'), ('influencer.add'), ('influencer.edit'), ('influencer.delete'),
  ('content.view'), ('content.add'), ('content.edit'), ('content.delete'),
  ('promotion.view'), ('promotion.add'), ('promotion.edit'), ('promotion.delete'), ('promotion.approve'),
  ('budget.view'), ('budget.add'), ('budget.edit'), ('budget.delete'), ('budget.approve'),
  ('communication.view'), ('communication.add'), ('communication.edit'), ('communication.delete'),
  ('automation.view'), ('automation.add'), ('automation.edit'), ('automation.delete'),
  ('report.view'), ('report.generate'), ('notification.view'),
  ('user.view'), ('user.invite'), ('user.assign_role'), ('user.activate'), ('user.deactivate'),
  ('settings.view'), ('settings.manage'), ('audit.view')
) as v(permission_key)
on conflict (permission_key) do nothing;

insert into public.role_permissions (role_key, permission_key)
select 'admin', permission_key from public.app_permissions
on conflict do nothing;

-- Preserve existing profiles without creating hard-coded user accounts. Their
-- roles become editable records; Administrators can assign their permissions.
insert into public.app_roles (role_key, name, is_system)
select distinct
  u.role,
  initcap(replace(replace(u.role, '_', ' '), 'marketing clerk', 'marketing staff')),
  false
from public.users u
where nullif(trim(u.role), '') is not null
  and u.role <> 'admin'
on conflict (role_key) do nothing;

-- These helpers are repeated here so this migration remains safe when the
-- Supabase CLI applies files in filename order before the later user-management
-- migration.
create or replace function public.get_my_role()
returns text language sql stable security definer set search_path = public
as $$ select coalesce((select role from public.users where id = auth.uid()), 'viewer'); $$;

create or replace function public.get_my_status()
returns text language sql stable security definer set search_path = public
as $$ select coalesce((select status from public.users where id = auth.uid()), 'deactivated'); $$;

create or replace function public.is_active_user()
returns boolean language sql stable security definer set search_path = public
as $$ select auth.uid() is not null and public.get_my_status() = 'active'; $$;

create or replace function public.is_admin_user()
returns boolean language sql stable security definer set search_path = public
as $$ select public.get_my_role() = 'admin' and public.get_my_status() = 'active'; $$;

drop policy if exists "app roles: active read" on public.app_roles;
create policy "app roles: active read" on public.app_roles
  for select to authenticated
  using (public.is_active_user());

drop policy if exists "app permissions: active read" on public.app_permissions;
create policy "app permissions: active read" on public.app_permissions
  for select to authenticated
  using (public.is_active_user());

drop policy if exists "role permissions: active read" on public.role_permissions;
create policy "role permissions: active read" on public.role_permissions
  for select to authenticated
  using (public.is_active_user() and
    (role_key = public.get_my_role() or public.is_admin_user()));

create or replace function public.admin_create_role(
  p_name text,
  p_permissions text[] default '{}'
)
returns public.app_roles
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_key text;
  v_role public.app_roles;
  v_permission text;
begin
  if not public.is_admin_user() then raise exception 'Only an active Administrator can manage roles' using errcode = '42501'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'Role name is required' using errcode = '22023'; end if;
  v_key := trim(both '_' from regexp_replace(lower(trim(p_name)), '[^a-z0-9]+', '_', 'g'));
  if v_key in ('admin', '') then raise exception 'This role name is reserved' using errcode = '22023'; end if;
  if exists (select 1 from public.app_roles where role_key = v_key or lower(name) = lower(trim(p_name))) then
    raise exception 'A role with this name already exists' using errcode = '23505';
  end if;
  insert into public.app_roles(role_key, name, is_system, created_by)
  values (v_key, trim(p_name), false, auth.uid()) returning * into v_role;
  foreach v_permission in array coalesce(p_permissions, '{}') loop
    if not exists (select 1 from public.app_permissions where permission_key = v_permission) then
      raise exception 'Unknown permission: %', v_permission using errcode = '22023';
    end if;
    insert into public.role_permissions values (v_key, v_permission);
  end loop;
  return v_role;
end;
$$;

create or replace function public.admin_update_role(
  p_role_key text,
  p_name text,
  p_permissions text[] default '{}'
)
returns public.app_roles
language plpgsql security definer set search_path = public, pg_temp
as $$
declare
  v_role public.app_roles;
  v_permission text;
begin
  if not public.is_admin_user() then raise exception 'Only an active Administrator can manage roles' using errcode = '42501'; end if;
  select * into v_role from public.app_roles where role_key = p_role_key for update;
  if v_role.role_key is null then raise exception 'Role not found' using errcode = 'P0002'; end if;
  if v_role.is_system then raise exception 'The Administrator role cannot be edited' using errcode = '42501'; end if;
  update public.app_roles set name = trim(p_name) where role_key = p_role_key returning * into v_role;
  delete from public.role_permissions where role_key = p_role_key;
  foreach v_permission in array coalesce(p_permissions, '{}') loop
    if not exists (select 1 from public.app_permissions where permission_key = v_permission) then
      raise exception 'Unknown permission: %', v_permission using errcode = '22023';
    end if;
    insert into public.role_permissions values (p_role_key, v_permission);
  end loop;
  return v_role;
end;
$$;

create or replace function public.admin_delete_role(p_role_key text)
returns void
language plpgsql security definer set search_path = public, pg_temp
as $$
begin
  if not public.is_admin_user() then raise exception 'Only an active Administrator can manage roles' using errcode = '42501'; end if;
  if exists (select 1 from public.app_roles where role_key = p_role_key and is_system) then
    raise exception 'The Administrator role cannot be deleted' using errcode = '42501';
  end if;
  if exists (select 1 from public.users where role = p_role_key) then
    raise exception 'Reassign users before deleting this role' using errcode = '23503';
  end if;
  delete from public.app_roles where role_key = p_role_key;
end;
$$;

revoke all on function public.admin_create_role(text, text[]) from public;
revoke all on function public.admin_update_role(text, text, text[]) from public;
revoke all on function public.admin_delete_role(text) from public;
grant execute on function public.admin_create_role(text, text[]) to authenticated;
grant execute on function public.admin_update_role(text, text, text[]) to authenticated;
grant execute on function public.admin_delete_role(text) to authenticated;

notify pgrst, 'reload schema';
