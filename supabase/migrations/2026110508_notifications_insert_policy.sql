-- Authenticated users may create notifications for themselves only.
-- Notification writes are initiated by the current user's own actions.
drop policy if exists "dynamic: insert notifications" on public.notifications;
create policy "dynamic: insert notifications" on public.notifications
  for insert to authenticated
  with check (public.is_active_user() and user_id = auth.uid());

notify pgrst, 'reload schema';
