-- EduAI — identity, entitlement & billing
-- Run this in the Supabase SQL editor (or `supabase db push`) AFTER 0001/0002.
-- Safe to re-run: guards with "if not exists" / "drop policy if exists".
--
-- This migration is what makes the product sellable. Before it, every account
-- was a student, anybody could create a school for free, and nothing anywhere
-- checked whether money had changed hands. It introduces:
--
--   profiles            — the server-side role (student / parent / school_admin)
--   plan_tiers          — the school price list, server-authoritative
--   parent_plans        — the direct-to-parent price list
--   school_licenses     — one licence per school: trialing → active → expired
--   parent_subscriptions— a parent paying directly, with no school involved
--   parent_students     — the confirmed parent ↔ student link
--   invites             — the two ways that link gets created (school-side and
--                         parent-side), plus the code that redeems it
--   payments            — every Mobile Money reference, idempotent per ref
--
-- and one function the client trusts for access decisions: access_state().

-- ─────────────────────────────────────────────────────────────────────────
-- Price lists
--
-- Prices live server-side on purpose. If the client sent the amount, a
-- modified build could buy the District tier for 1 RWF. Every settle_*
-- function below recomputes the expected amount from these tables.
-- ─────────────────────────────────────────────────────────────────────────

create table if not exists public.plan_tiers (
  id                  text primary key,
  name                text not null,
  price_per_seat_rwf  integer not null check (price_per_seat_rwf > 0),
  max_seats           integer,
  seats_label         text not null,
  features            text[] not null default '{}',
  sort_order          integer not null default 0
);

insert into public.plan_tiers
  (id, name, price_per_seat_rwf, max_seats, seats_label, features, sort_order)
values
  ('starter', 'Starter', 900, 150, 'Up to 150 students',
   array['AI Tutor', 'Lessons library', 'Offline access'], 1),
  ('growth', 'Growth', 1500, 800, 'Up to 800 students',
   array['Everything in Starter', 'Stylus workbook', 'Parent reports'], 2),
  ('district', 'District', 1250, null, '800+ students',
   array['Everything in Growth', 'Multi-school admin', 'Dedicated support'], 3)
on conflict (id) do update
  set name               = excluded.name,
      price_per_seat_rwf = excluded.price_per_seat_rwf,
      max_seats          = excluded.max_seats,
      seats_label        = excluded.seats_label,
      features           = excluded.features,
      sort_order         = excluded.sort_order;

create table if not exists public.parent_plans (
  id                   text primary key,
  name                 text not null,
  price_per_child_rwf  integer not null check (price_per_child_rwf > 0),
  period_days          integer not null default 30,
  features             text[] not null default '{}',
  sort_order           integer not null default 0
);

insert into public.parent_plans
  (id, name, price_per_child_rwf, period_days, features, sort_order)
values
  ('family_monthly', 'Family — monthly', 3000, 30,
   array['AI Tutor', 'Lessons library', 'Stylus workbook', 'Weekly reports'], 1),
  ('family_termly', 'Family — one term', 7500, 90,
   array['Everything monthly', 'Save 17%', 'Covers a full school term'], 2)
on conflict (id) do update
  set name                = excluded.name,
      price_per_child_rwf = excluded.price_per_child_rwf,
      period_days         = excluded.period_days,
      features            = excluded.features,
      sort_order          = excluded.sort_order;

-- ─────────────────────────────────────────────────────────────────────────
-- Profiles — the one source of truth for an account's role
-- ─────────────────────────────────────────────────────────────────────────

create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  role         text not null default 'student'
               check (role in ('student', 'parent', 'school_admin')),
  display_name text,
  phone        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles (role);

-- ─────────────────────────────────────────────────────────────────────────
-- Licences & subscriptions
-- ─────────────────────────────────────────────────────────────────────────

-- One licence per school, created automatically by trigger the moment a
-- school row appears — so a school can never exist in an unknown billing
-- state. It starts on a trial; it does not start free forever.
create table if not exists public.school_licenses (
  school_id          uuid primary key
                     references public.schools (id) on delete cascade,
  tier_id            text not null default 'growth'
                     references public.plan_tiers (id),
  status             text not null default 'trialing'
                     check (status in ('trialing', 'active', 'past_due',
                                       'expired', 'canceled')),
  -- What the school has bought. Seats *used* is counted live from
  -- memberships, so the two can never silently disagree.
  seats_purchased    integer not null default 0 check (seats_purchased >= 0),
  price_per_seat_rwf integer not null default 1500,
  trial_ends_at      timestamptz,
  current_period_end timestamptz,
  activated_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- How generous the trial is. Kept here rather than in the client so it can be
-- changed without shipping an app update.
create table if not exists public.billing_settings (
  id               boolean primary key default true check (id),
  trial_days       integer not null default 30,
  trial_seat_cap   integer not null default 50,
  grace_days       integer not null default 7
);
insert into public.billing_settings (id) values (true) on conflict (id) do nothing;

-- A parent paying directly, with no school in the picture at all.
create table if not exists public.parent_subscriptions (
  id                  uuid primary key default gen_random_uuid(),
  parent_id           uuid not null references auth.users (id) on delete cascade,
  plan_id             text not null references public.parent_plans (id),
  status              text not null default 'active'
                      check (status in ('active', 'past_due', 'expired',
                                        'canceled')),
  children_covered    integer not null default 1 check (children_covered > 0),
  price_per_child_rwf integer not null,
  current_period_end  timestamptz not null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists parent_subscriptions_parent_idx
  on public.parent_subscriptions (parent_id);

-- At most one live subscription per parent; renewals extend it in place.
create unique index if not exists parent_subscriptions_one_live
  on public.parent_subscriptions (parent_id)
  where status in ('active', 'past_due');

-- ─────────────────────────────────────────────────────────────────────────
-- Parent ↔ student links, and the invites that create them
-- ─────────────────────────────────────────────────────────────────────────

-- The two foreign keys point at public.profiles rather than auth.users on
-- purpose: it lets a client read the other party's display name by embedding
-- (`profiles!parent_students_student_id_fkey`) in one query. profiles.id
-- cascades from auth.users, so deleting an account still clears the link.
create table if not exists public.parent_students (
  id         uuid primary key default gen_random_uuid(),
  parent_id  uuid not null references public.profiles (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  -- Who set the link up. Kept for support ("the school added me").
  source     text not null default 'parent'
             check (source in ('parent', 'school')),
  created_at timestamptz not null default now(),
  constraint parent_students_not_self check (parent_id <> student_id)
);

create unique index if not exists parent_students_unique
  on public.parent_students (parent_id, student_id);
create index if not exists parent_students_student_idx
  on public.parent_students (student_id);

-- Both linking directions, in one table:
--
--   kind='parent_of_student' — a school admin nominates a parent for one of
--     its enrolled students. student_id is set; the parent redeems the code.
--   kind='student_of_parent' — a parent invites their own child. parent_id is
--     set; the student redeems the code.
create table if not exists public.invites (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null
              check (kind in ('parent_of_student', 'student_of_parent')),
  code        text not null unique,
  school_id   uuid references public.schools (id) on delete cascade,
  student_id  uuid references auth.users (id) on delete cascade,
  parent_id   uuid references auth.users (id) on delete cascade,
  -- Phone or email the invite was addressed to, for the "pending" list. Not
  -- used for authorisation — the code is what authorises.
  contact     text,
  status      text not null default 'pending'
              check (status in ('pending', 'accepted', 'revoked', 'expired')),
  expires_at  timestamptz not null default (now() + interval '30 days'),
  created_by  uuid not null references auth.users (id) on delete cascade,
  accepted_by uuid references auth.users (id) on delete set null,
  accepted_at timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists invites_school_idx on public.invites (school_id);
create index if not exists invites_student_idx on public.invites (student_id);
create index if not exists invites_parent_idx on public.invites (parent_id);
create index if not exists invites_code_idx on public.invites (code);

-- ─────────────────────────────────────────────────────────────────────────
-- Payments
--
-- One row per Mobile Money request-to-pay. `reference` is MTN's id and is
-- unique, which is what makes crediting idempotent: replaying a settlement
-- can never grant a second period or a second set of sessions.
-- ─────────────────────────────────────────────────────────────────────────

create table if not exists public.payments (
  id               uuid primary key default gen_random_uuid(),
  reference        text not null unique,
  payer_id         uuid not null references auth.users (id) on delete cascade,
  purpose          text not null
                   check (purpose in ('school_license', 'parent_subscription',
                                      'tutor_topup')),
  amount_expected_rwf integer not null,
  amount_reported_rwf integer,
  status           text not null default 'pending'
                   check (status in ('pending', 'settled', 'disputed',
                                     'failed')),
  -- 'client' until a server-side job has confirmed the reference against the
  -- gateway. See the note on settle_school_license below.
  verified_by      text not null default 'client'
                   check (verified_by in ('client', 'gateway')),
  school_id        uuid references public.schools (id) on delete set null,
  subscription_id  uuid references public.parent_subscriptions (id)
                   on delete set null,
  metadata         jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now(),
  settled_at       timestamptz
);

create index if not exists payments_payer_idx on public.payments (payer_id);
create index if not exists payments_school_idx on public.payments (school_id);

-- ─────────────────────────────────────────────────────────────────────────
-- Triggers
-- ─────────────────────────────────────────────────────────────────────────

-- Validates a role requested in sign-up metadata against the allowlist.
--
-- Anything unrecognised (or absent) becomes a student, the least-privileged
-- option. Kept as one function because the trigger below and the backfill at
-- the bottom of this file must agree: a backfill that ignored the requested
-- role would silently demote every director who signed up before this
-- migration was applied.
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

-- A profile for every new auth user, with the role chosen at sign-up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, display_name, phone)
  values (
    new.id,
    public.role_from_metadata(new.raw_user_meta_data),
    nullif(trim(coalesce(new.raw_user_meta_data->>'display_name',
                         new.raw_user_meta_data->>'name', '')), ''),
    new.phone
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- A role is not something a client may rewrite. Escalating to school_admin
-- would not leak another school's data (RLS scopes every row by ownership),
-- but it would hand out the admin shell — and with it the billing surface —
-- to an account that never passed the paywall.
--
-- The guard is scoped to requests that carry an end-user JWT. A service-role
-- connection or the SQL editor has no auth.uid(), so support (and the backfill
-- at the bottom of this file) can still convert an account deliberately.
create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role and auth.uid() is not null then
    raise exception
      'role cannot be changed from the client; contact support to convert an account';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_protect_role on public.profiles;
create trigger profiles_protect_role
  before update on public.profiles
  for each row execute function public.protect_profile_role();

-- Every school gets a licence the instant it is created, on a trial. This is
-- the difference between "anyone can create a school for free, forever" and
-- "anyone can *try* EduAI for 30 days".
create or replace function public.start_school_trial()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings public.billing_settings;
  v_price    integer;
begin
  select * into v_settings from public.billing_settings where id;
  select price_per_seat_rwf into v_price
    from public.plan_tiers where id = 'growth';

  insert into public.school_licenses (
    school_id, tier_id, status, seats_purchased,
    price_per_seat_rwf, trial_ends_at
  )
  values (
    new.id, 'growth', 'trialing', 0,
    coalesce(v_price, 1500),
    now() + make_interval(days => coalesce(v_settings.trial_days, 30))
  )
  on conflict (school_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_school_created on public.schools;
create trigger on_school_created
  after insert on public.schools
  for each row execute function public.start_school_trial();

-- ─────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.my_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select role from public.profiles where id = auth.uid()),
                  'student');
$$;

-- The school the signed-in admin runs. A director owns exactly one school in
-- this model; the District tier's multi-school case takes the earliest.
create or replace function public.my_school_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.schools
   where created_by = auth.uid()
   order by created_at
   limit 1;
$$;

create or replace function public.is_my_school(p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.schools
     where id = p_school_id and created_by = auth.uid()
  );
$$;

-- Seats actually consumed: distinct students enrolled in the school. Counted
-- live rather than stored, so it cannot drift from the roster.
create or replace function public.school_seats_used(p_school_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(distinct m.user_id)::integer
    from public.memberships m
   where m.school_id = p_school_id
     and m.role = 'student';
$$;

-- A short, unambiguous invite code. Excludes the character pairs a parent
-- would misread off a printed slip (0/O, 1/I/L, 5/S, 8/B).
create or replace function public.new_invite_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alphabet text := 'ACDEFGHJKMNPQRTUVWXY234679';
  v_code     text;
  v_i        integer;
begin
  loop
    v_code := '';
    for v_i in 1..7 loop
      v_code := v_code ||
        substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.invites where code = v_code);
  end loop;
  return v_code;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- access_state() — the single question the client asks about entitlement
--
-- Returned as one JSON object so a screen needs exactly one round trip, and
-- so the decision is made server-side where the client cannot lean on it.
--
-- status: 'entitled'      — paid and current
--         'trialing'      — inside the trial window
--         'needs_payment' — was entitled, or wants to be, and must pay
--         'needs_setup'   — nothing to bill yet (no school / no child linked)
--         'unknown'       — not signed in
-- ─────────────────────────────────────────────────────────────────────────

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

  -- ---- Parent: covered if any child's school pays, or they pay ----------
  if v_role = 'parent' then
    select count(*)::integer into v_children
      from public.parent_students where parent_id = v_uid;

    -- A school licence covering any linked child means the parent owes
    -- nothing. This is checked before their own subscription so a parent is
    -- never asked to pay for access the school already bought.
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
      -- Kept even when it has lapsed: "your plan ended on <date>" is a far
      -- better prompt to renew than a bare paywall.
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

  -- Nothing covers this student right now. Enrolled-but-lapsed is a different
  -- situation from never-joined, and must not be reported as the same thing: a
  -- student already in a school does not need to "join a school", they need
  -- their school's invoice paid. Telling them otherwise sends them off to
  -- re-enter a join code that will change nothing.
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

  -- No school at all, and no paying parent. This student is not a customer
  -- yet — the app asks them to join a school or have a parent subscribe.
  return jsonb_build_object('status', 'needs_setup', 'source', 'none',
                            'role', v_role, 'children_linked', 0);
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Licence management (school admin)
-- ─────────────────────────────────────────────────────────────────────────

-- Pick a tier. Effective immediately for pricing; it does not itself pay.
create or replace function public.select_school_tier(p_tier_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_school uuid := public.my_school_id();
  v_tier   public.plan_tiers;
begin
  if v_school is null then
    raise exception 'no school for this account';
  end if;
  select * into v_tier from public.plan_tiers where id = p_tier_id;
  if not found then
    raise exception 'unknown plan tier %', p_tier_id;
  end if;

  update public.school_licenses
     set tier_id            = v_tier.id,
         price_per_seat_rwf = v_tier.price_per_seat_rwf,
         updated_at         = now()
   where school_id = v_school;

  return public.access_state();
end;
$$;

create or replace function public.set_seats_purchased(p_seats integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_school uuid := public.my_school_id();
  v_tier   public.plan_tiers;
  v_seats  integer := greatest(coalesce(p_seats, 0), 0);
begin
  if v_school is null then
    raise exception 'no school for this account';
  end if;

  select t.* into v_tier
    from public.school_licenses l
    join public.plan_tiers t on t.id = l.tier_id
   where l.school_id = v_school;

  if v_tier.max_seats is not null and v_seats > v_tier.max_seats then
    raise exception 'the % tier covers at most % students', v_tier.name,
                    v_tier.max_seats;
  end if;

  update public.school_licenses
     set seats_purchased = v_seats, updated_at = now()
   where school_id = v_school;

  return public.access_state();
end;
$$;

-- What the school owes right now, computed server-side. The client shows this
-- and then pays exactly it — it never proposes its own amount.
create or replace function public.school_license_quote(p_seats integer default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_school uuid := public.my_school_id();
  v_lic    public.school_licenses;
  v_tier   public.plan_tiers;
  v_used   integer;
  v_seats  integer;
begin
  if v_school is null then
    raise exception 'no school for this account';
  end if;

  select * into v_lic  from public.school_licenses where school_id = v_school;
  select * into v_tier from public.plan_tiers where id = v_lic.tier_id;
  v_used  := public.school_seats_used(v_school);
  -- Bill on the larger of seats bought and seats actually in use: a school
  -- cannot enrol 300 students against 50 purchased seats and pay for 50.
  v_seats := greatest(coalesce(p_seats, v_lic.seats_purchased), v_used, 1);

  return jsonb_build_object(
    'school_id',          v_school,
    'tier_id',            v_tier.id,
    'tier_name',          v_tier.name,
    'seats',              v_seats,
    'seats_used',         v_used,
    'price_per_seat_rwf', v_tier.price_per_seat_rwf,
    'amount_rwf',         v_seats * v_tier.price_per_seat_rwf,
    'period_days',        30
  );
end;
$$;

-- Records a Mobile Money settlement against the school licence and activates
-- it for one period. Idempotent per [p_reference]: replaying the same MTN
-- reference returns the current state without granting a second period.
--
-- TRUST NOTE. The reference and amount arrive from the client, which has
-- already polled MTN. That is enough to stop an *accidental* double-credit
-- and enough to catch a client that under-reports the amount, but it is not
-- proof of payment: a modified build could invent a reference. Closing that
-- hole needs a server-side confirmation — the data-connector calling
-- `requesttopay/status/{reference}` itself and flipping verified_by to
-- 'gateway'. Until that job exists, rows stay verified_by='client' and are
-- reconcilable against the MTN statement.
create or replace function public.settle_school_license(
  p_reference       text,
  p_amount_reported integer,
  p_seats           integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_quote  jsonb;
  v_school uuid;
  v_amount integer;
  v_days   integer;
  v_exist  public.payments;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;
  if coalesce(trim(p_reference), '') = '' then
    raise exception 'a payment reference is required';
  end if;

  select * into v_exist from public.payments where reference = p_reference;
  if found then
    -- Already recorded. Do not extend the period again.
    return public.access_state();
  end if;

  v_quote  := public.school_license_quote(p_seats);
  v_school := (v_quote->>'school_id')::uuid;
  v_amount := (v_quote->>'amount_rwf')::integer;
  v_days   := (v_quote->>'period_days')::integer;

  -- Under-reported settlement: record it, activate nothing, let support look.
  if coalesce(p_amount_reported, 0) < v_amount then
    insert into public.payments (
      reference, payer_id, purpose, amount_expected_rwf,
      amount_reported_rwf, status, school_id, metadata
    ) values (
      p_reference, v_uid, 'school_license', v_amount,
      p_amount_reported, 'disputed', v_school, v_quote
    );
    return public.access_state();
  end if;

  insert into public.payments (
    reference, payer_id, purpose, amount_expected_rwf,
    amount_reported_rwf, status, school_id, metadata, settled_at
  ) values (
    p_reference, v_uid, 'school_license', v_amount,
    p_amount_reported, 'settled', v_school, v_quote, now()
  );

  update public.school_licenses
     set status             = 'active',
         seats_purchased    = (v_quote->>'seats')::integer,
         -- Renewing early adds a period rather than losing the remainder.
         current_period_end = greatest(coalesce(current_period_end, now()),
                                       now()) + make_interval(days => v_days),
         activated_at       = coalesce(activated_at, now()),
         updated_at         = now()
   where school_id = v_school;

  return public.access_state();
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Parent subscription
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.parent_plan_quote(
  p_plan_id  text,
  p_children integer default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid      uuid := auth.uid();
  v_plan     public.parent_plans;
  v_children integer;
begin
  select * into v_plan from public.parent_plans where id = p_plan_id;
  if not found then
    raise exception 'unknown plan %', p_plan_id;
  end if;

  -- Default to the number of children actually linked, minimum one, so the
  -- price on screen matches this family rather than a generic figure.
  select greatest(coalesce(p_children,
                           (select count(*)::integer from public.parent_students
                             where parent_id = v_uid)), 1)
    into v_children;

  return jsonb_build_object(
    'plan_id',             v_plan.id,
    'plan_name',           v_plan.name,
    'children',            v_children,
    'price_per_child_rwf', v_plan.price_per_child_rwf,
    'amount_rwf',          v_children * v_plan.price_per_child_rwf,
    'period_days',         v_plan.period_days
  );
end;
$$;

-- Same idempotency and trust caveats as settle_school_license.
create or replace function public.settle_parent_subscription(
  p_reference       text,
  p_plan_id         text,
  p_amount_reported integer,
  p_children        integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_quote  jsonb;
  v_amount integer;
  v_days   integer;
  v_kids   integer;
  v_sub    public.parent_subscriptions;
  v_exist  public.payments;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;
  if coalesce(trim(p_reference), '') = '' then
    raise exception 'a payment reference is required';
  end if;

  select * into v_exist from public.payments where reference = p_reference;
  if found then
    return public.access_state();
  end if;

  v_quote  := public.parent_plan_quote(p_plan_id, p_children);
  v_amount := (v_quote->>'amount_rwf')::integer;
  v_days   := (v_quote->>'period_days')::integer;
  v_kids   := (v_quote->>'children')::integer;

  if coalesce(p_amount_reported, 0) < v_amount then
    insert into public.payments (
      reference, payer_id, purpose, amount_expected_rwf,
      amount_reported_rwf, status, metadata
    ) values (
      p_reference, v_uid, 'parent_subscription', v_amount,
      p_amount_reported, 'disputed', v_quote
    );
    return public.access_state();
  end if;

  select * into v_sub
    from public.parent_subscriptions
   where parent_id = v_uid and status in ('active', 'past_due')
   limit 1;

  if found then
    update public.parent_subscriptions
       set plan_id             = p_plan_id,
           status              = 'active',
           children_covered    = greatest(children_covered, v_kids),
           price_per_child_rwf = (v_quote->>'price_per_child_rwf')::integer,
           current_period_end  = greatest(current_period_end, now())
                                 + make_interval(days => v_days),
           updated_at          = now()
     where id = v_sub.id;
  else
    insert into public.parent_subscriptions (
      parent_id, plan_id, status, children_covered,
      price_per_child_rwf, current_period_end
    ) values (
      v_uid, p_plan_id, 'active', v_kids,
      (v_quote->>'price_per_child_rwf')::integer,
      now() + make_interval(days => v_days)
    )
    returning * into v_sub;
  end if;

  insert into public.payments (
    reference, payer_id, purpose, amount_expected_rwf,
    amount_reported_rwf, status, subscription_id, metadata, settled_at
  ) values (
    p_reference, v_uid, 'parent_subscription', v_amount,
    p_amount_reported, 'settled', v_sub.id, v_quote, now()
  );

  return public.access_state();
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Invites — the two linking directions
-- ─────────────────────────────────────────────────────────────────────────

-- School side: an admin nominates a parent for one of its enrolled students.
-- Returns the code the school reads out (or texts) to the parent.
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
  v_school uuid := public.my_school_id();
  v_code   text;
  v_id     uuid;
begin
  if public.my_role() <> 'school_admin' or v_school is null then
    raise exception 'only a school admin can invite a parent';
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

-- Parent side: a parent creates a code for their own child to type in.
create or replace function public.invite_child(p_contact text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_id   uuid;
begin
  if public.my_role() <> 'parent' then
    raise exception 'only a parent account can invite a child';
  end if;

  v_code := public.new_invite_code();
  insert into public.invites (kind, code, parent_id, contact, created_by)
  values ('student_of_parent', v_code, auth.uid(),
          nullif(trim(coalesce(p_contact, '')), ''), auth.uid())
  returning id into v_id;

  return jsonb_build_object('id', v_id, 'code', v_code,
                            'kind', 'student_of_parent');
end;
$$;

-- Redeems either kind of code. The signed-in account supplies whichever side
-- of the link the invite is missing, which is what makes one function enough.
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

-- The admin's people list: every enrolled student, their class, and whether a
-- parent is linked or still pending. One call rather than N+1 from the client.
create or replace function public.school_roster()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_school uuid := public.my_school_id();
  v_rows   jsonb;
begin
  if v_school is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(entry order by student_name), '[]'::jsonb)
    into v_rows
    from (
      select jsonb_build_object(
               'student_id',   m.user_id,
               'student_name', coalesce(p.display_name, 'Student'),
               'class_id',     m.class_id,
               'class_name',   c.name,
               'parents_linked', (
                 select count(*)::integer from public.parent_students ps
                  where ps.student_id = m.user_id),
               'invite_pending', exists (
                 select 1 from public.invites i
                  where i.student_id = m.user_id
                    and i.kind = 'parent_of_student'
                    and i.status = 'pending'
                    and i.expires_at > now())
             ) as entry,
             coalesce(p.display_name, 'Student') as student_name
        from public.memberships m
        left join public.profiles p on p.id = m.user_id
        left join public.classes  c on c.id = m.class_id
       where m.school_id = v_school
         and m.role = 'student'
    ) t;

  return v_rows;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Row Level Security
-- ─────────────────────────────────────────────────────────────────────────

alter table public.plan_tiers           enable row level security;
alter table public.parent_plans         enable row level security;
alter table public.profiles             enable row level security;
alter table public.school_licenses      enable row level security;
alter table public.billing_settings     enable row level security;
alter table public.parent_subscriptions enable row level security;
alter table public.parent_students      enable row level security;
alter table public.invites              enable row level security;
alter table public.payments             enable row level security;

-- Price lists are public reading; only the service role writes them.
drop policy if exists plan_tiers_select   on public.plan_tiers;
drop policy if exists parent_plans_select on public.parent_plans;
drop policy if exists billing_settings_select on public.billing_settings;
create policy plan_tiers_select on public.plan_tiers
  for select to authenticated using (true);
create policy parent_plans_select on public.parent_plans
  for select to authenticated using (true);
create policy billing_settings_select on public.billing_settings
  for select to authenticated using (true);

-- Profiles: read your own; a school admin reads the profiles of students
-- enrolled in their school (that is the roster). Role changes are blocked by
-- the trigger above, so update is safe to allow for the display fields.
drop policy if exists profiles_select_own   on public.profiles;
drop policy if exists profiles_select_roster on public.profiles;
drop policy if exists profiles_update_own   on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_select_roster on public.profiles
  for select to authenticated using (
    exists (
      select 1
        from public.memberships m
        join public.schools s on s.id = m.school_id
       where m.user_id = public.profiles.id
         and s.created_by = auth.uid()
    )
  );
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid())
  with check (id = auth.uid());

-- Licences: the owning admin reads their own. Writes go through the
-- security-definer functions only, so there is no insert/update policy —
-- a client cannot set status='active' by itself.
drop policy if exists school_licenses_select_own on public.school_licenses;
create policy school_licenses_select_own on public.school_licenses
  for select to authenticated using (public.is_my_school(school_id));

-- Subscriptions and payments: readable by the payer, written only by the
-- settle_* functions.
drop policy if exists parent_subscriptions_select_own on public.parent_subscriptions;
create policy parent_subscriptions_select_own on public.parent_subscriptions
  for select to authenticated using (parent_id = auth.uid());

drop policy if exists payments_select_own on public.payments;
create policy payments_select_own on public.payments
  for select to authenticated using (
    payer_id = auth.uid() or public.is_my_school(school_id)
  );

-- Parent ↔ student links: visible to both sides. Created only by
-- redeem_invite, and removable by the parent (unlinking a child).
drop policy if exists parent_students_select on public.parent_students;
drop policy if exists parent_students_delete on public.parent_students;
create policy parent_students_select on public.parent_students
  for select to authenticated using (
    parent_id = auth.uid() or student_id = auth.uid()
  );
create policy parent_students_delete on public.parent_students
  for delete to authenticated using (parent_id = auth.uid());

-- Invites: the creator sees and can revoke theirs. Redeeming happens through
-- redeem_invite, which is why there is deliberately no broad select policy —
-- a code must not be discoverable by listing the table.
drop policy if exists invites_select_own on public.invites;
drop policy if exists invites_update_own on public.invites;
create policy invites_select_own on public.invites
  for select to authenticated using (
    created_by = auth.uid()
    or parent_id = auth.uid()
    or (school_id is not null and public.is_my_school(school_id))
  );
create policy invites_update_own on public.invites
  for update to authenticated using (created_by = auth.uid())
  with check (created_by = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- Tighten 0001: creating a school is now a school-admin action
--
-- 0001 let any authenticated user insert a school, which is exactly the
-- "anyone can create a school without a subscription" hole. Creation is now
-- limited to school-admin identities, and the trial trigger above puts every
-- new school straight onto a clock.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists schools_insert_self on public.schools;
create policy schools_insert_self on public.schools
  for insert to authenticated with check (
    created_by = auth.uid() and public.my_role() = 'school_admin'
  );

-- Classes belong to the school's own admin, not to whoever asks first.
drop policy if exists classes_insert_self on public.classes;
create policy classes_insert_self on public.classes
  for insert to authenticated with check (
    created_by = auth.uid() and public.is_my_school(school_id)
  );

drop policy if exists classes_update_own on public.classes;
create policy classes_update_own on public.classes
  for update to authenticated using (public.is_my_school(school_id))
  with check (public.is_my_school(school_id));

drop policy if exists classes_delete_own on public.classes;
create policy classes_delete_own on public.classes
  for delete to authenticated using (public.is_my_school(school_id));

-- Memberships: a school admin also needs to read their own school's roster
-- (0001 restricted select to the member themselves).
drop policy if exists memberships_select_school_admin on public.memberships;
create policy memberships_select_school_admin on public.memberships
  for select to authenticated using (public.is_my_school(school_id));

-- ─────────────────────────────────────────────────────────────────────────
-- Backfill, so an existing database is consistent after this migration
-- ─────────────────────────────────────────────────────────────────────────

-- Honour the role each account asked for at sign-up. Hardcoding 'student' here
-- would demote every parent and director who signed up before this migration
-- ran — and the protect-role trigger would then stop them fixing it from the
-- app, which reads as "the app forgot who I am".
insert into public.profiles (id, role, display_name, phone)
select u.id,
       public.role_from_metadata(u.raw_user_meta_data),
       nullif(trim(coalesce(u.raw_user_meta_data->>'display_name',
                            u.raw_user_meta_data->>'name', '')), ''),
       u.phone
  from auth.users u
on conflict (id) do nothing;

-- Every pre-existing school gets a trial licence rather than silently
-- becoming free forever.
insert into public.school_licenses (
  school_id, tier_id, status, seats_purchased, price_per_seat_rwf, trial_ends_at
)
select s.id, 'growth', 'trialing', 0,
       (select price_per_seat_rwf from public.plan_tiers where id = 'growth'),
       now() + interval '30 days'
  from public.schools s
on conflict (school_id) do nothing;

-- Whoever created a school is, by definition, its admin.
update public.profiles p
   set role = 'school_admin'
 where p.role = 'student'
   and exists (select 1 from public.schools s where s.created_by = p.id);

-- ─────────────────────────────────────────────────────────────────────────
-- Grants — every function above is security definer, so it must be callable
-- ─────────────────────────────────────────────────────────────────────────

grant execute on function public.access_state()                   to authenticated;
grant execute on function public.my_role()                        to authenticated;
grant execute on function public.my_school_id()                   to authenticated;
grant execute on function public.is_my_school(uuid)               to authenticated;
grant execute on function public.school_seats_used(uuid)          to authenticated;
grant execute on function public.select_school_tier(text)         to authenticated;
grant execute on function public.set_seats_purchased(integer)     to authenticated;
grant execute on function public.school_license_quote(integer)    to authenticated;
grant execute on function public.settle_school_license(text, integer, integer)
  to authenticated;
grant execute on function public.parent_plan_quote(text, integer) to authenticated;
grant execute on function public.settle_parent_subscription(text, text, integer, integer)
  to authenticated;
grant execute on function public.invite_parent(uuid, text)        to authenticated;
grant execute on function public.invite_child(text)               to authenticated;
grant execute on function public.redeem_invite(text)              to authenticated;
grant execute on function public.school_roster()                  to authenticated;
