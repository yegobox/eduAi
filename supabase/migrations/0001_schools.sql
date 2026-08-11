-- EduAI — schools, classes & memberships
-- Run this in the Supabase SQL editor (or `supabase db push`).
-- Safe to re-run: guards with "if not exists" / "drop policy if exists".

-- ─────────────────────────────────────────────────────────────────────────
-- Tables
-- ─────────────────────────────────────────────────────────────────────────

create table if not exists public.schools (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  -- Optional short code students can type to join without browsing.
  join_code   text unique,
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.classes (
  id          uuid primary key default gen_random_uuid(),
  school_id   uuid not null references public.schools (id) on delete cascade,
  name        text not null,
  grade       text,
  join_code   text unique,
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now()
);

-- A user's enrollment. class_id null == joined the school but no class yet.
create table if not exists public.memberships (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  school_id  uuid not null references public.schools (id) on delete cascade,
  class_id   uuid references public.classes (id) on delete cascade,
  role       text not null default 'student'
             check (role in ('student', 'teacher', 'owner')),
  created_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────
-- Indexes & uniqueness
-- ─────────────────────────────────────────────────────────────────────────

create index if not exists classes_school_id_idx on public.classes (school_id);
create index if not exists memberships_user_id_idx on public.memberships (user_id);
create index if not exists memberships_school_id_idx on public.memberships (school_id);

-- One school-level membership per user (class_id is null).
create unique index if not exists memberships_unique_school
  on public.memberships (user_id, school_id)
  where class_id is null;

-- One membership per user per class.
create unique index if not exists memberships_unique_class
  on public.memberships (user_id, class_id)
  where class_id is not null;

-- ─────────────────────────────────────────────────────────────────────────
-- Row Level Security
-- The publishable/anon key is only safe because these policies gate every row.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.schools     enable row level security;
alter table public.classes     enable row level security;
alter table public.memberships enable row level security;

-- Schools: any signed-in user can browse the catalog; creators own their rows.
drop policy if exists schools_select        on public.schools;
drop policy if exists schools_insert_self   on public.schools;
drop policy if exists schools_update_own    on public.schools;
drop policy if exists schools_delete_own    on public.schools;

create policy schools_select on public.schools
  for select to authenticated using (true);
create policy schools_insert_self on public.schools
  for insert to authenticated with check (created_by = auth.uid());
create policy schools_update_own on public.schools
  for update to authenticated using (created_by = auth.uid())
  with check (created_by = auth.uid());
create policy schools_delete_own on public.schools
  for delete to authenticated using (created_by = auth.uid());

-- Classes: readable by any signed-in user; creators own their rows.
-- (Production: tighten inserts to school owners/teachers.)
drop policy if exists classes_select      on public.classes;
drop policy if exists classes_insert_self on public.classes;
drop policy if exists classes_update_own  on public.classes;
drop policy if exists classes_delete_own  on public.classes;

create policy classes_select on public.classes
  for select to authenticated using (true);
create policy classes_insert_self on public.classes
  for insert to authenticated with check (created_by = auth.uid());
create policy classes_update_own on public.classes
  for update to authenticated using (created_by = auth.uid())
  with check (created_by = auth.uid());
create policy classes_delete_own on public.classes
  for delete to authenticated using (created_by = auth.uid());

-- Memberships: a user only ever sees / creates / removes their OWN rows.
drop policy if exists memberships_select_own on public.memberships;
drop policy if exists memberships_insert_self on public.memberships;
drop policy if exists memberships_delete_self on public.memberships;

create policy memberships_select_own on public.memberships
  for select to authenticated using (user_id = auth.uid());
create policy memberships_insert_self on public.memberships
  for insert to authenticated with check (user_id = auth.uid());
create policy memberships_delete_self on public.memberships
  for delete to authenticated using (user_id = auth.uid());
