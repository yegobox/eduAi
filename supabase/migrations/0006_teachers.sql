-- EduAI — teacher accounts
-- Run AFTER 0005. Safe to re-run.
--
-- A director delegating to teachers is the difference between a 3-class pilot
-- and a 30-class school. A teacher gets their own shell: their classes, their
-- rosters, their students' progress, and the parent invites for those students.
--
-- The one rule that shapes everything here: **the teacher role is granted by
-- invitation, never chosen at sign-up.** If `role_from_metadata` accepted
-- 'teacher', anybody could sign up as a teacher and then only need a class id
-- to start reading children's progress. So teacher is absent from that
-- allowlist, and the only way to become one is to redeem a code minted by the
-- school that employs you.

-- ─────────────────────────────────────────────────────────────────────────
-- Role + invite kind
-- ─────────────────────────────────────────────────────────────────────────

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('student', 'parent', 'school_admin', 'teacher'));

alter table public.invites drop constraint if exists invites_kind_check;
alter table public.invites
  add constraint invites_kind_check
  check (kind in ('parent_of_student', 'student_of_parent', 'teacher_of_school'));

-- `redeem_invite` has to promote a student profile to teacher, but the guard in
-- 0003 blocks any role change carrying an end-user JWT — and a security-definer
-- function still sees `auth.uid()`, because it reads a request-scoped claim
-- rather than the connection's role. So trusted functions announce themselves
-- with a session-local flag instead of the guard being loosened.
create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and coalesce(current_setting('app.role_change_allowed', true), '') <> 'on'
  then
    raise exception
      'role cannot be changed from the client; contact support to convert an account';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────

-- True when the caller teaches at this school.
create or replace function public.is_teacher_at(p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.memberships m
     where m.user_id = auth.uid()
       and m.school_id = p_school_id
       and m.role = 'teacher'
  );
$$;

-- The single school a teacher belongs to (the earliest, if somehow more).
create or replace function public.my_teaching_school_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select m.school_id
    from public.memberships m
   where m.user_id = auth.uid() and m.role = 'teacher'
   order by m.created_at
   limit 1;
$$;

-- True when the caller may see a class: its school's admin, or a teacher of
-- that class (class-level membership) or of its school.
create or replace function public.may_view_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.classes c
     where c.id = p_class_id
       and (
         public.is_my_school(c.school_id)
         or public.is_teacher_at(c.school_id)
       )
  );
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Inviting a teacher
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.invite_teacher(p_contact text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_school uuid := public.my_school_id();
  v_code   text;
  v_id     uuid;
begin
  if public.my_role() <> 'school_admin' or v_school is null then
    raise exception 'only a school admin can invite a teacher';
  end if;

  v_code := public.new_invite_code();
  insert into public.invites (kind, code, school_id, contact, created_by)
  values ('teacher_of_school', v_code, v_school,
          nullif(trim(coalesce(p_contact, '')), ''), auth.uid())
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'code', v_code,
                            'kind', 'teacher_of_school');
end;
$$;

-- Redeems all three invite kinds. A teacher code promotes the redeeming
-- account and enrols it as a teacher of the inviting school.
create or replace function public.redeem_invite(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_role   text := public.my_role();
  v_invite public.invites;
  v_parent uuid;
  v_child  uuid;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  select * into v_invite
    from public.invites
   where code = upper(trim(p_code))
   for update;

  if not found then
    raise exception 'that code does not match any invite';
  end if;
  if v_invite.status <> 'pending' then
    raise exception 'that invite has already been used';
  end if;
  if v_invite.expires_at <= now() then
    update public.invites set status = 'expired' where id = v_invite.id;
    raise exception 'that invite has expired — ask for a new code';
  end if;

  -- ---- teacher ----------------------------------------------------------
  if v_invite.kind = 'teacher_of_school' then
    -- A parent or a director redeeming a teacher code would lose their own
    -- surface, so only a plain account (or an existing teacher) may.
    if v_role not in ('student', 'teacher') then
      raise exception
        'sign in with the account that should become a teacher (not a parent '
        'or school account)';
    end if;

    perform set_config('app.role_change_allowed', 'on', true);
    update public.profiles set role = 'teacher', updated_at = now()
     where id = v_uid and role <> 'teacher';
    perform set_config('app.role_change_allowed', 'off', true);

    insert into public.memberships (user_id, school_id, class_id, role)
    values (v_uid, v_invite.school_id, null, 'teacher')
    on conflict do nothing;

    update public.invites
       set status = 'accepted', accepted_by = v_uid, accepted_at = now()
     where id = v_invite.id;

    return jsonb_build_object('kind', 'teacher_of_school',
                              'school_id', v_invite.school_id,
                              'role', 'teacher');
  end if;

  -- ---- family links -----------------------------------------------------
  if v_invite.kind = 'parent_of_student' then
    if v_role <> 'parent' then
      raise exception 'sign in with a parent account to use this code';
    end if;
    v_parent := v_uid;
    v_child  := v_invite.student_id;
  else
    if v_role <> 'student' then
      raise exception 'sign in with the student account to use this code';
    end if;
    v_parent := v_invite.parent_id;
    v_child  := v_uid;
  end if;

  if v_parent = v_child then
    raise exception 'an account cannot be its own parent';
  end if;

  insert into public.parent_students (parent_id, student_id, source)
  values (v_parent, v_child,
          case when v_invite.kind = 'parent_of_student'
               then 'school' else 'parent' end)
  on conflict (parent_id, student_id) do nothing;

  update public.invites
     set status = 'accepted', accepted_by = v_uid, accepted_at = now()
   where id = v_invite.id;

  return jsonb_build_object('parent_id', v_parent, 'student_id', v_child,
                            'kind', v_invite.kind);
end;
$$;

-- A teacher may invite the parent of a student in their own school; the admin
-- keeps the same power over the whole roster.
create or replace function public.invite_parent(
  p_student_id uuid,
  p_contact    text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_school uuid;
  v_code   text;
  v_id     uuid;
begin
  v_school := case public.my_role()
                when 'school_admin' then public.my_school_id()
                when 'teacher'      then public.my_teaching_school_id()
                else null
              end;
  if v_school is null then
    raise exception 'only a school admin or teacher can invite a parent';
  end if;
  if not exists (
    select 1 from public.memberships
     where school_id = v_school and user_id = p_student_id
  ) then
    raise exception 'that student is not enrolled in your school';
  end if;

  v_code := public.new_invite_code();
  insert into public.invites (
    kind, code, school_id, student_id, contact, created_by
  ) values (
    'parent_of_student', v_code, v_school, p_student_id,
    nullif(trim(coalesce(p_contact, '')), ''), auth.uid()
  )
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'code', v_code,
                            'kind', 'parent_of_student');
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- What a teacher reads
-- ─────────────────────────────────────────────────────────────────────────

-- The caller's classes, with live student counts. An admin gets every class in
-- their school; a teacher gets the school's classes they teach in.
create or replace function public.teacher_classes()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_school uuid;
  v_rows   jsonb;
begin
  v_school := coalesce(public.my_school_id(), public.my_teaching_school_id());
  if v_school is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(entry order by name), '[]'::jsonb)
    into v_rows
    from (
      select jsonb_build_object(
               'id',            c.id,
               'school_id',     c.school_id,
               'name',          c.name,
               'grade',         c.grade,
               'join_code',     c.join_code,
               'student_count', (
                 select count(*)::integer from public.memberships m
                  where m.class_id = c.id and m.role = 'student')
             ) as entry,
             c.name as name
        from public.classes c
       where c.school_id = v_school
    ) t;

  return v_rows;
end;
$$;

-- Per-student progress for one class, rolled up from learning_events.
--
-- A security-definer function rather than an RLS policy on learning_events:
-- a teacher needs *aggregates* over their students, not the right to read raw
-- events, and a tutor question is a child's own conversation. Only the counts
-- and the accuracy leave this function.
create or replace function public.class_progress(
  p_class_id uuid,
  p_days     integer default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rows  jsonb;
  v_since timestamptz := now() - make_interval(days => greatest(coalesce(p_days, 30), 1));
begin
  if not public.may_view_class(p_class_id) then
    raise exception 'that class is not yours';
  end if;

  select coalesce(jsonb_agg(entry order by student_name), '[]'::jsonb)
    into v_rows
    from (
      select jsonb_build_object(
               'student_id',   m.user_id,
               'student_name', coalesce(p.display_name, 'Student'),
               'questions',    coalesce(e.questions, 0),
               'checks',       coalesce(e.checks, 0),
               'correct',      coalesce(e.correct, 0),
               'last_active',  e.last_active,
               'parents_linked', (
                 select count(*)::integer from public.parent_students ps
                  where ps.student_id = m.user_id)
             ) as entry,
             coalesce(p.display_name, 'Student') as student_name
        from public.memberships m
        left join public.profiles p on p.id = m.user_id
        left join (
          select le.user_id,
                 count(*) filter (where le.kind = 'question')::integer as questions,
                 count(*) filter (where le.kind = 'check')::integer     as checks,
                 count(*) filter (where le.is_correct)::integer         as correct,
                 max(le.created_at)                                     as last_active
            from public.learning_events le
           where le.created_at >= v_since
           group by le.user_id
        ) e on e.user_id = m.user_id
       where m.class_id = p_class_id
         and m.role = 'student'
    ) t;

  return v_rows;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Entitlement + write rules
-- ─────────────────────────────────────────────────────────────────────────

-- A teacher is covered by the school that employs them. Slotted in before the
-- student branch, since a teacher has a membership too and would otherwise be
-- billed as a seat.
create or replace function public.access_state()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid      uuid := auth.uid();
  v_role     text;
  v_now      timestamptz := now();
  v_settings public.billing_settings;
  v_school   record;
  v_sub      record;
  v_children integer := 0;
  v_status   text;
  v_until    timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('status', 'unknown', 'source', 'none',
                              'role', 'student');
  end if;

  select * into v_settings from public.billing_settings where id;
  v_role := public.my_role();

  -- ---- School admin: the licence for the school they created -------------
  if v_role = 'school_admin' then
    select s.id           as school_id,
           s.name         as school_name,
           l.tier_id, l.status, l.seats_purchased, l.price_per_seat_rwf,
           l.trial_ends_at, l.current_period_end,
           public.school_seats_used(s.id) as seats_used
      into v_school
      from public.schools s
      join public.school_licenses l on l.school_id = s.id
     where s.created_by = v_uid
     order by s.created_at
     limit 1;

    if not found then
      return jsonb_build_object('status', 'needs_setup', 'source', 'none',
                                'role', v_role, 'children_linked', 0);
    end if;

    v_status := case
      when v_school.status = 'active'
       and coalesce(v_school.current_period_end, v_now) > v_now then 'entitled'
      when v_school.status = 'trialing'
       and coalesce(v_school.trial_ends_at, v_now) > v_now then 'trialing'
      else 'needs_payment'
    end;

    return jsonb_build_object(
      'status',          v_status,
      'source',          'school_license',
      'role',            v_role,
      'school_id',       v_school.school_id,
      'school_name',     v_school.school_name,
      'tier_id',         v_school.tier_id,
      'license_status',  v_school.status,
      'seats_purchased', v_school.seats_purchased,
      'seats_used',      v_school.seats_used,
      'trial_seat_cap',  v_settings.trial_seat_cap,
      'valid_until',     case when v_school.status = 'trialing'
                              then v_school.trial_ends_at
                              else v_school.current_period_end end,
      'children_linked', 0
    );
  end if;

  -- ---- Teacher: covered by the school that employs them -----------------
  if v_role = 'teacher' then
    select s.id as school_id, s.name as school_name, l.tier_id,
           l.status, l.trial_ends_at, l.current_period_end
      into v_school
      from public.memberships m
      join public.schools s         on s.id = m.school_id
      join public.school_licenses l on l.school_id = s.id
     where m.user_id = v_uid and m.role = 'teacher'
     order by m.created_at
     limit 1;

    if not found then
      return jsonb_build_object('status', 'needs_setup', 'source', 'none',
                                'role', v_role, 'children_linked', 0);
    end if;

    return jsonb_build_object(
      'status',         case
                          when v_school.status = 'active'
                           and coalesce(v_school.current_period_end, v_now) > v_now
                            then 'entitled'
                          when v_school.status = 'trialing'
                           and coalesce(v_school.trial_ends_at, v_now) > v_now
                            then 'trialing'
                          else 'needs_payment'
                        end,
      'source',         'school_license',
      'role',           v_role,
      'school_id',      v_school.school_id,
      'school_name',    v_school.school_name,
      'tier_id',        v_school.tier_id,
      'license_status', v_school.status,
      'valid_until',    case when v_school.status = 'trialing'
                             then v_school.trial_ends_at
                             else v_school.current_period_end end,
      'children_linked', 0
    );
  end if;

  -- ---- Parent: covered if any child's school pays, or they pay ----------
  if v_role = 'parent' then
    select count(*)::integer into v_children
      from public.parent_students where parent_id = v_uid;

    select s.id as school_id, s.name as school_name, l.tier_id,
           l.status, l.trial_ends_at, l.current_period_end
      into v_school
      from public.parent_students ps
      join public.memberships m  on m.user_id = ps.student_id
      join public.schools s      on s.id = m.school_id
      join public.school_licenses l on l.school_id = s.id
     where ps.parent_id = v_uid
       and ((l.status = 'active'   and coalesce(l.current_period_end, v_now) > v_now)
         or (l.status = 'trialing' and coalesce(l.trial_ends_at, v_now) > v_now))
     order by l.current_period_end desc nulls last
     limit 1;

    if found then
      return jsonb_build_object(
        'status',          case when v_school.status = 'trialing'
                                then 'trialing' else 'entitled' end,
        'source',          'school_license',
        'role',            v_role,
        'school_id',       v_school.school_id,
        'school_name',     v_school.school_name,
        'tier_id',         v_school.tier_id,
        'license_status',  v_school.status,
        'valid_until',     case when v_school.status = 'trialing'
                                then v_school.trial_ends_at
                                else v_school.current_period_end end,
        'children_linked', v_children
      );
    end if;

    v_until := null;
    select * into v_sub
      from public.parent_subscriptions
     where parent_id = v_uid
       and status in ('active', 'past_due')
     order by current_period_end desc
     limit 1;

    if found then
      v_until := v_sub.current_period_end;
      if v_until > v_now then
        return jsonb_build_object(
          'status',           'entitled',
          'source',           'parent_subscription',
          'role',             v_role,
          'plan_id',          v_sub.plan_id,
          'children_covered', v_sub.children_covered,
          'valid_until',      v_until,
          'children_linked',  v_children
        );
      end if;
    end if;

    return jsonb_build_object(
      'status',          case when v_children = 0 then 'needs_setup'
                              else 'needs_payment' end,
      'source',          'none',
      'role',            v_role,
      'children_linked', v_children,
      'valid_until',     v_until
    );
  end if;

  -- ---- Student: their school's licence, else a parent's subscription ----
  select s.id as school_id, s.name as school_name, l.tier_id,
         l.status, l.trial_ends_at, l.current_period_end
    into v_school
    from public.memberships m
    join public.schools s         on s.id = m.school_id
    join public.school_licenses l on l.school_id = s.id
   where m.user_id = v_uid
     and ((l.status = 'active'   and coalesce(l.current_period_end, v_now) > v_now)
       or (l.status = 'trialing' and coalesce(l.trial_ends_at, v_now) > v_now))
   order by l.current_period_end desc nulls last
   limit 1;

  if found then
    return jsonb_build_object(
      'status',         case when v_school.status = 'trialing'
                             then 'trialing' else 'entitled' end,
      'source',         'school_license',
      'role',           v_role,
      'school_id',      v_school.school_id,
      'school_name',    v_school.school_name,
      'tier_id',        v_school.tier_id,
      'license_status', v_school.status,
      'valid_until',    case when v_school.status = 'trialing'
                             then v_school.trial_ends_at
                             else v_school.current_period_end end,
      'children_linked', 0
    );
  end if;

  select ps.parent_id, sub.plan_id, sub.children_covered,
         sub.current_period_end
    into v_sub
    from public.parent_students ps
    join public.parent_subscriptions sub on sub.parent_id = ps.parent_id
   where ps.student_id = v_uid
     and sub.status in ('active', 'past_due')
     and sub.current_period_end > v_now
   order by sub.current_period_end desc
   limit 1;

  if found then
    return jsonb_build_object(
      'status',          'entitled',
      'source',          'parent_subscription',
      'role',            v_role,
      'plan_id',         v_sub.plan_id,
      'valid_until',     v_sub.current_period_end,
      'children_linked', 0
    );
  end if;

  -- Enrolled-but-lapsed is not the same as never-joined.
  select s.id as school_id, s.name as school_name, l.tier_id,
         l.status, l.trial_ends_at, l.current_period_end
    into v_school
    from public.memberships m
    join public.schools s         on s.id = m.school_id
    join public.school_licenses l on l.school_id = s.id
   where m.user_id = v_uid
   order by coalesce(l.current_period_end, l.trial_ends_at) desc nulls last
   limit 1;

  if found then
    return jsonb_build_object(
      'status',         'needs_payment',
      'source',         'school_license',
      'role',           v_role,
      'school_id',      v_school.school_id,
      'school_name',    v_school.school_name,
      'tier_id',        v_school.tier_id,
      'license_status', v_school.status,
      'valid_until',    coalesce(v_school.current_period_end,
                                 v_school.trial_ends_at),
      'children_linked', 0
    );
  end if;

  return jsonb_build_object('status', 'needs_setup', 'source', 'none',
                            'role', v_role, 'children_linked', 0);
end;
$$;

-- Seats stay student-only. A teacher is added by redeeming a code (through the
-- definer function above), never by inserting their own membership.
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

-- A teacher may add classes to the school that employs them.
drop policy if exists classes_insert_self on public.classes;
create policy classes_insert_self on public.classes
  for insert to authenticated with check (
    created_by = auth.uid()
    and (public.is_my_school(school_id) or public.is_teacher_at(school_id))
  );

drop policy if exists classes_update_own on public.classes;
create policy classes_update_own on public.classes
  for update to authenticated using (
    public.is_my_school(school_id) or public.is_teacher_at(school_id)
  )
  with check (
    public.is_my_school(school_id) or public.is_teacher_at(school_id)
  );

-- Teachers read their school's roster and their students' names.
drop policy if exists memberships_select_teacher on public.memberships;
create policy memberships_select_teacher on public.memberships
  for select to authenticated using (public.is_teacher_at(school_id));

drop policy if exists profiles_select_teacher on public.profiles;
create policy profiles_select_teacher on public.profiles
  for select to authenticated using (
    exists (
      select 1 from public.memberships m
       where m.user_id = public.profiles.id
         and public.is_teacher_at(m.school_id)
    )
  );

-- Teachers see the invites they created (the parent codes they hand out);
-- 0003's policy already covers `created_by = auth.uid()`.

grant execute on function public.is_teacher_at(uuid)              to authenticated;
grant execute on function public.my_teaching_school_id()          to authenticated;
grant execute on function public.may_view_class(uuid)             to authenticated;
grant execute on function public.invite_teacher(text)             to authenticated;
grant execute on function public.teacher_classes()                to authenticated;
grant execute on function public.class_progress(uuid, integer)    to authenticated;
