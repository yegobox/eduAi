-- EduAI — enrolment requires a join code
-- Run AFTER 0006. Safe to re-run.
--
-- Until now `may_enrol` let a student insert a membership into *any* school by
-- id. The catalog is world-readable to signed-in users, so anybody could browse
-- to a school they had nothing to do with and enrol — consuming one of that
-- school's seats and raising its next invoice. Nothing about that was
-- deliberate; it fell out of the schools catalog being a browse-and-join list
-- before there was anything to bill.
--
-- Enrolment now needs the code a teacher hands out, which is how the product
-- describes it anyway ("enter the code your teacher gave you").
--
-- Joining a *second class inside a school you already belong to* stays a direct
-- insert: it adds no seat (seats count distinct students) and it is how a
-- student picks up another subject.

-- ─────────────────────────────────────────────────────────────────────────
-- Enrol with a code
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.enrol_by_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_code   text := upper(trim(coalesce(p_code, '')));
  v_school public.schools;
  v_class  public.classes;
  v_id     uuid;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;
  if v_code = '' then
    raise exception 'enter a join code';
  end if;
  -- Only students take seats. A director or a teacher reaching this would be
  -- enrolling themselves as a pupil in their own school.
  if public.my_role() <> 'student' then
    raise exception
      'only a student account enrols with a class code';
  end if;

  -- A class code first: it is the specific thing a teacher hands out, and it
  -- also establishes the school.
  select * into v_class from public.classes where join_code = v_code;
  if found then
    insert into public.memberships (user_id, school_id, class_id, role)
    values (v_uid, v_class.school_id, v_class.id, 'student')
    on conflict do nothing
    returning id into v_id;

    return jsonb_build_object(
      'school_id', v_class.school_id,
      'class_id',  v_class.id,
      'class_name', v_class.name,
      'already_enrolled', v_id is null
    );
  end if;

  select * into v_school from public.schools where join_code = v_code;
  if found then
    insert into public.memberships (user_id, school_id, class_id, role)
    values (v_uid, v_school.id, null, 'student')
    on conflict do nothing
    returning id into v_id;

    return jsonb_build_object(
      'school_id', v_school.id,
      'school_name', v_school.name,
      'already_enrolled', v_id is null
    );
  end if;

  raise exception 'no school or class matches that code';
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Direct inserts no longer open a new school
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
           -- A student may add themselves to another class of a school they are
           -- already in — no new seat, and no need for a second code. Getting
           -- *into* a school in the first place goes through enrol_by_code.
           when 'student' then p_role = 'student' and exists (
             select 1 from public.memberships m
              where m.user_id = auth.uid() and m.school_id = p_school_id
           )
           when 'school_admin' then p_role in ('owner', 'teacher')
                                     and public.is_my_school(p_school_id)
           else false
         end;
$$;

grant execute on function public.enrol_by_code(text) to authenticated;
