alter table public.campaign_customers
  add column if not exists allocated_amount numeric(14, 2) not null default 0
    check (allocated_amount >= 0);

alter table public.expenses
  add column if not exists company text not null default '';

create or replace function public.check_campaign_company_allocation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company text;
  v_other_allocated numeric(14, 2);
  v_company_spent numeric(14, 2);
begin
  select coalesce(nullif(btrim(c.company), ''), btrim(c.name))
    into v_company
    from public.customers c
   where c.id = new.customer_id;

  if v_company is null or v_company = '' then
    raise exception 'The assigned customer must have a company or contact name.';
  end if;

  if tg_op = 'INSERT' then
    select coalesce(sum(cc.allocated_amount), 0)
      into v_other_allocated
      from public.campaign_customers cc
      join public.customers c on c.id = cc.customer_id
     where cc.campaign_id = new.campaign_id
       and coalesce(nullif(btrim(c.company), ''), btrim(c.name)) = v_company;
  else
    select coalesce(sum(cc.allocated_amount), 0)
      into v_other_allocated
      from public.campaign_customers cc
      join public.customers c on c.id = cc.customer_id
     where cc.campaign_id = new.campaign_id
       and (cc.campaign_id, cc.customer_id) <> (old.campaign_id, old.customer_id)
       and coalesce(nullif(btrim(c.company), ''), btrim(c.name)) = v_company;
  end if;

  select coalesce(sum(e.amount), 0)
    into v_company_spent
    from public.expenses e
   where e.campaign_id = new.campaign_id
     and e.company = v_company
     and e.status <> 'rejected';

  if v_other_allocated + new.allocated_amount < v_company_spent then
    raise exception 'Company allocation cannot be less than the amount already spent.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_campaign_company_allocation on public.campaign_customers;
create trigger trg_campaign_company_allocation
  before insert or update of allocated_amount, customer_id, campaign_id
  on public.campaign_customers
  for each row execute function public.check_campaign_company_allocation();

create or replace function public.check_expense_company_allocation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_allocated numeric(14, 2);
  v_spent numeric(14, 2);
begin
  if btrim(new.company) = '' then
    return new;
  end if;

  select coalesce(sum(cc.allocated_amount), 0)
    into v_allocated
    from public.campaign_customers cc
    join public.customers c on c.id = cc.customer_id
   where cc.campaign_id = new.campaign_id
     and coalesce(nullif(btrim(c.company), ''), btrim(c.name)) = btrim(new.company);

  if v_allocated <= 0 then
    raise exception 'Assign a company budget before recording its expense.';
  end if;

  select coalesce(sum(e.amount), 0)
    into v_spent
    from public.expenses e
   where e.campaign_id = new.campaign_id
     and e.company = btrim(new.company)
     and e.status <> 'rejected'
     and e.id <> new.id;

  if v_spent + new.amount > v_allocated then
    raise exception 'Expense exceeds the company budget allocation.';
  end if;

  new.company := btrim(new.company);
  return new;
end;
$$;

drop trigger if exists trg_expense_company_allocation on public.expenses;
create trigger trg_expense_company_allocation
  before insert or update of campaign_id, company, amount, status
  on public.expenses
  for each row execute function public.check_expense_company_allocation();
