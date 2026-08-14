-- EduAI — a small real charge for testing, without faking the billing logic
-- Run AFTER 0004. Safe to re-run.
--
-- Testing a Mobile Money flow needs real money to move: MTN has to prompt a
-- real handset and settle a real reference. Paying a school's real licence
-- (7,500 RWF and up) to check a button is not viable, so this adds a
-- server-side price override for non-production projects.
--
-- Why it lives here and not in the client:
--
--   settle_school_license() and settle_parent_subscription() recompute the
--   amount from the quote functions and refuse anything short of it (recorded
--   as `disputed`). A client that simply paid 100 RWF would therefore have
--   every test payment rejected. Overriding the *quote* keeps the two sides
--   agreeing by construction — seats are still counted, tiers still validated,
--   references still idempotent, under-payment still refused. The only thing
--   that changes is the number of francs.
--
-- Two safety properties, because this is a switch that gives the product away
-- if it is ever left on in production:
--
--   1. Off unless explicitly enabled, and only by a service-role/SQL-editor
--      connection — `enable_test_pricing` refuses a signed-in client.
--   2. It **expires**. A forgotten override stops applying on its own rather
--      than quietly discounting a real school forever.

alter table public.billing_settings
  add column if not exists test_charge_amount_rwf integer,
  add column if not exists test_charge_until timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'billing_settings_test_amount_positive'
  ) then
    alter table public.billing_settings
      add constraint billing_settings_test_amount_positive
      check (test_charge_amount_rwf is null or test_charge_amount_rwf > 0);
  end if;
end $$;

-- The override in force right now, or null when normal pricing applies.
create or replace function public.test_charge_amount()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select s.test_charge_amount_rwf
    from public.billing_settings s
   where s.id
     and s.test_charge_amount_rwf is not null
     -- No expiry set means "not enabled": leaving this open-ended is the
     -- mistake the expiry exists to prevent.
     and s.test_charge_until is not null
     and s.test_charge_until > now();
$$;

-- Turns test pricing on for a bounded window. Service role / SQL editor only.
create or replace function public.enable_test_pricing(
  p_amount_rwf integer default 100,
  p_hours      integer default 24
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hours integer := greatest(least(coalesce(p_hours, 24), 24 * 30), 1);
begin
  if auth.uid() is not null then
    raise exception 'test pricing cannot be enabled by a signed-in client';
  end if;
  if coalesce(p_amount_rwf, 0) <= 0 then
    raise exception 'the test amount must be greater than zero';
  end if;

  update public.billing_settings
     set test_charge_amount_rwf = p_amount_rwf,
         test_charge_until      = now() + make_interval(hours => v_hours)
   where id;

  return jsonb_build_object(
    'test_charge_amount_rwf', p_amount_rwf,
    'expires_at', (select test_charge_until from public.billing_settings where id)
  );
end;
$$;

create or replace function public.disable_test_pricing()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    raise exception 'test pricing cannot be changed by a signed-in client';
  end if;
  update public.billing_settings
     set test_charge_amount_rwf = null, test_charge_until = null
   where id;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- Quotes honour the override
--
-- `amount_rwf` is what gets charged and what settlement checks. The real
-- figures stay in the response (`seats`, `price_per_seat_rwf`,
-- `full_amount_rwf`) so the app can show what this *would* have cost and make
-- it obvious that test pricing is on.
-- ─────────────────────────────────────────────────────────────────────────

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
  v_full   integer;
  v_test   integer := public.test_charge_amount();
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
  v_full  := v_seats * v_tier.price_per_seat_rwf;

  return jsonb_build_object(
    'school_id',          v_school,
    'tier_id',            v_tier.id,
    'tier_name',          v_tier.name,
    'seats',              v_seats,
    'seats_used',         v_used,
    'price_per_seat_rwf', v_tier.price_per_seat_rwf,
    'amount_rwf',         coalesce(v_test, v_full),
    'full_amount_rwf',    v_full,
    'test_mode',          v_test is not null,
    'period_days',        30
  );
end;
$$;

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
  v_full     integer;
  v_test     integer := public.test_charge_amount();
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
  v_full := v_children * v_plan.price_per_child_rwf;

  return jsonb_build_object(
    'plan_id',             v_plan.id,
    'plan_name',           v_plan.name,
    'children',            v_children,
    'price_per_child_rwf', v_plan.price_per_child_rwf,
    'amount_rwf',          coalesce(v_test, v_full),
    'full_amount_rwf',     v_full,
    'test_mode',           v_test is not null,
    'period_days',         v_plan.period_days
  );
end;
$$;

-- access_state() reports it too, so the app can warn on every billing screen
-- rather than only where a quote happens to be loaded.
create or replace function public.billing_test_mode()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.test_charge_amount() is not null;
$$;

grant execute on function public.test_charge_amount()   to authenticated;
grant execute on function public.billing_test_mode()    to authenticated;

-- Deliberately NOT granted to `authenticated`: enabling a discount is an
-- operator action, not something any signed-in account can reach.
revoke all on function public.enable_test_pricing(integer, integer) from public;
revoke all on function public.disable_test_pricing() from public;
