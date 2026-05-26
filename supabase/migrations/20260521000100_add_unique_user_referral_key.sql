create or replace function public.generate_user_referral_key(user_id uuid)
returns text
language sql
immutable
as $$
  select 'JNV-' || upper(substr(replace(user_id::text, '-', ''), 1, 8));
$$;

alter table public.users
add column if not exists referral_key text;

update public.users
set referral_key = public.generate_user_referral_key(id)
where referral_key is null or btrim(referral_key) = '';

alter table public.users
alter column referral_key set not null;

create unique index if not exists users_referral_key_key
on public.users (referral_key);

create or replace function public.set_user_referral_key()
returns trigger
language plpgsql
as $$
begin
  if new.referral_key is null or btrim(new.referral_key) = '' then
    new.referral_key := public.generate_user_referral_key(new.id);
  end if;

  new.referral_key := upper(btrim(new.referral_key));
  return new;
end;
$$;

drop trigger if exists set_user_referral_key on public.users;

create trigger set_user_referral_key
before insert or update of referral_key on public.users
for each row
execute function public.set_user_referral_key();
