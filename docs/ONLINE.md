# Online play

How co-op over the internet works, in plain words. Decisions and details: `docs/DECISIONS.md` T-138; the contract
between the parts: `docs/U09_CONTRACTS.md` C3. (The browser build's own notes, UPDATE 09 section 2c, go in their own
section of this file.)

## Play with a friend (by code)
1. Main menu → **Co-op** (later: Play → Online). The first time it asks for a **display name** (no account; it is kept
   on your PC and shown to the others).
2. One of you presses **Create Lobby**: pick the map, how many players (2–4), **Public** (listed for strangers) or
   private, and whether **bots fill empty slots**. The lobby screen shows a **6-letter code**, e.g. `KXMRTA`.
3. Send the code to your friend (chat, phone, anything). They press **Join by Code** and type it (case doesn't matter).
4. Each of you picks a survivor (each survivor once), the friend presses **Ready**, the host presses **Start**.

Other ways in: **Quick Match** joins the public lobby with the fewest players (or creates a public one if there is
none); **Browse Lobbies** lists the public lobbies (it refreshes every 5 seconds).

Nobody has to open a port or touch their router. Desktop and browser builds use the same connection, so a browser
player and a desktop player can play together.

### If something goes wrong
- **"Couldn't connect to that lobby (timed out after 15 s)."** The two computers couldn't reach each other (see
  "Known limits"). You're back on the lobby screen; try again, or try the other person hosting.
- **"The host left the match."** The host quit or closed the lobby: the match ends for everyone (there is no host
  migration). You land back on the lobby screen.
- **Your own connection dropped** ("Lost the connection to the host."): the lobby screen shows **Rejoin the match**
  for 60 seconds. Rejoining puts you back in as the same player with the same survivor and the same gear, where your
  body was. Meanwhile your slot is played by a bot if the host switched "bots fill empty slots" on; otherwise your
  body steps out of the match until you're back (after 60 s without you, it's gone for good).
- **"No lobby with that code"**: the code is wrong, the host closed it, or it expired (a lobby disappears 2 minutes
  after its host stopped answering).

## LAN (direct IP)
Still there for playing on one network or testing: lobby screen → **LAN (direct IP)** → **Host a LAN game** on one PC;
the others type its address (shown on the host's screen; same PC: `127.0.0.1`). This uses UDP port 24785 directly
(ENet), so over the internet it needs a forwarded port; use the code lobbies for that instead.

## What Supabase does (and doesn't)
Supabase is a hosted database service (project `fkoebguijrmlqdqrsgdy`, free tier). The game uses it for two small
jobs only:
- **The lobby list**: one row per open lobby (the code, map, public/private, the host's display name, the player list,
  the bots switch, when it was last heard from). The host refreshes its row every 20 seconds.
- **The introduction** ("signaling"): before two games can talk directly, they swap a few short messages (who's there,
  how to reach each other). These go through Supabase Realtime as broadcast messages on a channel named after the
  lobby code; nothing is stored.

After that the games talk **directly to each other** (WebRTC, peer to peer). Gameplay never goes through Supabase,
so it costs nothing per match and adds no lag. The schema is `supabase/migrations/0001_lobbies.sql`; how to apply it:
`supabase/README.md`.

## Security model
- The game only contains Supabase's **public "anon" key** (`data/gravelight/online.json`). It is meant to be public:
  on its own it can do only what the database rules allow. The **service-role key is never in the game or the repo.**
- **Row Level Security** is on. With the anon key anyone can: list *public* lobbies; read one lobby by its exact code;
  create a lobby; join a lobby by code. Nobody can change or delete a lobby except through two functions that check the
  host's secret **host token** (made fresh for each lobby, kept only in the host's memory, never readable from the
  table).
- **Abuse limits**: at most 5 lobbies a minute per host token, one open lobby per host token, 30 a minute per internet
  address, 500 open lobbies in total; lobbies without a heartbeat for 2 minutes are swept.
- What others can see about you: your display name, your survivor and ready state, the lobby code. Peer to peer means
  the other players' games learn your internet address (that's how every peer-to-peer game works). There are no
  accounts, passwords or chat.
- A rejoin needs the **session token** your game got when it joined; nobody else can take your slot.
- The host runs the match (host-authoritative, like the LAN game): clients send their inputs and hits, the host checks
  them (hit validation, D-066).

## TURN (optional) and how to add one
Most home connections can connect directly using the free public **STUN** servers already configured (they only tell a
computer its own public address). Some networks (strict company / school / mobile-carrier networks, "symmetric NAT")
block direct connections; for those a **TURN** server relays the traffic. It's optional and costs money or a free-tier
account, so it's off.

To add one: create a TURN account (for example Metered.ca's free "Open Relay" tier, Twilio Network Traversal, or
Cloudflare Calls TURN, or run `coturn` on a small server), then put its details in `data/gravelight/online.json`:
```json
"turn": {"urls": ["turn:your.turn.host:3478", "turns:your.turn.host:5349"], "username": "...", "credential": "..."}
```
Leave `urls` empty to switch it off again. (A TURN credential in the game is visible to players; use a provider's
limited or time-boxed credentials, never an admin password.)

## Known limits
- **No host migration**: when the host leaves, the match ends.
- **Strict networks without TURN** can't connect (the 15 s timeout message). Adding TURN fixes it.
- A rejoin restores your body, gear, the round, Scrip, perks, the doors, the boards, the zombies alive and the quest
  state; small effects that were already running when you dropped (a power-up glinting on the ground, a dynamic
  world object spawned while you were away) may be missing until they change again.
- Joining a match that has already started is only possible as a rejoin (within 60 s of a drop).
- The desktop build needs the `addons/webrtc` extension (webrtc-native, MIT; Windows and Linux 64-bit are included);
  the browser build has WebRTC built in. Without the extension, online lobbies say so and LAN still works.
- Up to 4 players (humans + bots).

## For developers
- Code: `gravelight/autoload/net.gd` (Net: ENet `host_game`/`join_game`, WebRTC `host_online`/`join_online`, the roster,
  bots in slots, drop/rejoin), `gravelight/net/rtc_transport.gd` (WebRTC peer + connections + trickle ICE),
  `gravelight/net/signaling.gd` (abstract) + `supabase_signaling.gd` + `mock_signaling.gd` + `mock_signal_server.gd`,
  `gravelight/net/lobby_service.gd` (the `Lobbies` autoload) + `supabase_lobby_backend.gd` + `mock_lobby_service.gd` +
  `mock_lobby_backend.gd`, the screens in `gravelight/ui/menu_lobby.gd`.
- Local testing without the internet: start the game with `--mock-online-serve=28500` on one instance (it hosts a
  local lobby table + relay) and `--mock-online=28500` on the others; or set `"backend": "mock"` in online.json.
- Tests: `gravelight/tests/unit/test_online.gd`, `test_coop.gd`; smokes `smoke_webrtc` (two headless instances over
  WebRTC + the mock relay: lobby, 2 rounds with a bot, drop + rejoin, host leaves) and `smoke_lobby` (the lobby state
  machine on the mock backend).
