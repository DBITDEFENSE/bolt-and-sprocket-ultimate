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

## What works the same online
Everything in a match runs on the host and shows on every screen: rounds, Scrip, perks, the crate, power-ups, quests,
**Jakub and the map companions** (talk to them and their choice card opens on your screen; they fight, go down and get
revived like offline), the Totenglocke's **Bell Dome** (whoever plants it, it slows and staggers the zombies on the
host and everyone sees it), and **the bank** (each player's savings stay in their own profile; deposits and
withdrawals move Scrip through the host).

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
- Online, Jakub is the Map 0 prisoner you free in the match; the Jakub who travels with you between campaign maps
  (and the one from your profile on other maps) is still offline-only, as is a map companion carried between acts.
- The bank trusts each player's own saved balance (it lives on their PC), so a tampered game could withdraw more than
  it saved. Fine among friends; there is no server-side bank.

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

## The browser build: what to expect

*(UPDATE 09 §2c, DECISIONS T-139.)*

**It looks simpler than the desktop game, on purpose.** Browsers run Godot on WebGL 2, which means Godot's
*Compatibility* renderer, not the *Forward+* renderer the desktop game uses. The Compatibility renderer has none of:
SDFGI (the bounce light), SSIL (indirect light), SSR (reflections), SSAO, volumetric fog and fog volumes, FSR
upscaling, TAA. So in the browser:
- the maps that use volumetric fog get plain distance ("depth") fog in the same colour instead;
- shadows from the sun reach 40 m, and each zone keeps at most 4 lamps that cast shadows (the ones nearest where
  you start; the others still light the room, without shadows);
- textures are at most 1024 px (the desktop has 2048 px on the guns, wonder weapons and the Poly Haven materials);
- particles and snow are halved, and zombies far away animate at a lower rate (from half the desktop distance);
- anti-aliasing is FXAA, the 3D view renders at 85% and is scaled up.

The game, its rules, timings, hitboxes and maps are the same. The browser picks this "Browser" graphics preset by
itself; Settings > Video still lets you change it.

**What computer.** A desktop browser (Chrome, Edge or Firefox, recent) with WebGL 2 and a GPU from the last few
years. Phones and tablets are not supported. The target is 30 FPS or more on a laptop with Intel Iris Xe graphics
(docs/PERFORMANCE.md; not yet measured on such a laptop), more on anything with a real graphics card. The desktop (Windows) build is faster and looks better on the same machine.

**Threads and headers.** The browser build uses Godot's single-threaded web template (`web_nothreads`). That
means the site needs no special `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers, works on
any static host, and works inside other pages. The price is that audio and loading share one thread with the game,
so a heavy moment can stutter a little more than on the desktop. The threaded template would need those headers
on every file; we measured no reason to switch yet.

**How big it is (the real numbers of the 2026-11-01 build after the map rebuilds and the new menu, `tools/build_web.sh`; T-150).**

| What | Size | Over the wire (gzip/brotli) |
|---|---|---|
| Engine (`cz-<hash>.wasm` + js) | 37.7 MB | ~10 MB |
| Main pack (menus, scripts, data, the inn set's textures, the zombie bodies and the squad's four people, the menu's sounds and music) | 97.8 MB | ~85 MB |
| **To reach the menu** | **135.8 MB** | **~95 MB** |
| Game packs `game1..game6` (people and living bodies, voices, the material and prop libraries, guns, wonder weapons, world objects, arms, the match sounds and music), each 25-64 MB | 276.2 MB | |
| Map packs (each map's own scene, textures and beds): Crossroads 14.4, Kaltenbrunn 7.7, Totenhafen 28.9, Thalbach 22.0, Kranich 9.6, Groom Lake 14.4, Mondlicht 22.4 | 119.4 MB | |
| **Before the first match** (menu + all game packs + the map) | **420-441 MB** | |

How it loads: the page downloads the engine and the main pack (the loading bar), then shows the menu. While you
are in the menu the six game packs download in the background. When you pick a map, its pack downloads (8-29 MB,
Crossroads 14 MB) and the match starts; if the game packs are not finished yet, a progress bar shows what is
left. Everything is cached by the browser after the first visit (the file names carry a hash, so a new version is
always fetched fresh and an old one never sticks).

**Running it yourself.** `tools/build_web.sh` builds `build/web/`; `tools/serve_web.sh` serves it on
http://127.0.0.1:8060/; `tools/deploy_web.sh` puts it on Vercel (one-time `npx vercel login`; set `CZ_PASSWORD`
in the Vercel project to put the site behind a password; without it the site is open).
