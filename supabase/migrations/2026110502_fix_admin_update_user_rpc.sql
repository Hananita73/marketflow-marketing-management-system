-- ============================================================================
-- FIX: public.admin_update_user RPC (PostgREST PGRST202)
--
-- Flutter calls this function with named parameters:
--   p_user_id, p_role, p_status, p_department
--
-- Run this migration after the users/RLS migrations. It is safe to re-run.
-- ============================================================================

alter table public.users
  add column if not exists phone text not null default '',
  add column if not exists is_system_admin boolean not null default false;

create table if not exists public.user_role_history (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  changed_by uuid not null references auth.users(id),
  previous_role text not null,
  new_role text not null,
  previous_status text not null,
  new_status text not null,
  created_at timestamptz not null default now()
);

-- Remove any old overload/signature so PostgREST sees one unambiguous RPC.
drop function if exists public.admin_update_user(uuid, text, text, text);
drop function if exists public.admin_update_user(text, text, text, uuid);

create function public.admin_update_user(
  p_user_id uuid,
  p_role text default null,
  p_status text default null,
  p_department text default null
)
returns public.users
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor public.users;
  v_before public.users;
  v_after public.users;
  v_new_role text;
  v_new_status text;
  v_new_department text;
begin
  select * into v_actor
  from public.users
  where id = auth.uid();

  if v_actor.id is null
     or v_actor.role <> 'admin'
     or v_actor.status <> 'active' then
    raise exception 'Only an active Administrator can manage users'
      using errcode = '42501';
  end if;

  select * into v_before
  from public.users
  where id = p_user_id
  for update;

  if v_before.id is null then
    raise exception 'User profile not found'
      using errcode = 'P0002';
  end if;

  v_new_role := coalesce(nullif(trim(p_role), ''), v_before.role);
  v_new_status := coalesce(nullif(trim(p_status), ''), v_before.status);
  v_new_department := coalesce(nullif(trim(p_department), ''), v_before.department);

  if not exists (
      select 1 from public.app_roles where role_key = v_new_role
  ) then
    raise exception 'Invalid role: %', v_new_role using errcode = '22023';
  end if;

  if v_new_status not in
      ('pending_assignment', 'active', 'deactivated') then
    raise exception 'Invalid account status: %', v_new_status using errcode = '22023';
  end if;

  if p_user_id = auth.uid()
     and (v_new_role <> v_before.role or v_new_status <> v_before.status) then
    raise exception 'Administrators cannot change their own role or status'
      using errcode = '42501';
  end if;

  if v_before.is_system_admin
     and (v_new_role <> 'admin' or v_new_status <> 'active') then
    raise exception 'The protected initial Administrator requires recovery procedure'
      using errcode = '42501';
  end if;

  -- Never allow the final active Administrator to lose administrator access.
  if v_before.role = 'admin'
     and v_before.status = 'active'
     and (v_new_role <> 'admin' or v_new_status <> 'active')
     and not exists (
       select 1
       from public.users u
       where u.role = 'admin'
         and u.status = 'active'
         and u.id <> v_before.id
     ) then
    raise exception 'The last active Administrator cannot be deactivated or reassigned'
      using errcode = '42501';
  end if;

  update public.users
  set role = v_new_role,
      status = v_new_status,
      department = v_new_department
  where id = p_user_id
  returning * into v_after;

  if v_before.role <> v_after.role
     or v_before.status <> v_after.status then
    insert into public.user_role_history
      (user_id, changed_by, previous_role, new_role,
       previous_status, new_status)
    values
      (v_after.id, auth.uid(), v_before.role, v_after.role,
       v_before.status, v_after.status);
  end if;

  if v_before.role <> v_after.role
     or v_before.status <> v_after.status
     or v_before.department <> v_after.department then
    insert into public.audit_logs
      (user_id, user_name, action, module, record_id, record_name, details)
    values
      (auth.uid(), v_actor.full_name, 'user_access_change', 'Users & Roles',
       v_after.id::text, v_after.full_name,
       jsonb_build_object(
         'affected_user_id', v_after.id,
         'previous_role', v_before.role,
         'new_role', v_after.role,
         'previous_status', v_before.status,
         'new_status', v_after.status,
         'previous_department', v_before.department,
         'new_department', v_after.department
       ));
  end if;

  if v_before.status <> v_after.status then
    insert into public.notifications (user_id, title, message, category)
    values (
      v_after.id,
      case when v_after.status = 'active'
           then 'Account activated'
           else 'Account deactivated' end,
      case when v_after.status = 'active'
           then 'Your MarketFlow account is active.'
           else 'Your MarketFlow account has been deactivated. Contact an Administrator.' end,
      'user_management'
    );
  end if;

  return v_after;
end;
$$;

revoke all on function public.admin_update_user(uuid, text, text, text) from public;
grant execute on function public.admin_update_user(uuid, text, text, text) to authenticated;

-- Ask PostgREST to reload the function definition immediately.
notify pgrst, 'reload schema';
