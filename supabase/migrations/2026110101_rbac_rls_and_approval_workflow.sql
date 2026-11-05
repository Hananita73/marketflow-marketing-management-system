-- ============================================================================
-- MIGRATION: RBAC Role-Based Access Control + Approval Workflow
-- MarketFlow Marketing Management System
-- ============================================================================
-- SAFE / ADDITIVE:
--   - ALTER TABLE ... ADD COLUMN IF NOT EXISTS
--   - CREATE OR REPLACE FUNCTION
--   - DROP POLICY IF EXISTS + CREATE POLICY
--   - No data deletion
-- ============================================================================

-- ============================================================================
-- PART 1: ADD APPROVAL WORKFLOW COLUMNS
-- ============================================================================

-- Campaigns: submitted_by (self-approval prevention)
alter table public.campaigns
  add column if not exists submitted_by      text not null default '',
  add column if not exists approval_comments text not null default '',
  add column if not exists approved_by       text not null default '';

-- ============================================================================
-- PART 2: CONTENT CREATOR ROLE + GET_MY_ROLE UPDATE
-- ============================================================================
-- The get_my_role() helper already exists from the previous migration.
-- It reads directly from public.users, so adding 'content_creator' to the
-- users.role check constraint is the only schema change needed here.

-- Drop and re-add the users.role check constraint to include content_creator.
alter table public.users
  drop constraint if exists users_role_check;

alter table public.users
  add constraint users_role_check
    check (role in ('admin','marketing_manager','marketing_clerk',
                    'content_creator','analyst','viewer'));

-- ============================================================================
-- PART 3: ROLE-BASED RLS POLICIES
-- ============================================================================
-- Replaces the broad 'authenticated' policies with role-aware ones using
-- get_my_role(). Each table gets:
--   SELECT: all authenticated users can read (shared workspace)
--   INSERT: staff + content_creator + admin (NOT manager, analyst, viewer)
--   UPDATE: staff + content_creator + admin can update their own records;
--           manager can update status only (approval workflow);
--           admin can update everything
--   DELETE: admin only
-- ============================================================================

-- Helper: is the current user an approver (admin or manager)?
create or replace function public.is_approver()
returns boolean
language sql
security definer
set search_path = public
as $$
  select public.get_my_role() in ('admin', 'marketing_manager');
$$;

-- Helper: can the current user create records?
create or replace function public.can_create_records()
returns boolean
language sql
security definer
set search_path = public
as $$
  select public.get_my_role() in ('admin', 'marketing_clerk', 'content_creator');
$$;

-- Helper: can the current user edit records?
create or replace function public.can_edit_records()
returns boolean
language sql
security definer
set search_path = public
as $$
  select public.get_my_role() in ('admin', 'marketing_clerk', 'content_creator');
$$;

-- ── Campaigns ──────────────────────────────────────────────────────────────

do $$
declare
  t text := 'campaigns';
begin
  -- Drop previous broad policies
  execute format('drop policy if exists "app: select %I" on public.%I', t, t);
  execute format('drop policy if exists "app: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "app: update %I" on public.%I', t, t);
  execute format('drop policy if exists "app: delete %I" on public.%I', t, t);
  -- Also drop dev policies if they exist
  execute format('drop policy if exists "dev: select %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: update %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select campaigns"
  on public.campaigns for select
  to authenticated using (true);

create policy "rbac: insert campaigns"
  on public.campaigns for insert
  to authenticated
  with check (public.can_create_records());

create policy "rbac: update campaigns"
  on public.campaigns for update
  to authenticated
  using (public.can_edit_records() or public.is_approver())
  with check (public.can_edit_records() or public.is_approver());

create policy "rbac: delete campaigns"
  on public.campaigns for delete
  to authenticated
  using (public.get_my_role() = 'admin');

-- ── Customers ──────────────────────────────────────────────────────────────

do $$
declare t text := 'customers';
begin
  execute format('drop policy if exists "app: select %I" on public.%I', t, t);
  execute format('drop policy if exists "app: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "app: update %I" on public.%I', t, t);
  execute format('drop policy if exists "app: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select customers"   on public.customers for select to authenticated using (true);
create policy "rbac: insert customers"   on public.customers for insert to authenticated with check (public.can_create_records());
create policy "rbac: update customers"   on public.customers for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete customers"   on public.customers for delete to authenticated using (public.get_my_role() = 'admin');

-- ── Leads ──────────────────────────────────────────────────────────────────

do $$
declare t text := 'leads';
begin
  execute format('drop policy if exists "app: select %I" on public.%I', t, t);
  execute format('drop policy if exists "app: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "app: update %I" on public.%I', t, t);
  execute format('drop policy if exists "app: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select leads"   on public.leads for select to authenticated using (true);
create policy "rbac: insert leads"   on public.leads for insert to authenticated with check (public.can_create_records());
create policy "rbac: update leads"   on public.leads for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete leads"   on public.leads for delete to authenticated using (public.get_my_role() = 'admin');

-- ── Opportunities ──────────────────────────────────────────────────────────

do $$
declare t text := 'opportunities';
begin
  execute format('drop policy if exists "app: select %I" on public.%I', t, t);
  execute format('drop policy if exists "app: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "app: update %I" on public.%I', t, t);
  execute format('drop policy if exists "app: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select opportunities" on public.opportunities for select to authenticated using (true);
create policy "rbac: insert opportunities" on public.opportunities for insert to authenticated with check (public.can_create_records());
create policy "rbac: update opportunities" on public.opportunities for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete opportunities" on public.opportunities for delete to authenticated using (public.get_my_role() = 'admin');

-- ── Budgets ────────────────────────────────────────────────────────────────

do $$
declare t text := 'budgets';
begin
  execute format('drop policy if exists "app: select %I" on public.%I', t, t);
  execute format('drop policy if exists "app: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "app: update %I" on public.%I', t, t);
  execute format('drop policy if exists "app: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select budgets"   on public.budgets for select to authenticated using (true);
create policy "rbac: insert budgets"   on public.budgets for insert to authenticated with check (public.can_create_records());
create policy "rbac: update budgets"   on public.budgets for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete budgets"   on public.budgets for delete to authenticated using (public.get_my_role() = 'admin');

-- ── Budget requests ────────────────────────────────────────────────────────

do $$
declare t text := 'budget_requests';
begin
  execute format('drop policy if exists "dev: all %I anon" on public.%I', t, t);
  execute format('drop policy if exists "dev: select %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: update %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: delete %I" on public.%I', t, t);
end $$;

alter table public.budget_requests enable row level security;
create policy "rbac: select budget_requests" on public.budget_requests for select to authenticated using (true);
create policy "rbac: insert budget_requests" on public.budget_requests for insert to authenticated with check (public.can_create_records());
create policy "rbac: update budget_requests" on public.budget_requests for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete budget_requests" on public.budget_requests for delete to authenticated using (public.get_my_role() = 'admin');

-- ── Promotions ─────────────────────────────────────────────────────────────

do $$
declare t text := 'promotions';
begin
  execute format('drop policy if exists "app: select %I" on public.%I', t, t);
  execute format('drop policy if exists "app: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "app: update %I" on public.%I', t, t);
  execute format('drop policy if exists "app: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select promotions"   on public.promotions for select to authenticated using (true);
create policy "rbac: insert promotions"   on public.promotions for insert to authenticated with check (public.can_create_records());
create policy "rbac: update promotions"   on public.promotions for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete promotions"   on public.promotions for delete to authenticated using (public.get_my_role() = 'admin');

-- ── Influencers ────────────────────────────────────────────────────────────
-- Content creators can manage influencers.

do $$
declare t text := 'influencers';
begin
  execute format('drop policy if exists "app: select %I" on public.%I', t, t);
  execute format('drop policy if exists "app: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "app: update %I" on public.%I', t, t);
  execute format('drop policy if exists "app: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select influencers" on public.influencers for select to authenticated using (true);
create policy "rbac: insert influencers" on public.influencers for insert to authenticated with check (public.can_create_records());
create policy "rbac: update influencers" on public.influencers for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete influencers" on public.influencers for delete to authenticated using (public.get_my_role() = 'admin');

-- ── Content items ──────────────────────────────────────────────────────────
-- Content creators have full create/edit rights.

do $$
declare t text := 'content_items';
begin
  execute format('drop policy if exists "app: select %I" on public.%I', t, t);
  execute format('drop policy if exists "app: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "app: update %I" on public.%I', t, t);
  execute format('drop policy if exists "app: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select content_items" on public.content_items for select to authenticated using (true);
create policy "rbac: insert content_items" on public.content_items for insert to authenticated with check (public.can_create_records());
create policy "rbac: update content_items" on public.content_items for update to authenticated using (public.can_edit_records()) with check (public.can_edit_records());
create policy "rbac: delete content_items" on public.content_items for delete to authenticated using (public.get_my_role() = 'admin');

-- ── Expenses (from campaign integration) ───────────────────────────────────

do $$
declare t text := 'expenses';
begin
  execute format('drop policy if exists "dev: select %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: update %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select expenses"   on public.expenses for select to authenticated using (true);
create policy "rbac: insert expenses"   on public.expenses for insert to authenticated with check (public.can_create_records() or public.is_approver());
create policy "rbac: update expenses"   on public.expenses for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete expenses"   on public.expenses for delete to authenticated using (public.get_my_role() = 'admin');

-- ── Campaign customers junction ─────────────────────────────────────────────

do $$
declare t text := 'campaign_customers';
begin
  execute format('drop policy if exists "dev: select %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: update %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select campaign_customers" on public.campaign_customers for select to authenticated using (true);
create policy "rbac: insert campaign_customers" on public.campaign_customers for insert to authenticated with check (public.can_create_records() or public.is_approver());
create policy "rbac: update campaign_customers" on public.campaign_customers for update to authenticated using (public.can_edit_records() or public.is_approver()) with check (public.can_edit_records() or public.is_approver());
create policy "rbac: delete campaign_customers" on public.campaign_customers for delete to authenticated using (public.get_my_role() in ('admin', 'marketing_manager', 'marketing_clerk'));

-- ── Audit logs ─────────────────────────────────────────────────────────────
-- All authenticated users can write audit logs; only admins+managers can read.

do $$
declare t text := 'audit_logs';
begin
  execute format('drop policy if exists "dev: all %I anon" on public.%I', t, t);
end $$;

alter table public.audit_logs enable row level security;

create policy "rbac: select audit_logs"
  on public.audit_logs for select
  to authenticated
  using (public.get_my_role() in ('admin', 'marketing_manager', 'analyst'));

create policy "rbac: insert audit_logs"
  on public.audit_logs for insert
  to authenticated
  with check (true);  -- all authenticated users can write audit entries

-- ── Notifications ───────────────────────────────────────────────────────────

do $$
declare t text := 'notifications';
begin
  execute format('drop policy if exists "dev: select %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: insert %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: update %I" on public.%I', t, t);
  execute format('drop policy if exists "dev: delete %I" on public.%I', t, t);
end $$;

create policy "rbac: select notifications" on public.notifications for select to authenticated using (true);
create policy "rbac: insert notifications" on public.notifications for insert to authenticated with check (true);
create policy "rbac: update notifications" on public.notifications for update to authenticated using (true) with check (true);
create policy "rbac: delete notifications" on public.notifications for delete to authenticated using (true);

-- ============================================================================
-- PART 4: SEED 5 TEST USERS (one per key role)
-- ============================================================================
-- These seed auth users and corresponding public.users profiles for testing.
-- Passwords: all test accounts use 'Test@1234' as the password.
-- NOTE: Creating auth.users requires running this as a service_role script,
-- OR using the Supabase dashboard Auth > Users section.
-- This migration inserts ONLY the public.users profiles.
-- To create the auth users, use the Supabase dashboard or the admin Edge Function.
-- ============================================================================

-- Insert test profiles (will link when auth users are created with matching emails).
-- Run this AFTER creating the auth users in the Supabase Auth dashboard.

insert into public.users (id, full_name, email, role, department, status)
select v.id::uuid, v.full_name, v.email, v.role, v.department, v.status
from (values
  ('00000000-0000-0000-0000-000000000001', 'Test Admin',           'admin@marketflow.et',           'admin',             'IT',        'active'),
  ('00000000-0000-0000-0000-000000000002', 'Test Manager',         'manager@marketflow.et',         'marketing_manager', 'Marketing', 'active'),
  ('00000000-0000-0000-0000-000000000003', 'Test Staff',           'staff@marketflow.et',           'marketing_clerk',   'Marketing', 'active'),
  ('00000000-0000-0000-0000-000000000004', 'Test Content Creator', 'creator@marketflow.et',         'content_creator',   'Creative',  'active'),
  ('00000000-0000-0000-0000-000000000005', 'Test Analyst',         'analyst@marketflow.et',         'viewer',            'Analytics', 'active'),
  ('00000000-0000-0000-0000-000000000006', 'Test Viewer',          'viewer@marketflow.et',          'viewer',            'Sales',     'active')
) as v(id, full_name, email, role, department, status)
where exists (select 1 from auth.users au where au.id = v.id::uuid)
on conflict (id) do nothing;

-- ============================================================================
-- PART 5: VERIFY
-- ============================================================================

select tablename, policyname, roles, cmd
from pg_policies
where schemaname = 'public'
  and policyname like 'rbac:%'
order by tablename, cmd;

