-- ============================================================================
--  Operating Plan Tracker — database schema (run this once in the Supabase
--  SQL editor, then run seed.sql).
--
--  Design notes:
--   * Postgres is the single source of truth. The app never relies on local
--     state, files, or static JSON for persistence.
--   * One row per topic (checkpoints & notes live as JSONB inside the topic
--     row) keeps concurrent editing safe: two people editing different topics
--     never collide. Same-topic edits are last-write-wins, which is fine for a
--     small internal team.
--   * Realtime is enabled on every table so each change is pushed live to all
--     connected users.
--   * Row-Level Security: any signed-in (authenticated) user can read & write.
--     Anonymous visitors get nothing.
-- ============================================================================

-- ---- settings (single row) ----
create table if not exists public.settings (
  id         int primary key default 1,
  start      text not null,
  version    int  not null default 1,
  updated_at timestamptz not null default now(),
  constraint settings_singleton check (id = 1)
);

-- ---- workstreams (the "cats" / categories) ----
create table if not exists public.workstreams (
  id         text primary key,
  name       text not null,
  color      text not null default '#5a6373',
  sort_order int  not null default 0,
  updated_at timestamptz not null default now()
);

-- ---- topics (the "items" / initiatives) ----
create table if not exists public.topics (
  id            text primary key,
  workstream_id text not null references public.workstreams(id) on delete cascade,
  title         text not null,
  owner         text not null default '',
  owner2        text not null default '',
  status        text not null default 'not_started',
  priority      text,
  phase         int  not null default 1,
  start         text,
  due           text,
  completed_at  text,
  health        text,
  checkpoints   jsonb not null default '[]'::jsonb,
  notes         jsonb not null default '[]'::jsonb,
  sort_order    int  not null default 0,
  updated_at    timestamptz not null default now()
);
create index if not exists topics_workstream_idx on public.topics(workstream_id);

-- ---- activity log (append-only) ----
create table if not exists public.activity (
  id    text primary key,
  ts    timestamptz not null default now(),
  type  text,
  topic text,
  msg   text not null
);
create index if not exists activity_ts_idx on public.activity(ts);

-- ---- weekly progress snapshots ----
create table if not exists public.history (
  week       text primary key,
  snapshot   jsonb not null,
  updated_at timestamptz not null default now()
);

-- ---- deleted items (recoverable archive — nothing is ever hard-deleted by users) ----
create table if not exists public.deleted_items (
  id            text primary key,
  kind          text not null,            -- 'topic' | 'checkpoint' | 'note'
  payload       jsonb not null,           -- the full original item, for restore
  workstream_id text,                     -- where a topic should be restored
  topic_id      text,                     -- which topic a checkpoint/note belongs to
  sort_order    int,
  context       text,                     -- e.g. the topic title, for display
  deleted_by    text,
  deleted_at    timestamptz not null default now()
);
create index if not exists deleted_items_deleted_at_idx on public.deleted_items(deleted_at);

-- ============================================================================
--  Realtime: broadcast every change to connected clients
-- ============================================================================
alter publication supabase_realtime add table public.settings;
alter publication supabase_realtime add table public.workstreams;
alter publication supabase_realtime add table public.topics;
alter publication supabase_realtime add table public.activity;
alter publication supabase_realtime add table public.history;
alter publication supabase_realtime add table public.deleted_items;

-- ============================================================================
--  Row-Level Security: signed-in users can do everything; anon gets nothing
-- ============================================================================
alter table public.settings    enable row level security;
alter table public.workstreams enable row level security;
alter table public.topics      enable row level security;
alter table public.activity    enable row level security;
alter table public.history     enable row level security;
alter table public.deleted_items enable row level security;

do $$
declare t text;
begin
  foreach t in array array['settings','workstreams','topics','activity','history','deleted_items'] loop
    execute format(
      'create policy %I on public.%I for all to authenticated using (true) with check (true)',
      'authenticated_all_' || t, t
    );
  end loop;
end $$;

-- ============================================================================
--  Access control: ADMIN-ONLY accounts (no public sign-up)
--  In the Supabase dashboard: Authentication -> Providers -> Email, turn OFF
--  "Allow new users to sign up". Create each user under Authentication -> Users.
--  The app's login screen has no sign-up option, and RLS already restricts all
--  data to signed-in users only. No signup trigger is used; this also removes
--  any earlier one so it can't block admin-created accounts.
-- ============================================================================
drop trigger if exists enforce_allowed_signup on auth.users;
drop function if exists public.enforce_allowed_signup();
