-- Optional sample data so the schools list isn't empty on first run.
-- Run AFTER 0001_schools.sql. created_by is left null (system-seeded).

insert into public.schools (id, name, description, join_code, created_by)
values
  ('11111111-1111-1111-1111-111111111111',
   'Kigali Modern Academy',
   'A demo school for exploring EduAI.',
   'KMA24', null),
  ('22222222-2222-2222-2222-222222222222',
   'Green Hills Secondary',
   'Science & technology focused demo school.',
   'GHS24', null)
on conflict (id) do nothing;

insert into public.classes (id, school_id, name, grade, join_code, created_by)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '11111111-1111-1111-1111-111111111111',
   'Primary 5 — Mathematics', 'P5', 'MATH5', null),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   '11111111-1111-1111-1111-111111111111',
   'Primary 6 — English', 'P6', 'ENG6', null),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc',
   '22222222-2222-2222-2222-222222222222',
   'Senior 1 — Physics', 'S1', 'PHY1', null)
on conflict (id) do nothing;
