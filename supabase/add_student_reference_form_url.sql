-- Run this in the Supabase SQL editor before saving the new
-- Student Reference Form URL from the admin home page.

alter table public.app_config
add column if not exists student_reference_form_url text;

-- Optional one-time seed. Replace the URL with your real Google Form link.
-- If app_config already has a row, this updates it. If it has no row yet,
-- insert a row from the app after this column exists, or uncomment and adapt
-- the insert below to match your table defaults.
--
-- update public.app_config
-- set student_reference_form_url = 'https://forms.gle/your-student-reference-form';
--
-- insert into public.app_config (registration_form_url, student_reference_form_url)
-- select '', 'https://forms.gle/your-student-reference-form'
-- where not exists (select 1 from public.app_config);
