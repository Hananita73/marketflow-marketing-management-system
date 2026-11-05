-- ============================================================================
-- MIGRATION v2: RBAC — marketing_clerk role + updated RLS
-- MarketFlow Marketing Management System
-- ============================================================================
-- This migration supersedes 20261101_rbac_rls_and_approval_workflow.sql.
-- Safe / additive:
--   - ALTER TABLE ... ADD COLUMN IF NOT EXISTS
--   - CREATE OR REPLACE FUNCTION
--   - DROP POLICY IF EXISTS then CREATE POLICY
--   - No data deletion
-- ============================================================================

-- ============================================================================
-- 1. UPDATE users.role CHECK CONSTRAINT
--    Five roles only. marketing_staff is renamed to marketing_clerk.
--    analyst removed (viewer covers read-only per spec).
-- ============================================================================

alter table public.users
  drop constraint if exists users_role_check;

alter table public.users
  add constraint users_role_check
    check (role in (
      'admin',
      'marketing_manager',
      'marketing_clerk',
      'content_creator',
      'viewer'
    ));

-- Migrate existing marketing_staff rows to marketing_clerk
update public.users
   set role = 'marketing_clerk'
 where role = 'marketing_staff';

-- Migrate existing analyst rows to viewer (read-only role)
update public.users
   set role = 'viewer'
 where role = 'analyst';

-- ============================================================================
-- 2. ADD APPROVAL WORKFLOW COLUMNS (idempotent)
-- ============================================================================

alter table public.campaigns
  add column if not exists submitted_by      text not null default '',
  add column if not exists approval_comments text not null default '',
  add column if not exists approved_by       text not null default '';

-- ============================================================================
-- 3. HELPER FUNCTIONS (role-based guards for RLS)
-- ============================================================================

-- Returns the current user's role from public.users.
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

-- True when the current user is an approver (admin or marketing_manager).
create or replace function public.is_approver()
returns boolean
language sql
security definer
set search_path = public
as $$
  select public.get_my_role() in ('admin', 'marketing_manager');
$$;

-- True when the current user can create/edit records.
-- marketing_clerk and content_creator can create; admin can do everything.
create or replace function public.can_create_records()
returns boolean
language sql
security definer
set search_path = public
as $$
  select public.get_my_role() in ('admin', 'marketing_clerk', 'content_creator');
$$;

create or replace function public.can_edit_records()
returns boolean
language sql
security definer
set search_path = public
as $$
  select public.get_my_role() in ('admin', 'marketing_clerk', 'content_creator');
$$;

-- ============================================================================
-- 4. ROLE-BASED RLS POLICIES
--    Pattern per table:
--      SELECT : all authenticated users (role-specific UI shows what's relevant)
--      INSERT : clerk + content_creator + admin
--      UPDATE : clerk + content_creator + admin; manager for approval fields
--      DELETE : admin only
-- ============================================================================

-- helper macro — drops existing policies for a given table
create or replace function public._drop_app_policies(tbl text)
returns void
language plpgsql
security definer
as $$
declare
  pol record;
begin
  for pol in (
    select policyname from pg_policies
    where tablename = tbl and schemaname = 'public'
  ) loop
    execute format('drop policy if exists %I on public.%I', pol.policyname, tbl);
  end loop;
end;
$$;

-- ── campaigns ───────────────────────────────────────────────────────────────
select public._drop_app_policies('campaigns');

create policy "rbac: select campaigns"
  on public.campaigns for select to authenticated using (true);

create policy "rbac: insert campaigns"
  on public.campaigns for insert to authenticated
  with check (public.can_create_records());

create policy "rbac: update campaigns"
  on public.campaigns for update to authenticated
  using  (public.can_edit_records() or public.is_approver())
  with check (public.can_edit_records() or public.is_approver());

create policy "rbac: delete campaigns"
  on public.campaigns for delete to authenticated
  using (public.get_my_role() = 'admin');

-- ── customers ───────────────────────────────────────────────────────────────
select public._drop_app_policies('customers');

create policy "rbac: select customers"   on public.customers for select to authenticated using (true);
create policy "rbac: insert customers"   on public.customers for insert to authenticated with check (public.can_create_records());
create policy "rbac: update customers"   on public.customers for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete customers"   on public.customers for delete to authenticated using (public.get_my_role() = 'admin');

-- ── leads ────────────────────────────────────────────────────────────────────
select public._drop_app_policies('leads');

create policy "rbac: select leads"   on public.leads for select to authenticated using (true);
create policy "rbac: insert leads"   on public.leads for insert to authenticated with check (public.can_create_records());
create policy "rbac: update leads"   on public.leads for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete leads"   on public.leads for delete to authenticated using (public.get_my_role() = 'admin');

-- ── opportunities ─────────────────────────────────────────────────────────────
select public._drop_app_policies('opportunities');

create policy "rbac: select opportunities" on public.opportunities for select to authenticated using (true);
create policy "rbac: insert opportunities" on public.opportunities for insert to authenticated with check (public.can_create_records());
create policy "rbac: update opportunities" on public.opportunities for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete opportunities" on public.opportunities for delete to authenticated using (public.get_my_role() = 'admin');

-- ── budgets ──────────────────────────────────────────────────────────────────
select public._drop_app_policies('budgets');

create policy "rbac: select budgets" on public.budgets for select to authenticated using (true);
create policy "rbac: insert budgets" on public.budgets for insert to authenticated with check (public.can_create_records());
create policy "rbac: update budgets" on public.budgets for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete budgets" on public.budgets for delete to authenticated using (public.get_my_role() = 'admin');

-- ── budget_requests ───────────────────────────────────────────────────────────
select public._drop_app_policies('budget_requests');

alter table public.budget_requests enable row level security;
create policy "rbac: select budget_requests" on public.budget_requests for select to authenticated using (true);
create policy "rbac: insert budget_requests" on public.budget_requests for insert to authenticated with check (public.can_create_records());
create policy "rbac: update budget_requests" on public.budget_requests for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete budget_requests" on public.budget_requests for delete to authenticated using (public.get_my_role() = 'admin');

-- ── promotions ────────────────────────────────────────────────────────────────
select public._drop_app_policies('promotions');

create policy "rbac: select promotions"   on public.promotions for select to authenticated using (true);
create policy "rbac: insert promotions"   on public.promotions for insert to authenticated with check (public.can_create_records());
create policy "rbac: update promotions"   on public.promotions for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete promotions"   on public.promotions for delete to authenticated using (public.get_my_role() = 'admin');

-- ── influencers ───────────────────────────────────────────────────────────────
-- content_creator has full access to influencers.
select public._drop_app_policies('influencers');

create policy "rbac: select influencers" on public.influencers for select to authenticated using (true);
create policy "rbac: insert influencers" on public.influencers for insert to authenticated with check (public.can_create_records());
create policy "rbac: update influencers" on public.influencers for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete influencers" on public.influencers for delete to authenticated using (public.get_my_role() = 'admin');

-- ── content_items ─────────────────────────────────────────────────────────────
-- content_creator has full access to content.
select public._drop_app_policies('content_items');

create policy "rbac: select content_items" on public.content_items for select to authenticated using (true);
create policy "rbac: insert content_items" on public.content_items for insert to authenticated with check (public.can_create_records());
create policy "rbac: update content_items" on public.content_items for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete content_items" on public.content_items for delete to authenticated using (public.get_my_role() = 'admin');

-- ── expenses ──────────────────────────────────────────────────────────────────
select public._drop_app_policies('expenses');

create policy "rbac: select expenses" on public.expenses for select to authenticated using (true);
create policy "rbac: insert expenses" on public.expenses for insert to authenticated with check (public.can_create_records() or public.is_approver());
create policy "rbac: update expenses" on public.expenses for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete expenses" on public.expenses for delete to authenticated using (public.get_my_role() = 'admin');

-- ── campaign_customers junction ───────────────────────────────────────────────
select public._drop_app_policies('campaign_customers');

create policy "rbac: select campaign_customers" on public.campaign_customers for select to authenticated using (true);
create policy "rbac: insert campaign_customers" on public.campaign_customers for insert to authenticated with check (public.can_create_records() or public.is_approver());
create policy "rbac: update campaign_customers" on public.campaign_customers for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete campaign_customers" on public.campaign_customers for delete to authenticated using (public.get_my_role() in ('admin', 'marketing_manager', 'marketing_clerk'));

-- ── users table (admin-only mutations) ───────────────────────────────────────
select public._drop_app_policies('users');

create policy "rbac: select users" on public.users for select to authenticated using (true);

-- Users can update their own profile; admins can update anyone.
create policy "rbac: update own profile" on public.users for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "rbac: update admin" on public.users for update to authenticated
  using (public.get_my_role() = 'admin')
  with check (public.get_my_role() = 'admin');

create policy "rbac: delete admin" on public.users for delete to authenticated
  using (public.get_my_role() = 'admin');

-- ── audit_logs ────────────────────────────────────────────────────────────────
select public._drop_app_policies('audit_logs');
alter table public.audit_logs enable row level security;

-- All authenticated users can write audit entries.
create policy "rbac: insert audit_logs" on public.audit_logs for insert to authenticated with check (true);

-- Only admins, managers, and viewers (for reports) can read audit logs.
create policy "rbac: select audit_logs" on public.audit_logs for select to authenticated
  using (public.get_my_role() in ('admin', 'marketing_manager'));

-- ── notifications ─────────────────────────────────────────────────────────────
select public._drop_app_policies('notifications');

create policy "rbac: select notifications" on public.notifications for select to authenticated using (true);
create policy "rbac: insert notifications" on public.notifications for insert to authenticated with check (true);
create policy "rbac: update notifications" on public.notifications for update to authenticated using (true) with check (true);
create policy "rbac: delete notifications" on public.notifications for delete to authenticated using (true);

-- ============================================================================
-- 5. SEED TEST USERS
--    One per role for testing. Replace UUIDs after creating accounts in Auth.
-- ============================================================================

insert into public.users (id, full_name, email, role, department, status)
select v.id::uuid, v.full_name, v.email, v.role, v.department, v.status
from (values
  ('00000000-0000-0000-0000-000000000001', 'Test Admin',   'admin@marketflow.et',   'admin',             'IT',        'active'),
  ('00000000-0000-0000-0000-000000000002', 'Test Manager', 'manager@marketflow.et', 'marketing_manager', 'Marketing', 'active'),
  ('00000000-0000-0000-0000-000000000003', 'Test Clerk',   'clerk@marketflow.et',   'marketing_clerk',   'Marketing', 'active'),
  ('00000000-0000-0000-0000-000000000004', 'Test Creator', 'creator@marketflow.et', 'content_creator',   'Creative',  'active'),
  ('00000000-0000-0000-0000-000000000005', 'Test Viewer',  'viewer@marketflow.et',  'viewer',            'Sales',     'active')
) as v(id, full_name, email, role, department, status)
where exists (select 1 from auth.users au where au.id = v.id::uuid)
on conflict (id) do nothing;

-- ============================================================================
-- 6. VERIFY
-- ============================================================================

select
  schemaname, tablename, policyname, roles, cmd
from pg_policies
where schemaname = 'public'
  and policyname like 'rbac:%'
order by tablename, cmd;
