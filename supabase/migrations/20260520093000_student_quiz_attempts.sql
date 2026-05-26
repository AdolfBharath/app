create table if not exists public.student_quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null,
  course_id uuid not null,
  score integer not null default 0,
  total integer not null default 0,
  pass_score integer not null default 0,
  passed boolean not null default false,
  attempt_number integer not null default 1,
  created_at timestamptz not null default now()
);

create index if not exists student_quiz_attempts_student_id_idx
on public.student_quiz_attempts (student_id);

create index if not exists student_quiz_attempts_course_id_idx
on public.student_quiz_attempts (course_id);

alter table public.student_course_progress
add column if not exists quiz_attempts integer not null default 0,
add column if not exists quiz_failed_attempts integer not null default 0,
add column if not exists quiz_locked boolean not null default false,
add column if not exists quiz_rewatch_required boolean not null default false,
add column if not exists quiz_last_score integer not null default 0,
add column if not exists quiz_last_total integer not null default 0,
add column if not exists quiz_best_score integer not null default 0;
