-- ============================================================================
-- Opportunity progress history, customer ownership, followers, and row scope
-- ============================================================================

-- Customer records now carry the company used by the opportunity selector.
alter table public.customers
  add column if not exists company text not null default '';

alter table public.opportunities
  add column if not exists created_by uuid references auth.users(id) on delete set null,
  add column if not exists last_progress text not null default '',
  add column if not exists last_progress_at timestamptz,
  add column if not exists last_progress_by text not null default '';

create table if not exists public.opportunity_progress (
  id bigserial primary key,
  opportunity_id integer not null references public.opportunities(id) on delete cascade,
  note text not null,
  stage text not null,
  value numeric(14,2) not null default 0 check (value >= 0),
  probability integer not null default 0 check (probability between 0 and 100),
  changed_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  changed_by_name text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists idx_opportunity_progress_opportunity
  on public.opportunity_progress(opportunity_id, created_at desc);

create table if not exists public.opportunity_followers (
  opportunity_id integer not null references public.opportunities(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  user_name text not null default '',
  added_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (opportunity_id, user_id)
);
create index if not exists idx_opportunity_followers_user
  on public.opportunity_followers(user_id, opportunity_id);

create or replace function public.fill_opportunity_follower_name()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if nullif(trim(new.user_name), '') is null then
    select full_name into new.user_name from public.users where id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists opportunity_follower_name_trigger on public.opportunity_followers;
create trigger opportunity_follower_name_trigger
before insert or update on public.opportunity_followers
for each row execute function public.fill_opportunity_follower_name();

-- This is the single permission that allows a role to see every opportunity.
insert into public.app_permissions(permission_key, name)
values ('opportunity.view_all', 'opportunity.view_all')
on conflict (permission_key) do nothing;
insert into public.role_permissions(role_key, permission_key)
values ('admin', 'opportunity.view_all')
on conflict do nothing;

create or replace function public.can_access_opportunity(p_opportunity_id integer)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_permission('opportunity.view_all')
      or exists (
        select 1 from public.opportunities o
        where o.id = p_opportunity_id and o.created_by = auth.uid()
      )
      or exists (
        select 1 from public.opportunity_followers f
        where f.opportunity_id = p_opportunity_id and f.user_id = auth.uid()
      );
$$;

revoke all on function public.can_access_opportunity(integer) from public;
grant execute on function public.can_access_opportunity(integer) to authenticated;

-- Replace the broad historical opportunity policies with scoped policies.
select public._drop_app_policies('opportunities');
create policy "opportunity: scoped select" on public.opportunities
  for select to authenticated
  using (public.has_permission('opportunity.view') and public.can_access_opportunity(id));
create policy "opportunity: scoped insert" on public.opportunities
  for insert to authenticated
  with check (
    public.has_permission('opportunity.add')
    and (created_by = auth.uid() or public.has_permission('opportunity.view_all'))
  );
create policy "opportunity: scoped update" on public.opportunities
  for update to authenticated
  using (public.has_permission('opportunity.edit') and public.can_access_opportunity(id))
  with check (public.has_permission('opportunity.edit') and public.can_access_opportunity(id));
create policy "opportunity: scoped delete" on public.opportunities
  for delete to authenticated
  using (public.has_permission('opportunity.delete') and public.can_access_opportunity(id));

alter table public.opportunity_progress enable row level security;
select public._drop_app_policies('opportunity_progress');
create policy "opportunity progress: scoped read" on public.opportunity_progress
  for select to authenticated
  using (public.can_access_opportunity(opportunity_id));
create policy "opportunity progress: append" on public.opportunity_progress
  for insert to authenticated
  with check (
    (public.has_permission('opportunity.add') or public.has_permission('opportunity.edit'))
    and public.can_access_opportunity(opportunity_id)
    and changed_by = auth.uid()
  );

alter table public.opportunity_followers enable row level security;
select public._drop_app_policies('opportunity_followers');
create policy "opportunity followers: scoped read" on public.opportunity_followers
  for select to authenticated
  using (public.can_access_opportunity(opportunity_id));
create policy "opportunity followers: manage" on public.opportunity_followers
  for insert to authenticated
  with check (
    (public.has_permission('opportunity.add') or public.has_permission('opportunity.edit'))
    and public.can_access_opportunity(opportunity_id)
  );
create policy "opportunity followers: remove" on public.opportunity_followers
  for delete to authenticated
  using (
    (public.has_permission('opportunity.add') or public.has_permission('opportunity.edit'))
    and public.can_access_opportunity(opportunity_id)
  );

-- The client never receives arbitrary user rows directly. This function exposes
-- only active teammates to users who can manage opportunities.
create or replace function public.list_opportunity_users()
returns table (
  id uuid,
  full_name text,
  email text,
  role text,
  department text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select u.id, u.full_name, u.email, u.role, u.department
  from public.users u
  where u.status = 'active'
    and (public.has_permission('opportunity.edit') or public.has_permission('opportunity.view_all'))
  order by u.full_name;
$$;

revoke all on function public.list_opportunity_users() from public;
grant execute on function public.list_opportunity_users() to authenticated;

notify pgrst, 'reload schema';
