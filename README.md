# NEW-Tracker-SG

Internal collaborative **Operating Plan — Implementation Tracker** for ~14 people
editing the same plan simultaneously, with **Supabase (Postgres + Realtime + Auth)**
as the single source of truth and **Vercel** hosting the frontend.

➡️ **Setup & deployment instructions: [`app/README.md`](app/README.md)**

- `app/` — the React + Vite application and the Supabase SQL (`app/supabase/`)
- `.github/workflows/supabase-keepalive.yml` — keeps the free Supabase project awake
- `operating-plan-tracker v5.html`, `tracker.json`, `*.pdf` — the original
  reference files (visual/functionality reference only; not used at runtime)
