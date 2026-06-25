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

-- 2) Access control: ADMIN-ONLY accounts (no public sign-up) -----------------
--    Remove any self-signup trigger from earlier so it can't block the accounts
--    you create yourself. In the dashboard, turn OFF "Allow new users to sign
--    up" and create each user under Authentication -> Users.
drop trigger if exists enforce_allowed_signup on auth.users;
drop function if exists public.enforce_allowed_signup();

-- 3) Reset start dates so topics begin as "Not started" ----------------------
--    (Skip this block if you have already started topics you want to keep.)
update public.topics set start = null, completed_at = null;
