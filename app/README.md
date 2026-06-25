# Operating Plan — Implementation Tracker

An internal collaborative tracker for ~14 people to edit the same plan at the
same time, with **Postgres as the single source of truth** and **live sync** so
nothing ever "appears then disappears".

- **Frontend:** React + Vite (static site) — deploy on **Vercel**
- **Backend:** **Supabase** — Postgres + Realtime + Auth, all in one free project
- **Sign-in:** email + password (no email sending required; admin creates accounts)
- **Keep-alive:** a GitHub Action pings Supabase every 3 days so the free project never pauses

The UI (6 tabs: Overview, Board, Schedule, Calendar, People, Deleted, plus
PDF/Excel exports) is ported from the original `operating-plan-tracker v5.html`.
Only the data layer was rebuilt — every create/edit/delete now writes straight
to Postgres and is broadcast to all other users.

> **Already have it running? To pick up the latest changes** (self-service
> sign-up, Deleted tab, automatic status/target dates, checkpoint health &
> categories): in the Supabase **SQL editor** run **`supabase/upgrade.sql`**
> once, then turn **ON** "Allow new users to sign up" and **OFF** "Confirm
> email" under **Authentication**. Vercel redeploys the frontend automatically
> when you push. That's it.

---

## Why this can't lose data (the old bug)

The previous version stored everything in browser memory / a local JSON file
(last-write-wins). If you weren't "connected" to a file, new items lived only in
React state and vanished on refresh — that was the disappearing-data bug.

Here, there is **no in-memory-only mode**. Each topic is a row in Postgres.
The screen is just a live view of the database. Add a checkpoint → it's an
`INSERT`/`UPDATE` that returns success and is pushed to everyone in ~100ms. Close
the browser, refresh, redeploy — the data is in Postgres, untouched.

---

## One-time setup (about 15 minutes)

### 1. Create the Supabase project
1. Go to https://supabase.com → **New project** (free plan). Pick a name and a
   strong database password. Wait ~2 min for it to provision.
2. In the dashboard, open **SQL Editor → New query**, paste the contents of
   [`supabase/schema.sql`](supabase/schema.sql), and **Run**.
3. New query again, paste [`supabase/seed.sql`](supabase/seed.sql), and **Run**.
   This loads the starting plan (5 workstreams, 36 topics).
4. Open **Project Settings → API** and copy two values:
   - **Project URL** (e.g. `https://abcd1234.supabase.co`)
   - **anon public** key

### 2. Set up self-service sign-up (email + password, no manual approval)
This app uses email + password with **self-service sign-up restricted to
authorized people**. No confirmation emails are sent, and you never have to
approve anyone by hand — a database rule only lets authorized emails register.

1. **Authentication → Providers → Email**: make sure **Email** is enabled and
   turn **ON** "Allow new users to sign up".
2. **Authentication → Sign In / Up** (or **Settings**): turn **OFF**
   "Confirm email" so new accounts work instantly without any email.
3. The signup restriction is created by the SQL in step 1 (`schema.sql`) — it
   only allows emails on your company domain (default `sigulerguff.com`) plus
   anything you add to the `allowed_emails` table. **Edit that domain** in
   `schema.sql` (function `enforce_allowed_signup`) before running it if your
   domain differs.

Now anyone with an authorized email opens the app, clicks **"First time here?
Create your account"**, sets a password, and is in immediately. To authorize an
outside collaborator, add their email:
`insert into public.allowed_emails (email) values ('name@partner.com');`

### 3. Deploy the frontend on Vercel
1. Push this repo to GitHub (already done if you're reading this there).
2. Go to https://vercel.com → **Add New… → Project** → import this repo.
3. **Important:** set **Root Directory** to `app` (this project lives in the
   `app/` subfolder). Vercel auto-detects Vite — leave build settings default.
4. Under **Environment Variables**, add:
   - `VITE_SUPABASE_URL` = your Project URL
   - `VITE_SUPABASE_ANON_KEY` = your anon public key
5. **Deploy.** When it's live, copy the Vercel URL and share it with your team.
   (No Supabase URL configuration is needed for password sign-in.)

### 4. Turn on the keep-alive (so the project never pauses)
In **GitHub → repo Settings → Secrets and variables → Actions → New repository
secret**, add:
- `SUPABASE_URL` = your Project URL
- `SUPABASE_ANON_KEY` = your anon public key

The workflow at [`.github/workflows/supabase-keepalive.yml`](../.github/workflows/supabase-keepalive.yml)
then pings Supabase every 3 days. You can also run it manually from the
**Actions** tab. (With 14 daily users it'll basically never be needed — it's a
safety net.)

### 5. Invite the team
Send everyone the Vercel URL. They enter their email, click the link, and they're in.

---

## Local development

```bash
cd app
cp .env.example .env      # then paste your Supabase URL + anon key into .env
npm install
npm run dev               # http://localhost:5173
```

For local magic links to work, add `http://localhost:5173` to Supabase
**Authentication → URL Configuration → Redirect URLs**.

```bash
npm run build             # production build into app/dist (what Vercel runs)
```

---

## How it works (for whoever maintains it)

| Concern | How it's handled |
|---|---|
| **Source of truth** | Postgres tables `workstreams`, `topics`, `settings`, `activity`, `history`. The app only ever renders what the database returns. |
| **Concurrent editing** | One row per topic (checkpoints/notes are JSONB inside it). Different topics never collide; same-topic edits are last-write-wins, fine for a small team. |
| **Live sync** | Supabase Realtime broadcasts every change; each client reloads the affected data automatically. The topic you're actively typing in is protected from being overwritten by an incoming sync. |
| **Persistence** | Every action is an awaited write to Postgres. No localStorage, no files, no mock data. |
| **Auth / access** | Supabase magic-link email. Row-Level Security only allows signed-in users; anonymous visitors get nothing. |

### Inspecting or fixing data by hand
Open the Supabase dashboard → **Table Editor**. You can read or correct any row
directly in `topics` / `workstreams`; changes appear live in the app. To reload
the whole starting plan from scratch, re-run `supabase/seed.sql` (it clears and
re-inserts).

### Project layout
```
app/
  index.html              # Vite entry
  src/
    main.jsx              # mounts <App/>
    supabase.js           # Supabase client (reads VITE_ env vars)
    tracker-core.jsx      # UI ported verbatim + the new Supabase data layer
  supabase/
    schema.sql            # tables, RLS, realtime  (run first)
    seed.sql              # starting plan          (run second)
.github/workflows/
  supabase-keepalive.yml  # keeps the free project awake
```
