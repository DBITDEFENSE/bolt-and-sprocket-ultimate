# GRAVELIGHT progression: rank, the Muster, Field Habits

Out-of-match character improvement (DECISIONS T-079). The older meta systems (rank 1-60, Commendations, dossiers,
weapon mastery camos, challenges, the Intel Archive) are in `gravelight/autoload/profile_save.gd` and
`data/gravelight/progression.json` (GDD section 16). This page covers what T-079 adds on top: **the Muster**, the
kit a survivor brings into a match.

## Names

- **The Muster**: the screen and the system. A muster is the roll call and kit check before a unit moves out. Main
  menu > *Muster (rank, sidearm, Field Habits)*; also Play > (survivor) > *Muster: ...*, and the co-op lobby.
- **Sidearm**: the pistol you start with (instead of always the M1911).
- **Field Habits**: small, permanent-for-the-match advantages "a soldier brings from the line". Deliberately not
  "perks": the perk tonics (Ironhide Stout, Second Wind Schnapps, ...) are bought from machines during a match and
  lost when you go down; Field Habits are chosen before the match, never bought and never lost. They also do
  different things from the tonics (Scrip, ammo, grenades, the knife, boards, timers), and are much smaller.
- **Habit slots**: how many Field Habits you can carry: 1 at rank 1, 2 at rank 10, 3 at rank 25.

(Survivor *traits* — Dutch's melee, Peg's grenade, Deacon's repairs, Wren's headshot Scrip — stay as they were:
fixed per survivor. The Muster is per survivor too: each of the four keeps their own sidearm and habits.)

## How it works

- Data: `data/gravelight/muster.json` (sidearms, habits, slot table, every number). Code: `gravelight/player/muster.gd`
  (`Muster`, static). Screen: `gravelight/ui/menu_muster.gd` (`MenuMuster`).
- Saved in the profile: `profile["muster"][<survivor>] = {"pistol": id, "habits": [ids]}`, profile **v3** (the
  v2 -> v3 migration gives every survivor the M1911 and no habits). Changes save immediately.
- Unlocks: each sidearm and habit has an `unlock` list; **any** condition unlocks it: `rank`, a career `stat`
  (e.g. 150 boards), `challenges` completed, or this survivor's `dossier` level. A Commendation (prestige) resets the
  rank but keeps every Muster unlock and all three slots. Rank-ups list what they opened on the game-over screen
  ("Sidearm: Walther P38", "Field Habit slot 2").
- Match start (`MapRoot._ready`): `Muster.begin_match()` fills `Muster.match_kits` (player id -> kit) before anyone
  spawns. Solo: the local human (id 1) from the saved profile, so **every way into a match uses it**: Play, the
  campaign, and the dev launcher's map buttons (they go through MapRoot). Bots and Jakub get no kit (their own
  default kit). The **player-bot agent** (F6, T-071) drives the human's own Player, so it plays the human's Muster.
- Co-op: each peer sends its four survivors' loadouts to the host at join (`Net._rpc_kits`, after the hello) and
  again after editing them in the lobby (`Net.send_kits`). The host checks them (known sidearms and habits, at most
  3 habits; it trusts the peer's rank), keeps them in the roster and shares them; host-authoritative effects (Scrip,
  boards, ammo prices) read them from `match_kits` on the host.
- **Classic Rules** (Settings) turns the Muster off as it turns the survivor traits off: plain M1911, no habits.
- The M1911's own meta (its finishes and the one-attachment *Loadout Pick*, Settings > Gameplay) stays M1911-only.
  The Armorer's Bench works on every sidearm (the generic pistol table; the Webley swaps the extended magazine for a
  speedloader).

## Sidearms

All are sidegrades of the M1911 at round 1 (round-1 DPS within 10%, one headshot still kills a round-1 zombie, about
the same total damage carried; tested in `test_muster.gd`). Each has a Crucible version. They are not in the crate
and not on walls. They don't count toward the Nachtglas meta camo (`muster_sidearm` in weapons.json).

| Sidearm | Unlock | Damage / mag / reserve / rpm | Reload (partial / empty) | Character | Crucible |
|---|---|---|---|---|---|
| M1911 | always | 40 / 8 / 80 / 450 | 1.4 / 1.8 s | the all-rounder; finishes and Loadout Pick | Last Rites |
| Walther P38 | rank 4 | 38 / 8 / 88 / 480 | 1.25 / 1.6 s | quicker follow-up and reload, tighter hip fire | Vespers (semi / 3-round burst) |
| Webley Mk VI | rank 8, or the survivor's dossier level 4 | 70 / 6 / 48 / 260 | 2.3 s (break-open) | nearly twice the hit, through one zombie, no brass | Mourner's Six (stagger) |
| Luger P08 | rank 14, or 4 challenges done | 38 / 8 / 80 / 420 | 1.55 / 1.95 s | fast to aim (0.12 s), tight ADS, damage carries further | Requiescat (6x headshots) |

Models are procedural (`WeaponModels._w_walther_p38 / _w_luger_p08 / _w_webley`), in the M1911's style, real scale,
no markings.

## Field Habits

| Habit | Unlock | Effect (`effects` key) |
|---|---|---|
| Pay Packet | rank 1 | +250 Scrip at the start of the match (`start_scrip`; not again on a campaign arrival) |
| Whetstone | rank 1 | knife / melee damage +25% (`melee_damage_mult`) |
| Full Haversack | rank 2 | your sidearm starts with +50% reserve ammo, also on a co-op respawn (`start_reserve_mult`) |
| Grenade in the Boot | rank 5 | start with 3 frags instead of 2 (`start_grenades`) |
| Carpenter's Pencil | rank 6, or 150 career boards | +5 Scrip on every board that pays (`board_scrip`) |
| Field Dressing | rank 7, or 25 career revives | bleed out 15 s later when downed with a squad (`bleedout_bonus_s`) |
| Cool Head | rank 10 | health regen starts 25% sooner after a hit (`regen_delay_mult` 0.75) |
| Spare Record | rank 12, or 3 challenges done | start with one Siren Gramophone (`start_tactical`) |
| Quick Holster | rank 15 | swapping to your pistol is 35% faster (`pistol_draw_mult` 0.65) |
| Long March | rank 18, or 300 career rounds | sprint lasts 25% longer (`sprint_duration_mult`) |
| Scrounger | rank 21 | ammo boxes cost you 15% less (`ammo_price_mult` 0.85) |
| Steady Hands | rank 28, or 100 career revives | reviving a teammate takes 20% less time (`revive_time_mult` 0.8) |

Slots: rank 1: 1, rank 10: 2, rank 25: 3 (`slots` in muster.json). XP to rank 10 is about 12,700 (three or four
decent matches), rank 25 about 78,000.

### Adding a habit or a sidearm

A habit is a row in `muster.json` with an effect key a hook already reads; a new kind of effect needs one
`Muster.value(pid, "<key>", default)` / `Muster.mult(pid, "<key>")` call where it applies. A sidearm needs a
weapons.json row (class `pistol`, `muster_sidearm: true`, an `upgraded` row), a model builder `_w_<id>` (and the id
in `WeaponModels.known_ids`), a bot tier in `data/gravelight/ai/economy.json`, and a row in `muster.json`.

## Hooks (where each effect is read)

| Key | Where |
|---|---|
| sidearm, `start_reserve_mult`, `start_grenades`, `start_tactical` | `WeaponHolder._set_start_loadout` (+ `Muster.apply_start_kit`), the last-stand pistol |
| `start_scrip`, `bleedout_bonus_s` | `MapRoot._ready` after `Economy.reset` (`Muster.apply_match_start`) |
| `melee_damage_mult` | `WeaponHolder._melee_strike` |
| `pistol_draw_mult` | `WeaponHolder._select` |
| `regen_delay_mult`, `sprint_duration_mult` | `Player` |
| `board_scrip` | `Barricade.repair_board` |
| `ammo_price_mult` | `AmmoBox.quote` |
| `revive_time_mult` | `RevivePoint.hold_time` |

Tests: `gravelight/tests/unit/test_muster.gd` (rules, migration, effects at spawn), the smoke
`gravelight/tools_src/smoke_muster.tscn` (Map 0 started like the launcher with a saved loadout, a bot and the
player-bot agent).
