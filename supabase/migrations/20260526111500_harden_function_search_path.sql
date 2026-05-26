alter function public.generate_user_referral_key(user_id uuid)
set search_path = public, pg_temp;

alter function public.limit_course_mentors()
set search_path = public, pg_temp;

alter function public.set_updated_at()
set search_path = public, pg_temp;

alter function public.set_user_referral_key()
set search_path = public, pg_temp;
