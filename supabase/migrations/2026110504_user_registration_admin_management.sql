-- ============================================================================
-- USER REGISTRATION + ADMINISTRATOR MANAGEMENT
-- MarketFlow / MarketFlow
--
-- Apply after the existing RBAC migrations. This migration is additive and
-- keeps the existing public.users table and Supabase Auth identities.
-- ============================================================================

-- The legacy schema used inactive/pending and did not store phone numbers.
alter table public.users add column if not exists phone text not null default '';
alter table public.users add column if not exists is_system_admin boolean not null default false;

-- Convert legacy values before adding the stricter constraints.
update public.users set status = 'pending_assignment' where status = 'pending';
update public.users set status = 'deactivated' where status = 'inactive';
update public.users set role = 'viewer' where role = 'analyst';

alter table public.users drop constraint if exists users_status_check;
alter table public.users add constraint users_status_check check (
  status in ('pending_assignment', 'active', 'deactivated')
);

-- Roles are database-managed records. Keep role non-empty, but do not restrict
-- the profile table to a hard-coded list of role keys.
alter table public.users drop constraint if exists users_role_check;
alter table public.users drop constraint if exists users_role_key_check;
alter table public.users add constraint users_role_key_check
  check (nullif(trim(role), '') is not null);

-- Preserve one initial administrator as a recovery anchor. If the deployment
-- already has an administrator, the oldest active administrator is selected.
update public.users
set is_system_admin = true
where id = (
  select id from public.users
  where role = 'admin' and status = 'active'
  order by created_at asc
  limit 1
)
and not exists (select 1 from public.users where is_system_admin);

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
create index if not exists idx_user_role_history_user on public.user_role_history(user_id, created_at desc);
alter table public.user_role_history enable row level security;

-- ============================================================================
-- Secure helper functions
-- ============================================================================

create or replace function public.get_my_role()
returns text
language sql stable security definer set search_path = public
as $$ select coalesce((select role from public.users where id = auth.uid()), 'viewer'); $$;

create or replace function public.get_my_status()
returns text
language sql stable security definer set search_path = public
as $$ select coalesce((select status from public.users where id = auth.uid()), 'deactivated'); $$;

create or replace function public.is_active_user()
returns boolean
language sql stable security definer set search_path = public
as $$ select auth.uid() is not null and public.get_my_status() = 'active'; $$;

create or replace function public.is_admin_user()
returns boolean
language sql stable security definer set search_path = public
as $$ select public.get_my_role() = 'admin' and public.get_my_status() = 'active'; $$;

create or replace function public.is_approver()
returns boolean
language sql stable security definer set search_path = public
as $$ select public.is_active_user() and public.get_my_role() = 'marketing_manager'; $$;

create or replace function public.can_create_records()
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_active_user()
    and public.get_my_role() in ('marketing_clerk', 'content_creator');
$$;

create or replace function public.can_edit_records()
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.is_active_user()
    and public.get_my_role() in ('marketing_clerk', 'content_creator');
$$;

-- ============================================================================
-- Registration trigger: safe defaults, no role/status from client metadata.
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.users (id, full_name, email, phone, role, department, status)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), 'New User'),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    'viewer',
    coalesce(nullif(new.raw_user_meta_data ->> 'department', ''), 'General'),
    'pending_assignment'
  )
  on conflict (id) do nothing;

  -- Notify every active administrator without trusting the registering user.
  insert into public.notifications (user_id, title, message, category)
  select id, 'New registration pending',
         coalesce(new.raw_user_meta_data ->> 'full_name', new.email, 'A new user')
           || ' submitted a registration request for review.',
         'user_management'
  from public.users
  where role = 'admin' and status = 'active';

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

-- ============================================================================
-- Admin-only role/status mutation. The client can call this RPC, but cannot
-- submit arbitrary role or status values through a table update.
-- ============================================================================

create or replace function public.admin_update_user(
  p_user_id uuid,
  p_role text default null,
  p_status text default null,
  p_department text default null
)
returns public.users
language plpgsql security definer set search_path = public
as $$
declare
  actor public.users;
  before_row public.users;
  after_row public.users;
begin
  select * into actor from public.users where id = auth.uid();
  if actor.id is null or actor.role <> 'admin' or actor.status <> 'active' then
    raise exception 'Only an active Administrator can manage users';
  end if;

  if p_role is not null and not exists (
      select 1 from public.app_roles where role_key = p_role
  ) then
    raise exception 'Invalid role';
  end if;
  if p_status is not null and p_status not in
      ('pending_assignment', 'active', 'deactivated') then
    raise exception 'Invalid account status';
  end if;

  select * into before_row from public.users where id = p_user_id for update;
  if before_row.id is null then raise exception 'User profile not found'; end if;
  if before_row.is_system_admin and (coalesce(p_status, before_row.status) <> 'active'
      or coalesce(p_role, before_row.role) <> 'admin') then
    raise exception 'The protected initial Administrator requires recovery procedure';
  end if;
  if p_user_id = auth.uid() and
      (coalesce(p_status, before_row.status) <> before_row.status
       or coalesce(p_role, before_row.role) <> before_row.role) then
    raise exception 'Administrators cannot change their own role or status';
  end if;

  update public.users
  set role = coalesce(p_role, role),
      status = coalesce(p_status, status),
      department = coalesce(nullif(p_department, ''), department)
  where id = p_user_id
  returning * into after_row;

  if before_row.role <> after_row.role or before_row.status <> after_row.status then
    insert into public.user_role_history
      (user_id, changed_by, previous_role, new_role, previous_status, new_status)
    values
      (after_row.id, auth.uid(), before_row.role, after_row.role,
       before_row.status, after_row.status);

    insert into public.audit_logs
      (user_id, user_name, action, module, record_id, record_name, details)
    values
      (auth.uid(), actor.full_name, 'user_access_change', 'Users & Roles',
       after_row.id::text, after_row.full_name,
       jsonb_build_object('previous_role', before_row.role,
                          'new_role', after_row.role,
                          'previous_status', before_row.status,
                          'new_status', after_row.status));

    if after_row.status = 'active' then
      insert into public.notifications (user_id, title, message, category)
      values (after_row.id, 'Account activated',
              'Your MarketFlow account is active as ' || after_row.role || '.',
              'user_management');
    elsif after_row.status = 'deactivated' then
      insert into public.notifications (user_id, title, message, category)
      values (after_row.id, 'Account deactivated',
              'Your MarketFlow account has been deactivated. Contact an Administrator.',
              'user_management');
    end if;
  end if;

  return after_row;
end;
$$;
revoke all on function public.admin_update_user(uuid, text, text, text) from public;
grant execute on function public.admin_update_user(uuid, text, text, text) to authenticated;

-- ============================================================================
-- RLS: active users can read marketing data; Administrator only can manage
-- profiles. Administrators have read-only access to marketing records.
-- ============================================================================

select public._drop_app_policies('users');
create policy "user profiles: self or admin read" on public.users
  for select to authenticated
  using (public.is_active_user() and (id = auth.uid() or public.is_admin_user()));
create policy "user profiles: self details only" on public.users
  for update to authenticated
  using (public.is_active_user() and id = auth.uid())
  with check (public.is_active_user() and id = auth.uid()
    and role = public.get_my_role() and status = public.get_my_status());

select public._drop_app_policies('user_role_history');
create policy "user role history: admin read" on public.user_role_history
  for select to authenticated using (public.is_admin_user());

-- Rebuild policies on the existing marketing tables so pending/deactivated
-- sessions cannot read or write protected data and admin is read-only.
do $$
declare t text;
begin
  foreach t in array array[
    'campaigns','customers','leads','opportunities','budgets','budget_requests',
    'promotions','influencers','content_items','expenses','campaign_customers'
  ] loop
    perform public._drop_app_policies(t);
    execute format('create policy "user access: select %s" on public.%I for select to authenticated using (public.is_active_user())', t, t);
    execute format('create policy "user access: insert %s" on public.%I for insert to authenticated with check (public.can_create_records())', t, t);
    execute format('create policy "user access: update %s" on public.%I for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver())', t, t);
    execute format('create policy "user access: delete %s" on public.%I for delete to authenticated using (public.can_edit_records())', t, t);
  end loop;
end $$;

select public._drop_app_policies('audit_logs');
create policy "audit logs: admin read" on public.audit_logs
  for select to authenticated using (public.is_admin_user());
create policy "audit logs: active self write" on public.audit_logs
  for insert to authenticated with check (public.is_active_user() and user_id = auth.uid());

select public._drop_app_policies('notifications');
create policy "notifications: own or admin read" on public.notifications
  for select to authenticated using (public.is_active_user() and (user_id = auth.uid() or public.is_admin_user()));
create policy "notifications: own update" on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

comment on column public.users.status is
  'pending_assignment, active, or deactivated; separate from role';
comment on column public.users.role is
  'Exactly one of admin, marketing_manager, marketing_clerk (Marketing Staff), content_creator, viewer';
