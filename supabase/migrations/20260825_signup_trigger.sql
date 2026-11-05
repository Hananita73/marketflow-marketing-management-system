-- ============================================================================
-- SIGNUP TRIGGER — 2026-08-25
-- ============================================================================
-- Automatically creates a public.users profile when a new user signs up
-- via Supabase Auth (public signup flow).
--
-- Security:
--   - Trigger is SECURITY DEFINER (runs as postgres, bypasses RLS)
--   - role is ALWAYS set to 'viewer' — never from user metadata
--   - status is ALWAYS set to 'active' — never from user metadata
--   - Only safe fields (full_name, email, department) come from metadata
-- ============================================================================


-- ── 1. HELPER FUNCTION ──────────────────────────────────────────────────────
-- Creates a public.users row for a newly signed-up auth user.
-- SECURITY DEFINER ensures it can INSERT into public.users even though
-- the production RLS removes the INSERT policy for authenticated users.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  user_full_name text;
  user_email     text;
  user_department text;
begin
  -- Extract safe fields from the signup metadata.
  -- Never trust role or status from client metadata.
  user_full_name := coalesce(new.raw_user_meta_data ->> 'full_name', 'New User');
  user_email     := coalesce(new.email, '');
  user_department := coalesce(new.raw_user_meta_data ->> 'department', 'General');

  -- Insert the profile with SAFE defaults only.
  insert into public.users (id, full_name, email, role, department, status)
  values (
    new.id,
    user_full_name,
    user_email,
    'viewer',          -- ALWAYS viewer for public signup — never overridden
    user_department,
    'active'            -- ALWAYS active for public signup — never overridden
  );

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Auto-creates a public.users profile when a new auth user signs up. '
  'Sets role=viewer and status=active regardless of client metadata.';


-- ── 2. TRIGGER ──────────────────────────────────────────────────────────────
-- Fires after a new row is inserted into auth.users.

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();


-- ── 3. VERIFICATION ─────────────────────────────────────────────────────────
-- After applying, test by signing up a new user:
--
--   1. Sign up via the Flutter app
--   2. Check auth.users:  select id, email from auth.users order by created_at desc limit 1;
--   3. Check public.users: select id, full_name, email, role, status from public.users order by created_at desc limit 1;
--   4. Expected: role = 'viewer', status = 'active', full_name from metadata
