alter table public.notifications
add column if not exists action_url text,
add column if not exists image_url text,
add column if not exists priority text not null default 'low';
