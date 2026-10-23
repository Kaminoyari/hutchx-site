-- Applied to Supabase project hutchx-site (sntghpgcerfijghqqoop) as migration "create_button_clicks".
create table public.button_clicks (
  id bigint generated always as identity primary key,
  button text not null check (button in (
    'book_call','schedule_with_us', -- schedule_with_us kept only for old rows; that button now records as book_call
   'watch_on_youtube','my_story_video',
    'footer_instagram','footer_youtube','footer_linkedin')),
  page text check (char_length(page) <= 200),
  referrer text check (char_length(referrer) <= 500),
  created_at timestamptz not null default now()
);
create index button_clicks_button_created_idx on public.button_clicks (button, created_at desc);
alter table public.button_clicks enable row level security;
create policy "Anyone can record a click" on public.button_clicks for insert to anon, authenticated with check (true);
revoke all on public.button_clicks from anon, authenticated;
grant insert (button, page, referrer) on public.button_clicks to anon, authenticated;
create view public.button_click_counts with (security_invoker = on) as
select button,
       count(*) as total_clicks,
       count(*) filter (where created_at > now() - interval '7 days') as last_7_days,
       count(*) filter (where created_at > now() - interval '30 days') as last_30_days,
       max(created_at) as last_click
from public.button_clicks group by button order by total_clicks desc;
revoke all on public.button_click_counts from anon, authenticated;

-- See your counts (Supabase dashboard → SQL Editor):
-- select * from public.button_click_counts;

-- Migration "merge_schedule_with_us_into_book_call":
-- the second "Book a call" button used to record as 'schedule_with_us'; store any such clicks as 'book_call'.
create or replace function public.button_clicks_normalize()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.button = 'schedule_with_us' then new.button := 'book_call'; end if;
  return new;
end; $$;
create trigger button_clicks_normalize before insert on public.button_clicks
for each row execute function public.button_clicks_normalize();
revoke all on function public.button_clicks_normalize() from public, anon, authenticated;
update public.button_clicks set button = 'book_call' where button = 'schedule_with_us';
