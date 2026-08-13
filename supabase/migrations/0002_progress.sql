-- EduAI — learning progress
-- Run this in the Supabase SQL editor (or `supabase db push`).
-- Safe to re-run: guards with "if not exists" / "drop policy if exists".

-- ─────────────────────────────────────────────────────────────────────────
-- Tables
-- ─────────────────────────────────────────────────────────────────────────

-- One append-only row per learning action. Every progress signal the app
-- shows (accuracy, activity, streaks, topics) is derived from this table, so
-- adding a signal later means reading these rows differently rather than
-- migrating a summary table that could drift out of sync.
--
--   kind='question' — the user asked the tutor something. is_correct is null.
--   kind='check'    — the user answered a concept check. is_correct is set.
create table if not exists public.learning_events (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('question', 'check')),
  -- Tutor context at the time of the event; all optional because the user
  -- can chat without ever setting a subject or level.
  subject    text,
  level      text,
  -- What was being studied: the subject when set, else a short form of the
  -- question. Drives "topics covered".
  topic      text,
  -- Only meaningful for kind='check'.
  is_correct boolean,
  created_at timestamptz not null default now(),

  constraint learning_events_correctness check (
    (kind = 'check' and is_correct is not null) or
    (kind <> 'check' and is_correct is null)
  )
);

-- ─────────────────────────────────────────────────────────────────────────
-- Indexes
-- ─────────────────────────────────────────────────────────────────────────

-- The only read pattern: "my events, newest first, within a window".
create index if not exists learning_events_user_created_idx
  on public.learning_events (user_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────
-- Row Level Security
-- The publishable/anon key is only safe because these policies gate every row.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.learning_events enable row level security;

-- A user only ever sees / writes their OWN rows. Progress is append-only from
-- the client: no update or delete policy is granted, so history can't be
-- rewritten to inflate a streak or scrub a wrong answer.
drop policy if exists learning_events_select_own on public.learning_events;
drop policy if exists learning_events_insert_self on public.learning_events;

create policy learning_events_select_own on public.learning_events
  for select to authenticated using (user_id = auth.uid());
create policy learning_events_insert_self on public.learning_events
  for insert to authenticated with check (user_id = auth.uid());
