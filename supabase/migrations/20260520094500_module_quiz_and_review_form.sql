alter table public.student_quiz_attempts
add column if not exists module_id text,
add column if not exists module_order integer,
add column if not exists module_title text;

create index if not exists student_quiz_attempts_module_idx
on public.student_quiz_attempts (student_id, course_id, module_order);

alter table public.student_course_progress
add column if not exists module_quiz_state jsonb not null default '{}'::jsonb;

alter table public.app_config
add column if not exists course_review_form_url text;
