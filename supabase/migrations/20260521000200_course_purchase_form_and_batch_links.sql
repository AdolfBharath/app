alter table public.courses
add column if not exists google_form_url text;

create table if not exists public.student_batches (
  student_id uuid not null,
  batch_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (student_id, batch_id)
);

create table if not exists public.student_course_marks (
  student_id uuid not null,
  course_id uuid not null,
  extra_marks integer not null default 0,
  note text,
  updated_at timestamptz not null default now(),
  primary key (student_id, course_id)
);

create index if not exists student_batches_batch_id_idx
on public.student_batches (batch_id);

create index if not exists student_course_marks_course_id_idx
on public.student_course_marks (course_id);
