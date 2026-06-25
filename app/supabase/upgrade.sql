-- ============================================================================
--  UPGRADE for an EXISTING database (you already ran schema.sql + seed.sql).
--  Run this once in the Supabase SQL editor. It is additive and safe to re-run.
--
--  It adds:
--   1. the Deleted-items archive table (recoverable deletes)
--   2. self-service signup restricted to authorized users (no manual approval)
--   3. resets topic start dates so every topic begins as "Not started"
--      (matches the new rule that a topic has no start date until you click Start)
-- ============================================================================

-- 1) Deleted items archive ----------------------------------------------------
create table if not exists public.deleted_items (
  id            text primary key,
  kind          text not null,
  payload       jsonb not null,
  workstream_id text,
  topic_id      text,
  sort_order    int,
  context       text,
  deleted_by    text,
  deleted_at    timestamptz not null default now()
);
create index if not exists deleted_items_deleted_at_idx on public.deleted_items(deleted_at);

-- realtime (ignore error if already added)
do $$ begin
  alter publication supabase_realtime add table public.deleted_items;
exception when duplicate_object then null; end $$;

alter table public.deleted_items enable row level security;
do $$ begin
  create policy authenticated_all_deleted_items on public.deleted_items
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

-- 2) Self-service signup, restricted to authorized people ---------------------
create table if not exists public.allowed_emails ( email text primary key );

-- >>> EDIT 'sigulerguff.com' if your company domain is different <<<
create or replace function public.enforce_allowed_signup()
returns trigger language plpgsql security definer as $$
declare allowed_domain text := 'sigulerguff.com';
begin
  if lower(split_part(new.email, '@', 2)) = allowed_domain
     or exists (select 1 from public.allowed_emails where lower(email) = lower(new.email)) then
    return new;
  end if;
  raise exception 'This email is not authorized to use this app.';
end $$;

drop trigger if exists enforce_allowed_signup on auth.users;
create trigger enforce_allowed_signup
  before insert on auth.users
  for each row execute function public.enforce_allowed_signup();

-- To authorize someone OUTSIDE your domain, add their email here, e.g.:
--   insert into public.allowed_emails (email) values ('partner@example.com');

-- 3) Reset start dates so topics begin as "Not started" ----------------------
--    (Skip this block if you have already started topics you want to keep.)
update public.topics set start = null, completed_at = null;
