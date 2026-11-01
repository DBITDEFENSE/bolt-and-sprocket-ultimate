-- UPDATE 09 section 2b (docs/U09_CONTRACTS.md C3, docs/DECISIONS.md T-138): online co-op lobbies.
--
-- What lives here: one row per open lobby (its 6-letter join code, map, public/private, the host's display name,
-- the player list the host keeps current, the bots toggle, a status and two timestamps). The WebRTC signaling
-- (offer / answer / ICE) never touches a table: it is Realtime *broadcast* on the channel `lobby:<code>`.
--
-- Security model (the client only ever has the public anon key):
--   * RLS is on. anon may SELECT public, not-closed lobbies (the Browse list). A private lobby is read only by
--     exact code through the RPCs `lobby_get` / `lobby_join`.
--   * anon may INSERT a lobby. A BEFORE INSERT trigger rate-limits it: at most 5 inserts a minute per host_token,
--     at most 1 open lobby per host_token, at most 30 inserts a minute per client IP (when the gateway passes
--     one), and at most 500 open lobbies in total.
--   * Nobody may UPDATE or DELETE directly. The host changes its lobby through `lobby_update(code, host_token,
--     patch)` and closes it with `lobby_close(code, host_token)`; both are SECURITY DEFINER and check the token.
--   * The host_token column is never readable: column privileges leave it out of every SELECT grant, and the
--     RPCs never return it.
--   * `lobby_sweep()` deletes every lobby whose heartbeat is older than 120 s (the client calls it now and then;
--     the insert trigger also runs it; pg_cron runs it every minute when the extension is enabled).
--
-- Idempotent: safe to run again (create ... if not exists, create or replace, drop policy if exists).

create table if not exists public.lobbies (
	code         text        primary key,
	map_id       text        not null,
	is_public    boolean     not null default true,
	host_name    text        not null default 'Player',
	players      jsonb       not null default '[]'::jsonb,
	fill_bots    boolean     not null default false,
	status       text        not null default 'open',
	max_players  integer     not null default 4,
	created_at   timestamptz not null default now(),
	heartbeat_at timestamptz not null default now(),
	host_token   text        not null
);

-- Constraints (added separately so a re-run on an existing table still gets them).
do $$
begin
	if not exists (select 1 from pg_constraint where conname = 'lobbies_code_format') then
		alter table public.lobbies add constraint lobbies_code_format check (code ~ '^[A-Z]{6}$');
	end if;
	if not exists (select 1 from pg_constraint where conname = 'lobbies_map_id_len') then
		alter table public.lobbies add constraint lobbies_map_id_len check (char_length(map_id) between 1 and 40);
	end if;
	if not exists (select 1 from pg_constraint where conname = 'lobbies_host_name_len') then
		alter table public.lobbies add constraint lobbies_host_name_len check (char_length(host_name) between 1 and 24);
	end if;
	if not exists (select 1 from pg_constraint where conname = 'lobbies_players_array') then
		alter table public.lobbies add constraint lobbies_players_array
			check (jsonb_typeof(players) = 'array' and jsonb_array_length(players) <= 4);
	end if;
	if not exists (select 1 from pg_constraint where conname = 'lobbies_status_values') then
		alter table public.lobbies add constraint lobbies_status_values
			check (status in ('open', 'starting', 'playing', 'closed'));
	end if;
	if not exists (select 1 from pg_constraint where conname = 'lobbies_max_players_range') then
		alter table public.lobbies add constraint lobbies_max_players_range check (max_players between 1 and 4);
	end if;
	if not exists (select 1 from pg_constraint where conname = 'lobbies_host_token_len') then
		alter table public.lobbies add constraint lobbies_host_token_len check (char_length(host_token) between 16 and 64);
	end if;
end $$;

create index if not exists lobbies_heartbeat_idx on public.lobbies (heartbeat_at);
create index if not exists lobbies_host_token_idx on public.lobbies (host_token);
create index if not exists lobbies_public_idx on public.lobbies (is_public, status);

-- The insert log behind the per-minute rate limit (rows of deleted lobbies still count). No policies: only the
-- SECURITY DEFINER trigger below writes or reads it.
create table if not exists public.lobby_insert_log (
	id         bigserial   primary key,
	host_token text        not null,
	client_ip  text        not null default '',
	at         timestamptz not null default now()
);
create index if not exists lobby_insert_log_at_idx on public.lobby_insert_log (at);
alter table public.lobby_insert_log enable row level security;
revoke all on public.lobby_insert_log from anon, authenticated;

-- ---------------------------------------------------------------------------------------------- privileges + RLS
alter table public.lobbies enable row level security;

revoke all on public.lobbies from anon, authenticated;
grant select (code, map_id, is_public, host_name, players, fill_bots, status, max_players, created_at, heartbeat_at)
	on public.lobbies to anon, authenticated;
grant insert (code, map_id, is_public, host_name, players, fill_bots, max_players, host_token)
	on public.lobbies to anon, authenticated;

drop policy if exists lobbies_select_public on public.lobbies;
create policy lobbies_select_public on public.lobbies
	for select to anon, authenticated
	using (is_public and status <> 'closed');

drop policy if exists lobbies_insert_any on public.lobbies;
create policy lobbies_insert_any on public.lobbies
	for insert to anon, authenticated
	with check (status = 'open' and jsonb_array_length(players) <= max_players);

-- No update / delete policies on purpose: changes go through the token-checked RPCs below.

-- ------------------------------------------------------------------------------------------------- helpers
-- The lobby as the client sees it (never the token).
create or replace function public.lobby_public_json(l public.lobbies)
returns jsonb
language sql
stable
set search_path = public
as $$
	select jsonb_build_object(
		'code', l.code, 'map_id', l.map_id, 'is_public', l.is_public, 'host_name', l.host_name,
		'players', l.players, 'fill_bots', l.fill_bots, 'status', l.status, 'max_players', l.max_players,
		'created_at', l.created_at, 'heartbeat_at', l.heartbeat_at);
$$;
revoke all on function public.lobby_public_json(public.lobbies) from public, anon, authenticated;

-- The caller's IP as the API gateway passes it (empty when there is none).
create or replace function public.lobby_client_ip()
returns text
language plpgsql
stable
set search_path = public
as $$
declare
	h json;
begin
	begin
		h := current_setting('request.headers', true)::json;
	exception when others then
		return '';
	end;
	if h is null then
		return '';
	end if;
	return coalesce(split_part(coalesce(h ->> 'x-forwarded-for', h ->> 'x-real-ip', ''), ',', 1), '');
end;
$$;
revoke all on function public.lobby_client_ip() from public, anon, authenticated;

-- --------------------------------------------------------------------------------------------- sweep
create or replace function public.lobby_sweep()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
	n integer;
begin
	delete from public.lobbies where heartbeat_at < now() - interval '120 seconds' or status = 'closed';
	get diagnostics n = row_count;
	delete from public.lobby_insert_log where at < now() - interval '10 minutes';
	return n;
end;
$$;
revoke all on function public.lobby_sweep() from public;
grant execute on function public.lobby_sweep() to anon, authenticated;

-- ------------------------------------------------------------------------------------- insert rate limit
create or replace function public.lobby_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
	ip text := public.lobby_client_ip();
begin
	perform public.lobby_sweep();
	-- the server owns these, whatever the client sent
	new.status := 'open';
	new.created_at := now();
	new.heartbeat_at := now();
	if (select count(*) from public.lobby_insert_log
			where host_token = new.host_token and at > now() - interval '1 minute') >= 5 then
		raise exception 'rate_limited: at most 5 lobbies a minute' using errcode = 'P0001';
	end if;
	if ip <> '' and (select count(*) from public.lobby_insert_log
			where client_ip = ip and at > now() - interval '1 minute') >= 30 then
		raise exception 'rate_limited: too many lobbies from this address' using errcode = 'P0001';
	end if;
	if exists (select 1 from public.lobbies
			where host_token = new.host_token and status in ('open', 'starting', 'playing')) then
		raise exception 'one_open_lobby: this host already has an open lobby' using errcode = 'P0001';
	end if;
	if (select count(*) from public.lobbies) >= 500 then
		raise exception 'server_full: too many open lobbies, try again later' using errcode = 'P0001';
	end if;
	insert into public.lobby_insert_log (host_token, client_ip) values (new.host_token, ip);
	return new;
end;
$$;
revoke all on function public.lobby_before_insert() from public, anon, authenticated;

drop trigger if exists lobbies_before_insert on public.lobbies;
create trigger lobbies_before_insert
	before insert on public.lobbies
	for each row execute function public.lobby_before_insert();

-- ------------------------------------------------------------------------------------------- RPCs
-- The host changes its lobby. Allowed patch keys: map_id, is_public, host_name, players, fill_bots, status.
-- Every call also refreshes heartbeat_at (an empty patch {} is the heartbeat). Returns the lobby (no token), or
-- raises 'lobby_not_found' when the code / token pair doesn't match.
create or replace function public.lobby_update(code text, host_token text, patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
	l public.lobbies;
	p jsonb := coalesce(patch, '{}'::jsonb);
begin
	if jsonb_typeof(p) <> 'object' then
		raise exception 'bad_patch' using errcode = 'P0001';
	end if;
	update public.lobbies as t set
		map_id = case when p ? 'map_id' then left(p ->> 'map_id', 40) else t.map_id end,
		is_public = case when p ? 'is_public' then (p ->> 'is_public')::boolean else t.is_public end,
		host_name = case when p ? 'host_name' then left(p ->> 'host_name', 24) else t.host_name end,
		players = case when p ? 'players' and jsonb_typeof(p -> 'players') = 'array'
			and jsonb_array_length(p -> 'players') <= t.max_players then p -> 'players' else t.players end,
		fill_bots = case when p ? 'fill_bots' then (p ->> 'fill_bots')::boolean else t.fill_bots end,
		status = case when p ->> 'status' in ('open', 'starting', 'playing', 'closed') then p ->> 'status' else t.status end,
		heartbeat_at = now()
	where t.code = lobby_update.code and t.host_token = lobby_update.host_token
	returning * into l;
	if not found then
		raise exception 'lobby_not_found' using errcode = 'P0001';
	end if;
	return public.lobby_public_json(l);
end;
$$;
revoke all on function public.lobby_update(text, text, jsonb) from public;
grant execute on function public.lobby_update(text, text, jsonb) to anon, authenticated;

-- The host closes its lobby (leaving, or the match ended). True when a row was deleted.
create or replace function public.lobby_close(code text, host_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
	delete from public.lobbies as t where t.code = lobby_close.code and t.host_token = lobby_close.host_token;
	return found;
end;
$$;
revoke all on function public.lobby_close(text, text) from public;
grant execute on function public.lobby_close(text, text) to anon, authenticated;

-- Read one lobby by its exact code (private ones too). Returns null when there is none (or it expired).
create or replace function public.lobby_get(code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
	l public.lobbies;
begin
	select * into l from public.lobbies as t
		where t.code = upper(lobby_get.code) and t.status <> 'closed'
			and t.heartbeat_at >= now() - interval '120 seconds';
	if not found then
		return null;
	end if;
	return public.lobby_public_json(l);
end;
$$;
revoke all on function public.lobby_get(text) from public;
grant execute on function public.lobby_get(text) to anon, authenticated;

-- A player joins by code: appends `player` ({name, character, ready, pid}) to an open lobby that has room and
-- returns the lobby. Raises 'lobby_not_found' (no such code or it expired), 'lobby_closed' (already playing),
-- 'lobby_full'. The host rewrites the list from its own roster on its next heartbeat, so this row is only a hint
-- for the Browse list until then.
create or replace function public.lobby_join(code text, player jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
	l public.lobbies;
	entry jsonb;
begin
	select * into l from public.lobbies as t
		where t.code = upper(lobby_join.code) and t.heartbeat_at >= now() - interval '120 seconds'
		for update;
	if not found then
		raise exception 'lobby_not_found' using errcode = 'P0001';
	end if;
	if l.status <> 'open' then
		raise exception 'lobby_closed' using errcode = 'P0001';
	end if;
	if jsonb_array_length(l.players) >= l.max_players then
		raise exception 'lobby_full' using errcode = 'P0001';
	end if;
	entry := jsonb_build_object(
		'name', left(coalesce(player ->> 'name', 'Player'), 24),
		'character', left(coalesce(player ->> 'character', ''), 16),
		'ready', false,
		'pid', 0);
	update public.lobbies as t set players = t.players || jsonb_build_array(entry)
		where t.code = l.code
		returning * into l;
	return public.lobby_public_json(l);
end;
$$;
revoke all on function public.lobby_join(text, jsonb) from public;
grant execute on function public.lobby_join(text, jsonb) to anon, authenticated;

-- Optional: sweep every minute with pg_cron when the extension is enabled (Database > Extensions > pg_cron).
do $$
begin
	if exists (select 1 from pg_extension where extname = 'pg_cron') then
		begin
			perform cron.unschedule('lobby_sweep');
		exception when others then
			null;
		end;
		perform cron.schedule('lobby_sweep', '* * * * *', 'select public.lobby_sweep();');
	end if;
end $$;
