-- ==========================================================================
-- Dynamic permission enforcement for every CRUD operation
-- ============================================================================

create or replace function public.has_permission(p_permission_key text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_active_user()
    and (
      public.get_my_role() = 'admin'
      or exists (
        select 1
        from public.role_permissions rp
        where rp.role_key = public.get_my_role()
          and rp.permission_key = p_permission_key
      )
    );
$$;

revoke all on function public.has_permission(text) from public;
grant execute on function public.has_permission(text) to authenticated;

create or replace function public.is_approver()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_permission('campaign.approve')
      or public.has_permission('budget.approve')
      or public.has_permission('promotion.approve');
$$;

create or replace function public.can_create_records()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_permission('campaign.add')
      or public.has_permission('customer.add')
      or public.has_permission('lead.add')
      or public.has_permission('opportunity.add')
      or public.has_permission('influencer.add')
      or public.has_permission('content.add')
      or public.has_permission('promotion.add')
      or public.has_permission('budget.add')
      or public.has_permission('communication.add')
      or public.has_permission('automation.add');
$$;

create or replace function public.can_edit_records()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.has_permission('campaign.edit')
      or public.has_permission('customer.edit')
      or public.has_permission('lead.edit')
      or public.has_permission('opportunity.edit')
      or public.has_permission('influencer.edit')
      or public.has_permission('content.edit')
      or public.has_permission('promotion.edit')
      or public.has_permission('budget.edit')
      or public.has_permission('communication.edit')
      or public.has_permission('automation.edit');
$$;

revoke all on function public.is_approver() from public;
revoke all on function public.can_create_records() from public;
revoke all on function public.can_edit_records() from public;
grant execute on function public.is_approver() to authenticated;
grant execute on function public.can_create_records() to authenticated;
grant execute on function public.can_edit_records() to authenticated;

-- Replace historical role-based policies with the named permission keys used
-- by the Flutter controls. This makes custom roles work without another SQL
-- migration whenever an Administrator creates a role.
do $$
declare
  v_table text;
  v_prefix text;
  v_select_key text;
  v_add_key text;
  v_edit_key text;
  v_delete_key text;
begin
  for v_table, v_prefix, v_select_key, v_add_key, v_edit_key, v_delete_key in
    select * from (values
      ('campaigns', 'campaign', 'campaign.view', 'campaign.add', 'campaign.edit', 'campaign.delete'),
      ('customers', 'customer', 'customer.view', 'customer.add', 'customer.edit', 'customer.delete'),
      ('leads', 'lead', 'lead.view', 'lead.add', 'lead.edit', 'lead.delete'),
      ('opportunities', 'opportunity', 'opportunity.view', 'opportunity.add', 'opportunity.edit', 'opportunity.delete'),
      ('influencers', 'influencer', 'influencer.view', 'influencer.add', 'influencer.edit', 'influencer.delete'),
      ('content_items', 'content', 'content.view', 'content.add', 'content.edit', 'content.delete'),
      ('promotions', 'promotion', 'promotion.view', 'promotion.add', 'promotion.edit', 'promotion.delete'),
      ('budgets', 'budget', 'budget.view', 'budget.add', 'budget.edit', 'budget.delete'),
      ('budget_requests', 'budget_request', 'budget.view', 'budget.add', 'budget.edit', 'budget.delete'),
      ('expenses', 'expense', 'budget.view', 'budget.add', 'budget.edit', 'budget.delete'),
      ('campaign_customers', 'campaign_customer', 'campaign.view', 'campaign.edit', 'campaign.edit', 'campaign.edit')
    ) as policy_rows(table_name, prefix, select_key, add_key, edit_key, delete_key)
  loop
    perform public._drop_app_policies(v_table);
    execute format(
      'create policy %I on public.%I for select to authenticated using (public.has_permission(%L));',
      'dynamic: select ' || v_prefix, v_table, v_select_key
    );
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (public.has_permission(%L));',
      'dynamic: insert ' || v_prefix, v_table, v_add_key
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (public.has_permission(%L)) with check (public.has_permission(%L));',
      'dynamic: update ' || v_prefix, v_table, v_edit_key, v_edit_key
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using (public.has_permission(%L));',
      'dynamic: delete ' || v_prefix, v_table, v_delete_key
    );
  end loop;
end $$;

select public._drop_app_policies('audit_logs');
create policy "dynamic: select audit_logs" on public.audit_logs
  for select to authenticated using (public.has_permission('audit.view'));
create policy "dynamic: insert audit_logs" on public.audit_logs
  for insert to authenticated
  with check (public.is_active_user() and user_id = auth.uid());

select public._drop_app_policies('notifications');
create policy "dynamic: select notifications" on public.notifications
  for select to authenticated
  using (public.is_active_user() and
    (user_id = auth.uid() or public.is_admin_user() or
     public.has_permission('notification.view')));
create policy "dynamic: update notifications" on public.notifications
  for update to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid());
create policy "dynamic: delete notifications" on public.notifications
  for delete to authenticated using (user_id = auth.uid());

-- Record role CRUD in the same central audit stream shown by the admin UI.
create or replace function public.audit_app_role_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role_key text := coalesce(new.role_key, old.role_key);
  v_name text := coalesce(new.name, old.name, v_role_key);
  v_action text := case tg_op
    when 'INSERT' then 'role_create'
    when 'UPDATE' then 'role_change'
    else 'role_delete'
  end;
begin
  insert into public.audit_logs
    (user_id, user_name, action, module, record_id, record_name, details)
  values
    (auth.uid(), coalesce((select full_name from public.users where id = auth.uid()), ''),
     v_action, 'Roles & Permissions', v_role_key, v_name,
     jsonb_build_object('operation', tg_op, 'role_key', v_role_key));
  return coalesce(new, old);
end;
$$;

drop trigger if exists app_roles_audit_trigger on public.app_roles;
create trigger app_roles_audit_trigger
after insert or update or delete on public.app_roles
for each row execute function public.audit_app_role_change();

notify pgrst, 'reload schema';
