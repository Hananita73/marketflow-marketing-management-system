-- ============================================================================
-- MIGRATION: Campaign ↔ Customer (many-to-many) + Budget ↔ Campaign (1-to-many)
--            + Expenses linked to campaign & budget allocation
-- MarketFlow Marketing Management System
-- ============================================================================
-- HOW TO RUN:
--   Supabase Dashboard → SQL Editor → New Query → Paste → Run
--
-- This migration is ADDITIVE and SAFE / idempotent:
--   - ALTER TABLE ... ADD COLUMN IF NOT EXISTS
--   - CREATE TABLE / INDEX / TRIGGER IF NOT EXISTS
--   - Never drops or truncates existing data
--   - Existing customers / budgets keep their original records untouched;
--     records without a campaign assignment remain so until an authorised
--     user assigns them (no guessing of historical relationships).
-- ============================================================================

-- Ensure the updated_at helper exists (created by the base schema, but make
-- this migration self-contained when run on a partially-set-up project).
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;


-- ============================================================================
-- PART 1: CAMPAIGN_CUSTOMERS — enhance the existing junction table
-- ============================================================================
-- The base junction (migration 001) only carried (campaign_id, customer_id,
-- added_at). The spec requires per-association participation metadata so the
-- same customer can be tracked independently across multiple campaigns.
--
-- participation_status : Assigned | Active | Completed | Withdrawn
-- engagement_status    : Pending | Engaged | Unresponsive
-- conversion_status    : Not Converted | Interested | Converted
--
-- The composite primary key (campaign_id, customer_id) already guarantees
-- that a customer cannot be assigned to the same campaign twice.

alter table public.campaign_customers
  add column if not exists participation_status text not null default 'Assigned',
  add column if not exists engagement_status    text not null default 'Pending',
  add column if not exists conversion_status    text not null default 'Not Converted',
  add column if not exists notes                text not null default '',
  add column if not exists created_at           timestamptz not null default now(),
  add column if not exists updated_at           timestamptz not null default now();

-- 'added_at' from migration 001 is the original assignment timestamp; keep it
-- and treat it as the assigned_date for legacy rows.

create index if not exists idx_campaign_customers_campaign on public.campaign_customers (campaign_id);
-- idx_campaign_customers_customer already created by migration 001.

drop trigger if exists trg_campaign_customers_updated_at on public.campaign_customers;
create trigger trg_campaign_customers_updated_at
  before update on public.campaign_customers
  for each row execute function public.set_updated_at();

-- Keep RLS enabled (migration 001 already enabled it). Re-create granular
-- dev policies so the junction is usable with the anon key during dev.
alter table public.campaign_customers enable row level security;

do $$
declare
  pol record;
begin
  for pol in (
    select policyname from pg_policies
    where tablename = 'campaign_customers' and schemaname = 'public'
  ) loop
    execute format('drop policy if exists %I on public.campaign_customers', pol.policyname);
  end loop;
end $$;

create policy "dev: select campaign_customers" on public.campaign_customers
  for select to anon using (true);
create policy "dev: insert campaign_customers" on public.campaign_customers
  for insert to anon with check (true);
create policy "dev: update campaign_customers" on public.campaign_customers
  for update to anon using (true) with check (true);
create policy "dev: delete campaign_customers" on public.campaign_customers
  for delete to anon using (true);


-- ============================================================================
-- PART 2: BUDGETS — campaign relationship (one campaign → many budgets)
-- ============================================================================
-- Every budget record now belongs to a campaign. The column is nullable so
-- legacy budgets that pre-date this migration are preserved (an admin can
-- assign them later). New budgets created through the integrated workflow
-- always set campaign_id.

alter table public.budgets
  add column if not exists campaign_id text references public.campaigns(id) on delete set null;

create index if not exists idx_budgets_campaign_id on public.budgets (campaign_id);


-- ============================================================================
-- PART 3: EXPENSES — linked to campaign AND budget allocation
-- ============================================================================
-- Canonical expense store. Replaces the previous pattern of storing expenses
-- as a JSON column on campaigns (which was never persisted on upsert). Each
-- expense belongs to exactly one campaign and optionally one budget
-- allocation within that campaign.
--
-- status         : pending | approved | rejected  (approval workflow)
-- payment_status : Pending | Paid | Partial       (accounting state)

create table if not exists public.expenses (
  id             text primary key,
  campaign_id    text not null references public.campaigns(id) on delete cascade,
  budget_id      text references public.budgets(id) on delete set null,
  name           text not null,
  description     text not null default '',
  category       text not null default 'Other',
  amount         numeric(14,2) not null default 0 check (amount >= 0),
  expense_date   date not null default current_date,
  vendor         text not null default '',
  payment_status text not null default 'Pending',
  status         text not null default 'pending',
  recorded_by    text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Consistency guard: an expense's budget allocation must belong to the same
-- campaign as the expense itself. Enforced by trigger + the app layer.
create or replace function public.check_expense_campaign_consistency()
returns trigger language plpgsql as $$
declare
  budget_campaign text;
begin
  if new.budget_id is null then
    return new;
  end if;
  select campaign_id into budget_campaign from public.budgets where id = new.budget_id;
  if budget_campaign is null then
    raise exception 'Selected budget allocation is not assigned to any campaign.';
  end if;
  if budget_campaign <> new.campaign_id then
    raise exception 'Expense campaign (%) does not match its budget allocation''s campaign (%).',
      new.campaign_id, budget_campaign;
  end if;
  return new;
end $$;

drop trigger if exists trg_expense_campaign_consistency on public.expenses;
create trigger trg_expense_campaign_consistency
  before insert or update on public.expenses
  for each row execute function public.check_expense_campaign_consistency();

create index if not exists idx_expenses_campaign_id on public.expenses (campaign_id);
create index if not exists idx_expenses_budget_id   on public.expenses (budget_id);
create index if not exists idx_expenses_status      on public.expenses (status);
create index if not exists idx_expenses_date        on public.expenses (expense_date);

drop trigger if exists trg_expenses_updated_at on public.expenses;
create trigger trg_expenses_updated_at
  before update on public.expenses
  for each row execute function public.set_updated_at();

alter table public.expenses enable row level security;

do $$
declare
  pol record;
begin
  for pol in (
    select policyname from pg_policies
    where tablename = 'expenses' and schemaname = 'public'
  ) loop
    execute format('drop policy if exists %I on public.expenses', pol.policyname);
  end loop;
end $$;

create policy "dev: select expenses" on public.expenses
  for select to anon using (true);
create policy "dev: insert expenses" on public.expenses
  for insert to anon with check (true);
create policy "dev: update expenses" on public.expenses
  for update to anon using (true) with check (true);
create policy "dev: delete expenses" on public.expenses
  for delete to anon using (true);


-- ============================================================================
-- PART 4: DATA-INTEGRITY NOTES (no destructive changes)
-- ============================================================================
-- • Existing customers keep all their records; the junction table starts
--   empty — associations are created by users (or the app seed).
-- • Existing budgets keep campaign_id = NULL until an admin assigns a
--   campaign (the app flags these as "Unassigned" for review).
-- • Existing campaign.expenses JSON arrays are migrated into the new
--   expenses table by the Flutter app on first run (ExpenseRepository.init
--   seeds the table when it is empty), preserving all historical expenses
--   attached to the campaign they belong to.
-- ============================================================================

-- Verify the resulting structure.
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('campaign_customers', 'budgets', 'expenses')
order by table_name, ordinal_position;
