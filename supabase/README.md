# Supabase: the online lobbies

The game's online lobbies (Quick Match, Create, Browse, Join by code) keep one small row per open lobby in a
Supabase table, and the two players' games find each other through Supabase Realtime broadcast messages. The game
itself is then played peer to peer (WebRTC); Supabase never sees gameplay traffic. Plain-words overview:
`docs/ONLINE.md`. Decisions: `docs/DECISIONS.md` T-138.

- Project: `fkoebguijrmlqdqrsgdy` (URL and the public anon key are in `data/gravelight/online.json`).
- Schema: `migrations/0001_lobbies.sql` (table `lobbies`, RLS, rate-limit trigger, the RPCs `lobby_update`,
  `lobby_close`, `lobby_get`, `lobby_join`, `lobby_sweep`). Safe to run more than once.
- **Never** put the service-role key (or the database password) in this repo or in the game. The game only needs the
  anon key, which is public by design.

## Apply the schema (pick one)

### A. Dashboard (no tools needed)
1. Open https://supabase.com/dashboard/project/fkoebguijrmlqdqrsgdy/sql/new
2. Paste the whole of `supabase/migrations/0001_lobbies.sql`, press **Run**. It should end with "Success. No rows
   returned".
3. Check: Table Editor shows `lobbies` with a "RLS enabled" badge, and Database > Functions lists `lobby_update`,
   `lobby_close`, `lobby_get`, `lobby_join`, `lobby_sweep`.

### B. Supabase CLI
```sh
supabase login                                   # opens the browser once
supabase link --project-ref fkoebguijrmlqdqrsgdy # asks for the database password (not stored in the repo)
supabase db push                                 # applies supabase/migrations/*.sql that are not applied yet
```

## Realtime (signaling)
Nothing to set up: the game uses public **broadcast** channels named `lobby:<CODE>` (no table, nothing stored). If
Realtime > Settings has "Allow public access" switched off, switch it back on (private channels would need user
accounts, which the game doesn't have).

## Optional
- Sweep with pg_cron: enable Database > Extensions > `pg_cron`, then run the migration again; it schedules
  `lobby_sweep()` every minute. Without it the game sweeps whenever someone creates or lists lobbies, which is enough.
- Quick health check from a terminal (anon key from `online.json`):
  ```sh
  curl -s "https://fkoebguijrmlqdqrsgdy.supabase.co/rest/v1/lobbies?select=code,map_id,players" -H "apikey: <anon key>"
  ```
  `[]` (or a list) means the table is live; a 404 / "relation does not exist" means the migration wasn't applied.
