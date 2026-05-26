alter table public.student_batches enable row level security;
alter table public.student_course_marks enable row level security;

revoke insert, update, delete on public.student_batches from anon;
revoke insert, update, delete on public.student_course_marks from anon;

grant select on public.student_batches to anon, authenticated;
grant select on public.student_course_marks to authenticated;

drop policy if exists "student_batches_read" on public.student_batches;
create policy "student_batches_read"
on public.student_batches
for select
to anon, authenticated
using (true);

drop policy if exists "student_course_marks_authenticated_read" on public.student_course_marks;
create policy "student_course_marks_authenticated_read"
on public.student_course_marks
for select
to authenticated
using (true);

drop policy if exists "student_batches_service_role_manage" on public.student_batches;
create policy "student_batches_service_role_manage"
on public.student_batches
for all
to service_role
using (true)
with check (true);

drop policy if exists "student_course_marks_service_role_manage" on public.student_course_marks;
create policy "student_course_marks_service_role_manage"
on public.student_course_marks
for all
to service_role
using (true)
with check (true);
