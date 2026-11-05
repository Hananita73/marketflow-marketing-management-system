-- ============================================================================
-- MIGRATION 001: Schema Fixes + New Tables
-- MarketFlow Marketing Management System
-- ============================================================================
-- HOW TO RUN:
--   Supabase Dashboard → SQL Editor → New Query → Paste → Run
--
-- This migration is ADDITIVE and SAFE:
--   - Uses ALTER TABLE ... ADD COLUMN IF NOT EXISTS
--   - Uses CREATE TABLE IF NOT EXISTS
--   - Never drops or truncates existing data
-- ============================================================================

-- ============================================================================
-- PART A: FIX SCHEMA MISMATCHES
-- The Flutter remote stores already write these columns; the DB was missing them.
-- ============================================================================

-- A1. customers: missing FK columns
alter table public.customers
  add column if not exists lead_id        text default null,
  add column if not exists opportunity_id text default null,
  add column if not exists campaign_id    text default null;

-- A2. leads: missing campaign assignment column
alter table public.leads
  add column if not exists assigned_campaign_id text default null;

-- A3. opportunities: missing lead/customer FK columns
alter table public.opportunities
  add column if not exists lead_id     text default null,
  add column if not exists customer_id text default null;

-- A4. campaigns: missing approval workflow columns
alter table public.campaigns
  add column if not exists approval_comments text not null default '',
  add column if not exists approved_by       text not null default '';

-- ============================================================================
-- PART B: handle_new_user TRIGGER
-- Creates a public.users profile whenever a new auth.users row is inserted.
-- Referenced in auth_service.dart signUp() but was missing from schema file.
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, full_name, email, role, department, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'New User'),
    new.email,
    'viewer',
    coalesce(new.raw_user_meta_data->>'department', 'General'),
    'pending'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================================
-- PART C: NOTIFICATIONS TABLE
-- Replaces the current in-memory NotificationRepository stub.
-- ============================================================================

create table if not exists public.notifications (
  id          text primary key default gen_random_uuid()::text,
  user_id     uuid references auth.users(id) on delete cascade,
  title       text not null,
  message     text not null default '',
  category    text not null default 'system',
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists idx_notifications_user_id on public.notifications (user_id);
create index if not exists idx_notifications_is_read on public.notifications (is_read);
create index if not exists idx_notifications_created on public.notifications (created_at desc);

alter table public.notifications enable row level security;

-- Dev policies (anon key — tighten before production)
do $$
declare
  each_policy record;
begin
  for each_policy in (
    select policyname from pg_policies
    where tablename = 'notifications' and schemaname = 'public'
  ) loop
    execute format('drop policy if exists %I on public.notifications', each_policy.policyname);
  end loop;
end $$;

create policy "dev: select notifications" on public.notifications
  for select to anon using (true);
create policy "dev: insert notifications" on public.notifications
  for insert to anon with check (true);
create policy "dev: update notifications" on public.notifications
  for update to anon using (true) with check (true);
create policy "dev: delete notifications" on public.notifications
  for delete to anon using (true);

-- ============================================================================
-- PART D: AUDIT LOGS TABLE
-- ============================================================================

create table if not exists public.audit_logs (
  id          bigserial primary key,
  user_id     uuid references auth.users(id) on delete set null,
  user_name   text not null default '',
  action      text not null,
    -- 'create' | 'update' | 'delete' | 'approve' | 'reject' | 'login' | 'logout'
  module      text not null,
    -- 'Campaigns' | 'Leads' | 'Customers' | 'Budget' | 'Promotions' | 'Auth' | ...
  record_id   text not null default '',
  record_name text not null default '',
  details     jsonb not null default '{}',
  created_at  timestamptz not null default now()
);

create index if not exists idx_audit_logs_user_id  on public.audit_logs (user_id);
create index if not exists idx_audit_logs_action   on public.audit_logs (action);
create index if not exists idx_audit_logs_module   on public.audit_logs (module);
create index if not exists idx_audit_logs_created  on public.audit_logs (created_at desc);

alter table public.audit_logs enable row level security;

create policy "dev: all audit_logs anon" on public.audit_logs
  for all to anon using (true) with check (true);

-- ============================================================================
-- PART E: SMS CAMPAIGNS TABLE
-- ============================================================================

create table if not exists public.sms_campaigns (
  id              text primary key,
  name            text not null,
  campaign_id     text references public.campaigns(id) on delete set null,
  message         text not null default '',
  status          text not null default 'Draft',
  recipient_count integer not null default 0,
  sent_count      integer not null default 0,
  failed_count    integer not null default 0,
  scheduled_at    timestamptz,
  sent_at         timestamptz,
  created_by      text not null default '',
  provider_ref    text not null default '',
  recipients      jsonb not null default '[]',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_sms_campaigns_status      on public.sms_campaigns (status);
create index if not exists idx_sms_campaigns_campaign_id on public.sms_campaigns (campaign_id);

drop trigger if exists trg_sms_campaigns_updated_at on public.sms_campaigns;
create trigger trg_sms_campaigns_updated_at
  before update on public.sms_campaigns
  for each row execute function public.set_updated_at();

alter table public.sms_campaigns enable row level security;
create policy "dev: all sms_campaigns anon" on public.sms_campaigns
  for all to anon using (true) with check (true);

-- ============================================================================
-- PART F: BUDGET REQUESTS TABLE
-- ============================================================================

create table if not exists public.budget_requests (
  id              text primary key,
  budget_id       text references public.budgets(id) on delete set null,
  campaign_id     text references public.campaigns(id) on delete set null,
  requested_by    text not null default '',
  requested_amount numeric(14,2) not null default 0,
  category        text not null default 'Other',
  description     text not null default '',
  status          text not null default 'Pending',
    -- 'Pending' | 'Approved' | 'Rejected'
  reviewed_by     text not null default '',
  review_comments text not null default '',
  reviewed_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_budget_requests_status      on public.budget_requests (status);
create index if not exists idx_budget_requests_campaign_id on public.budget_requests (campaign_id);
create index if not exists idx_budget_requests_budget_id   on public.budget_requests (budget_id);

drop trigger if exists trg_budget_requests_updated_at on public.budget_requests;
create trigger trg_budget_requests_updated_at
  before update on public.budget_requests
  for each row execute function public.set_updated_at();

alter table public.budget_requests enable row level security;
create policy "dev: all budget_requests anon" on public.budget_requests
  for all to anon using (true) with check (true);

-- ============================================================================
-- PART G: AUTOMATION WORKFLOWS TABLE
-- ============================================================================

create table if not exists public.automation_workflows (
  id              text primary key,
  name            text not null,
  description     text not null default '',
  trigger_type    text not null default 'Manual',
  trigger_config  jsonb not null default '{}',
  status          text not null default 'Active',
    -- 'Active' | 'Paused' | 'Draft'
  steps           jsonb not null default '[]',
  run_count       integer not null default 0,
  last_run_at     timestamptz,
  created_by      text not null default '',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_automation_workflows_status on public.automation_workflows (status);

drop trigger if exists trg_automation_updated_at on public.automation_workflows;
create trigger trg_automation_updated_at
  before update on public.automation_workflows
  for each row execute function public.set_updated_at();

alter table public.automation_workflows enable row level security;
create policy "dev: all automation_workflows anon" on public.automation_workflows
  for all to anon using (true) with check (true);

-- ============================================================================
-- PART H: SYSTEM SETTINGS TABLE
-- ============================================================================

create table if not exists public.system_settings (
  id          text primary key default 'singleton',
  app_name    text not null default 'MarketFlow',
  language    text not null default 'English',
  date_format text not null default 'DD/MM/YYYY',
  time_zone   text not null default 'Africa/Addis_Ababa',
  currency    text not null default 'ETB',
  notif_campaigns boolean not null default true,
  notif_leads     boolean not null default true,
  notif_budget    boolean not null default true,
  notif_reports   boolean not null default true,
  notif_system    boolean not null default true,
  updated_at  timestamptz not null default now()
);

alter table public.system_settings enable row level security;
create policy "dev: all system_settings anon" on public.system_settings
  for all to anon using (true) with check (true);

-- Seed default settings row
insert into public.system_settings (id) values ('singleton')
  on conflict (id) do nothing;

-- ============================================================================
-- PART I: CAMPAIGN ↔ CUSTOMER JUNCTION TABLE
-- ============================================================================

create table if not exists public.campaign_customers (
  campaign_id text not null references public.campaigns(id) on delete cascade,
  customer_id integer not null references public.customers(id) on delete cascade,
  added_at    timestamptz not null default now(),
  primary key (campaign_id, customer_id)
);

create index if not exists idx_campaign_customers_customer on public.campaign_customers (customer_id);

alter table public.campaign_customers enable row level security;
create policy "dev: all campaign_customers anon" on public.campaign_customers
  for all to anon using (true) with check (true);

-- ============================================================================
-- PART J: CRM SYNC LOG TABLE
-- ============================================================================

create table if not exists public.crm_sync_log (
  id          bigserial primary key,
  sync_type   text not null default 'customers',
    -- 'customers' | 'leads'
  status      text not null default 'success',
    -- 'success' | 'failed' | 'partial'
  records_imported  integer not null default 0,
  records_updated   integer not null default 0,
  records_skipped   integer not null default 0,
  error_message     text not null default '',
  triggered_by      text not null default '',
  created_at        timestamptz not null default now()
);

alter table public.crm_sync_log enable row level security;
create policy "dev: all crm_sync_log anon" on public.crm_sync_log
  for all to anon using (true) with check (true);

-- ============================================================================
-- VERIFY
-- ============================================================================

select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;
