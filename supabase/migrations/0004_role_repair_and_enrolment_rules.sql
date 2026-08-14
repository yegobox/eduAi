-- EduAI — role repair + who may enrol in a school
-- Run AFTER 0003. Safe to re-run.
--
-- Two fixes to real holes found by using the flow:
--
--   1. 0003's backfill wrote 'student' for every pre-existing account,
--      ignoring the role each one asked for at sign-up. Anybody who signed up
--      as a parent or a school before applying 0003 was silently demoted to
--      the student shell — no admin surface, no create-school step, no payment
--      gate — and the protect-role trigger then blocked the app from fixing
--      it. 0003 no longer does this; this migration repairs databases where it
--      already ran.
--
--   2. Nothing stopped a school-admin (or a parent) joining somebody else's
--      school as a student. That consumes a seat on that school's licence and
--      puts a director into a student's enrolment, which is not a thing that
--      should be possible.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. Repair roles that the old backfill flattened
-- ─────────────────────────────────────────────────────────────────────────

-- role_from_metadata may not exist yet if 0003 was applied before this fix.
create or replace function public.role_from_metadata(p_meta jsonb)
returns text
language sql
immutable
as $$
  select case lower(trim(coalesce(p_meta->>'role', '')))
           when 'parent'       then 'parent'
           when 'school_admin' then 'school_admin'
           when 'schooladmin'  then 'school_admin'
           when 'admin'        then 'school_admin'
           else 'student'
         end;
$$;

-- Only ever *promotes* from 'student' to what the account asked for. A role
-- that was set deliberately later (by support, or by this migration on a
-- previous run) is never overwritten by stale sign-up metadata.
--
-- The trigger guard only fires for requests carrying an end-user JWT, so this
-- runs fine from the SQL editor or a service-role connection.
update public.profiles p
   set role = public.role_from_metadata(u.raw_user_meta_data)
  from auth.users u
 where u.id = p.id
   and p.role = 'student'
   and public.role_from_metadata(u.raw_user_meta_data) <> 'student';

-- Whoever created a school is its admin, whatever their metadata said.
update public.profiles p
   set role = 'school_admin'
 where p.role <> 'school_admin'
   and exists (select 1 from public.schools s where s.created_by = p.id);

-- A deliberate, auditable way to convert an account — the supported answer to
-- "I picked the wrong thing at sign-up". Callable only by the service role
-- (and the SQL editor), never by the app: a client that could call this could
-- hand itself the admin shell.
create or replace function public.set_account_role(
  p_user_id uuid,
  p_role    text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    raise exception 'set_account_role is not callable by a signed-in client';
  end if;
  if p_role not in ('student', 'parent', 'school_admin') then
    raise exception 'unknown role %', p_role;
  end if;

  update public.profiles set role = p_role, updated_at = now()
   where id = p_user_id;
  if not found then
    raise exception 'no profile for %', p_user_id;
  end if;

  return p_role;
end;
$$;

revoke all on function public.set_account_role(uuid, text) from public;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. Who may enrol in a school
--
-- A seat on a school's licence belongs to a *student*. The rules:
--
--   * a student account may enrol itself, as 'student', in any school
--   * a school admin may only create 'owner'/'teacher' rows, and only for a
--     school it created (this is what createSchool/createClass rely on)
--   * a parent account enrols in nothing — a parent follows a child through
--     parent_students, and joining as a student would consume a seat
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.may_enrol(
  p_school_id uuid,
  p_role      text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case public.my_role()
           when 'student'      then p_role = 'student'
           when 'school_admin' then p_role in ('owner', 'teacher')
                                     and public.is_my_school(p_school_id)
           else false
         end;
$$;

drop policy if exists memberships_insert_self on public.memberships;
create policy memberships_insert_self on public.memberships
  for insert to authenticated with check (
    user_id = auth.uid() and public.may_enrol(school_id, role)
  );

grant execute on function public.role_from_metadata(jsonb)   to authenticated;
grant execute on function public.may_enrol(uuid, text)       to authenticated;
