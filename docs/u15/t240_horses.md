# T-240: a rideable horse on the Inn, and the undead horses of rounds 20 and 30

The owner: "also add a rideable horse in map 1. but also add boss zombie horses on round 20 and 30." ("Map 1" is the
Inn, `map00`.) One horse model and one set of gaits, built in code, used twice: the carters' Noriker tied in the yard,
and the same horse long dead as a boss. Branch `worktree-agent-a59fdef82608f9de3`, based on `claude/boss-rework` at
e31a4e92 (the worktree was cut from `master`, which has no ladders, zip line or boss kit; it was fast-forwarded to the
lead's branch before any work, see section 9).

## 1. The model and the gaits (our own work, in code)

- `gravelight/world/horse/horse_mesh.gd` (`HorseMesh`): one skinned mesh per look, built once and cached. The barrel,
  neck and head are lofted from egg-shaped sections (narrow over the spine, full in the belly; 12 sections for the
  barrel, 7 for the neck with a crest, 8 for the head with a deep jaw); each leg is one loft through its joints (shoulder,
  elbow, knee, fetlock, coronet for a fore leg; hip, stifle, hock, fetlock, coronet for a hind leg) with a hoof under it;
  the mane is two continuous sheets draped from the crest (long on the off side, shorter on the near side, a ragged
  lower edge) with a forelock; the tail is a tapered loft with strand cards that end at their own lengths. Every vertex
  is weighted to the 34 bones the rig poses. 1.6 m at the withers, 2.6 m from the nose to the quarters, about 2.2 m to
  the ear tips. Vertex colours shade the coat (a paler belly, black points, a blaze, a dark muzzle).
  - look `noriker`: a heavy dark bay with black points and a blaze, feathered fetlocks, a saddle with a pommel and a
    cantle on a loden blanket with a dull red edge, flaps, a girth, stirrup leathers and irons, a bridle (noseband,
    browband, headstall, cheekpieces, bit rings) and reins back to the pommel.
  - look `dead`: the same sections drawn in (the belly tucked up, the flanks fallen in, the neck thin), a dark dry hide,
    18 ribs standing as bars over the flanks, the spine's knuckles, the points of the hips, gaps in the hide between
    ribs (three on the near flank, one on the off flank) with a core of Nachtglas behind them, the muzzle bare bone
    from a ragged edge down, the lower jaw two bare bars with teeth on its own bone, dark sockets with the violet in
    them, the off ear torn short, the mane in hanks, the tail a dock with strands, rags of hide under the neck, a
    draught collar with iron hames whose knobs stand over the withers, a back strap, a belly band and trace chains
    along the flanks.
- `gravelight/world/horse/horse_gait.gd` (`HorseGait`, pure): the walk is a four-beat lateral sequence (left hind, left
  fore, right hind, right fore; never fewer than two feet down), the trot two-beat on diagonal pairs with a suspension
  between the beats, the gallop a four-beat transverse gallop with all four feet off the ground for a fifth of the
  stride. A hoof in stance travels back at exactly the body's speed (no sliding), a hoof in swing comes forward on an
  arc. The body's rise, pitch and roll and the head's nod are functions of the stride phase per gait. Gait changes
  have a hysteresis band.
- `gravelight/world/horse/horse_rig.gd` (`HorseRig`): a flat `Skeleton3D` posed every frame; nothing is a clip. Legs
  are solved from where each hoof is in its stride (two-bone IK for knee and stifle, the hock and the pastern by
  phase), the body rides the gait, the neck bends into a turn and the head keeps its face, the ears flick and pin, the
  tail hangs on a spring that lags the turn and swishes, the mane sways, a standing horse shifts its weight and rests
  a hind foot. Poses the owners set: `head_low`, `alert`, `ears_back`, `rear`, `kick`, `paw`, `jaw`, `wrong` (the dead
  one's crooked neck), `shy`, `stagger`, `collapse` (onto the knees, then over on its side: the boss's death; no
  ragdoll). It announces every hoof that lands (`hoof(leg, at, gait)`), which drives the sounds.
- Sounds, synthesized with the boss pack's method (`gravelight/tools_src/gen_audio_horse.py`, importing
  `gen_audio.py` and `gen_audio_bosses.py`; no recordings): 16 keys / 37 files in `gravelight/audio/horse/`.
  Living: `horse_hoof_snow`, `horse_hoof_wood`, `horse_hoof_stone`, `horse_snort`, `horse_blow`, `horse_neigh`,
  `horse_tack`. Undead: `horse_boss_hoof`, `horse_boss_scream`, `horse_boss_breath`, `horse_boss_snort`,
  `horse_boss_drag` (loop), `horse_boss_gallop_far`, `horse_boss_crash`, `horse_boss_whip`, `horse_boss_death`. The
  existing `horse_whinny` (the stable's ambience) is untouched; my first run overwrote it and was reverted, which is
  why the living whinny is `horse_neigh`.

## 2. The rideable horse (`gravelight/world/horse/horse.gd`, `horse_rules.gd`, `data/gravelight/horse.json`)

**Where.** `map00.json` "horses": `YardHorse` at (24.15, 0, 37.2) facing north, tied at a hitching rail at
(24.15, 0, 35.95) under the hoist ledge by the stable's south wall: east of the Thompson chalk (x 22), 5.6 m from the
zip line's landing post, 19.5 m from the tower ladder's foot, west of the snowed cart. `MapRoot` spawns it from data
beside the ladders and zip lines (`Horse.spawn_all`); `gen_map00.gd` is not touched and the navmesh is not re-baked.
The rail (two posts, a pole, a ring, a hay net, a bucket, a lead rope to the halter while it stands tied) has its
collider on the map-edge layer (bit 10): players and bots are stopped, zombies and shots pass, so it is never in a
zombie's baked path. The west post stands in the edge of the drift that lies along that wall.

**Controls.** Hold Use at it (0.4 s) to mount: a one-second climb (to the near-side stirrup, then up and over into
the saddle, the view leaning, both hands to the pommel). Mounted: forward urges it on (walk, trot, gallop: about 2.3 s
of held forward from a walk to a gallop; Sprint urges faster), no input lets it ease back to a walk on its own, back
reins it in to a stand (held at a stand it backs up at 1 m/s), left / right turn it. It answers like an animal: the
turn lags the rein by 0.28 s, it turns 1.5 rad/s at a stand and 1.0 at a gallop, and a hard turn brings a gallop down
to 6.4 m/s (a 5.8 m turning circle, which fits the yard's 14 m). Speeds 1.9 / 4.6 / 9.5 m/s (a player walks 4.5 and
sprints 6.8). The camera sits 0.8 m over the seat (the eye at 2.4 m) and rides the saddle (the trot's bounce, the
gallop's rock and a wider FOV); the rider turns with the horse and may look 2.2 rad either side of its nose. Hold Use
again, or press Jump, to get down (0.7 s) onto the first free spot of nine round the horse (floor under it, room for a
body, a clear line, inside the horse's ground). A prompt says so for the first seconds of the first three rides.

(T-262, 2026-11-22: the rider now shoots at a gallop too, and the horse can be fitted with tack; see
`docs/u20/t262_horse.md`. The paragraph below is how T-240 left it.)

**Shooting from the saddle: yes at a stand, a walk and a trot; no at a gallop.** `Player.carry_fire` (new, see
section 8) lets the carrier allow fire and ADS; the gait's own motion is the sway. At a gallop both hands go to the
reins at the pommel (`WeaponHolder.set_hands(&"climb")`, the existing two-hand mode) and fire is blocked. A true
one-hand-on-the-reins pose with the gun in the other is not built: the hands system has "both on the gun" and "both
off it", and adding a third state means editing `weapon_holder.gd`.

**Rules in a zombie game.** Zombies ignore it and cannot hurt it (no damage entry point, no hitboxes, off their
collision layers); there is no dead-horse scene. It counts the dead within 4.5 m five times a second: each one past the
first takes half a pace off its top pace (never under 1.4, so it always moves), at three it shies (the pose, pinned
ears, a snort). Within 14 m of a homage boss it will only walk and it whinnies. At 6 m/s or faster the first ordinary
zombie within 1.25 m of its chest is flung aside (7 m/s for 0.5 s; 90 damage where it lands, under a tenth of a round-20
zombie's health), the horse loses 35% of its speed and drops out of the gallop, and it cannot happen again for 0.7 s;
bosses, the Foreman and the Screamer are not shoved, nor one still rising or at a window. A rider can be hit (zombies
reach the saddle) and is put down beside the horse when downed or knocked down. Left alone for 25 s it walks back to
its rail along the navmesh and stands as it was tied.

**Where it may go.** Only its zones (`YARD`, and `GROUNDS` once the gate is bought), and only when the zone is open,
within 0.9 m above / 0.6 m below its rail's level. The check is on its body and on the end that leads (the nose going
forward, the quarters backing), so it stops a length short of a doorway. A step outside is refused (it is put back,
stops, snorts). So: not through the stable's 2 m door, not into the inn, not onto the tower, not down the well, not
past the map's edge. It does not jump; the yard's fences (2.3 m colliders) stop it.

**Co-op.** One rider. `HorseUse.interact` runs on the host (not `net_local`), which decides and mirrors `net_mount` /
`net_dismount` with `Net.mirror`. The rider's own machine moves the horse (as a ladder or a zip line moves its user);
every other peer puts the horse under the rider's replicated body and heads it where the rider goes. A riderless horse
walks home on every peer by the same rule. Bots never ride (`HorseRules.may_mount`), and the horse is in none of the
groups the bot code shops or interacts from.

## 3. The undead horses (`gravelight/enemies/homage/horse_boss.gd`, `horse_round.gd`, `data/gravelight/bosses/horse.json`)

**Data.** A map's json: `"round_bosses": [{"round": 20, "boss": "totenross", "count": 1}, {"round": 30, "boss":
"totenross_fuhrmann", "count": 1}]` and `"round_boss_arena": {"zones": [...], "arrive": [[x, y, z]], "exit": [...],
"centre": [...]}`. `MapRoot` attaches one `HorseRound` per row (`HorseRound.attach`). A map without the row has none.

**How the round runs.** There was a precedent, so it is followed: `HorseRound` is a `HomageEncounter` (PAUL's and the
Slender's shape). The round is reserved (no Bellringer round or Foreman on it; if one sits there the horse moves +1),
the horde keeps coming at 60% of the round's count, and the horse holds the round open until it dies or leaves. It is
heard first (hooves down the road at 0.5 s, the scream at 3.5 s) and comes in at 6 s at a gallop. The title card and
the bar show when it is within 30 m or after 7 s. Bots alone: the standard switch (half health, 0.6 damage, 1.3
cooldowns). Fail-safe: 300 s after the card it bolts back the way it came and returns two rounds later until killed.

**The fight.** Every attack is pose + sound + light for half a second or more (`tele_seconds` clamps the data) and has
a counter.

| Attack | Telegraph | What it does | Counter |
|---|---|---|---|
| Charge | 1.4 s (0.9 s for the second one): it paws, the head goes down, ears flat, the scream, the light rises | Runs its line at 13 m/s for the target's distance + 6 m (28 m at most). Anyone within 1.5 m of its chest: 80, thrown aside, knocked down 1.1 s. Zombies in the lane are flung. | The line is set at 70% of the wind-up: a side-step after that is a dodge (at the shortest range a walking side-step clears the lane with 4 m in hand). A wall, a cart or a trough in its way staggers it 2.6 s at x1.5 damage. |
| Stomp | 0.9 s: it rears, the scream | The fore hooves land 1.2 m ahead: 60 within 3.2 m (knocked down 1.0 s within 2.2 m), 30 out to 6.5 m for anyone on the ground. | Back out of the ring, or be in the air as the hooves land. |
| Kick | 0.5 s: ears flat, the head turns back, the tail lashes, a snort | Someone behind it (over 115 degrees off its nose, within 3.4 m) for 0.35 s: both hind feet into a 60-degree cone behind: 55 and thrown back 9 m/s. | Do not stand behind it; leave the cone. |
| Trample | 0.6 s: the head low, a snort, it walks on | Onto a knocked-down player within 9 m: up to three stamps of 30, 0.6 s apart. | A teammate's fire for 2.5% of its health, or one hit in the ribs, breaks it off; getting up and away ends it. Bleeding-out players are never trampled. |
| Whip (round 30, while the carter rides) | 0.7 s: the arm goes up, the whistle | A lash down a 1.2 m lane to 9.5 m: 35 and `whip_slow` for 2.5 s. | Step off the line; it does not reach past 9.5 m. |

Phases by health: 100% 4.2 m/s; at 66% "the traces burn": 5.2 m/s, cooldowns x0.85, the arena's lights to 70%, a
second charge straight after a charge that hit no wall; at 33% "it runs blind": 6.0 m/s (a sprint still outruns it),
cooldowns x0.7, lights to 35% so its own glow is the light, the stomp's outer ring 1.5 m wider. One explosive hit of
4% of its health staggers it 1.4 s.

Round 30 adds one thing: **the dead carter rides it** (a zombie body seated in the saddle, a wide hat, a whip). He
lashes until the horse is at half its health, then the horse rears and throws him; he gets up beside it as an
ordinary zombie of the round with four times its health, running, and is counted by the round like any other. A pair
of horses was the other option; one horse and a rider costs one rig and one zombie, and changes the fight at half
health instead of doubling it.

**Where it goes.** Only the arena's zones. A player elsewhere is not chased. With nobody in reach for 8 s it lays
siege: it screams and the dead within 45 m run (every 14 s), so hiding indoors is not free; the fail-safe still ends
it. Closed doors within 2.6 m on its way are broken open for free (as PAUL does).

**Numbers and why.** Health solo 46,000 (round 20) and 72,000 (round 30), x(1 + 0.75 per extra player). A round-20
zombie has 2,710 and a round-30 zombie 7,030; PAUL has 30,000 at round 15; the Foreman has 50,000 at round 20 and
75,000 at round 30. So the horse is worth 17 of its round's zombies at 20 and 10 at 30 (plus the carter's 28,120), sits
between PAUL and the Foreman, and has two weak points (the head x1.6, the lit gaps in the ribs x2.0) and a x1.5 window
every time it runs into a wall. Damage against 100 health (250 with Ironhide): no single hit downs a healthy player
(the worst is the charge's 80; round 30 is x1.2, so 96). Rewards follow PAUL's shape: 2,000 Scrip each and Resupply +
Double Scrip at round 20; 3,000 each and Resupply + Death's Door + Double Scrip at round 30; flags `totenross_down` /
`fuhrmann_down`. No unlocks or intel were added (those need the Archive's rows and VO).

**The living horse and the dead ones.** The boss's body collides with the world and doors only, so it runs through
neither the living horse nor its rail; it never targets it. The living horse shies (walk only within 14 m).

**Presentation.** The framework's own body is hidden and its limb boxes replaced by ten on the horse (head, neck,
two torso, two rib gaps as the weak point, four legs). It uses the kit only through public calls: `fx.tele` on every
telegraph, `fx.stomp` from the real hoof falls (heavier at a gallop), `fx.shake_all`, `fx.lights_dim` /
`lights_flicker` / `lights_restore` on the phases and at the death, `BossFx.emitter` (steam at the nostrils on each
breath, motes from the ribs from phase 2), `BossFx.burst`, `fx.extra_dread` while a telegraph runs, hit feedback
through `_on_damaged` (super called), `death_burst` from the base. A violet light rides in the ribcage (`no_dim`). It
drags a broken shaft by a trace (a body following the hip on a fixed length of chain) with a drag loop that rises
with its speed. Death: down on the knees, over on its side, the light fading.

## 4. Which maps are on

- **Inn (`map00`): on.** Zones `YARD`, `GROUNDS`, `STABLE`. It comes up the carters' road at (18, 0, 57) and breaks
  the yard's gate open if it is still chained. Not the taproom, the stairs or the cellar: the navmesh is baked for a
  0.5 m agent and the doors are 2.0 m by 2.4 m, which a horse's 0.8 m barrel passes, but a 2.6 m body among the
  taproom's tables, on a staircase or at a hatch is not honest.
- **Kaltenbrunn (`map01`): on, surface only.** Zones `A_MINEHEAD`, `B_RAILYARD`. Same 0.5 m agent and 2 m doors; the
  lift cage, the stairs and the galleries are excluded. It comes in at the point of those zones farthest from the squad
  (40 m in the smoke) and paths to the Minehead Yard. Players who go below are besieged, not followed.
- **Every other map: off.** One "round_bosses" line (and an arena) turns it on.

## 5. Decisions taken

1. The worktree was moved from `master` to `claude/boss-rework` before work (section 9).
2. Model in code, not Blender: one file builds both looks, the rig needs no clips, and nothing is imported.
3. The horse stands east of the Thompson chalk, not at the wall's middle: x 16..20 is the carters' track and the zip
   line's landing, x 22 is a wall-buy, x 11..16 is a zombie window and the woodpile.
4. The horse's and the rail's colliders are on the map-edge layer, so nothing baked changes for zombies.
5. Firing from the saddle at a trot or slower; both hands on the reins at a gallop (section 2).
6. No input eases the pace to a walk, not to a stop (stopping takes the reins).
7. A rider knocked down by a boss is unseated, as a downed one is.
8. The trample credits the rider and costs the horse its gallop; zombies that cannot be flung cost nothing.
9. The boss follows the `HomageEncounter` precedent rather than "one third into the round's spawns".
10. Round 30 is one horse with a rider, not a pair.
11. The boss stays out of rooms a horse does not fit and lays siege instead.
12. It breaks closed doors on its way (the yard gate, the stable's doors), as PAUL does.
13. `horse_neigh` for the living whinny (the bank already had `horse_whinny`).
14. `round_bosses` rows are read by a new director attached from `MapRoot`, because `zombie_director.gd` (where the
    other encounters are made) is on the do-not-touch list.
15. Data tables are loaded by `HorseRules.table()` / `HorseBoss.table()` rather than added to `GLData.TABLES`, to keep
    `data.gd` out of the diff.

## 6. What the bots need (not edited: `gravelight/bots/` is another worker's)

- They already count it a boss and shoot it (`BotPerception.is_boss` is true for any `HomageBoss`).
- While a charge, a stomp, a kick or the whip winds up, the boss posts its lane or disc to the squad's danger map
  through the public `BotBlackboard.add_danger` (the call the vacuum uses), cost 6, refreshed every 0.25 s. The smoke
  reads 12.0 in the lane and 0.0 beside it. Whether a bot leaves the lane in time depends on how the brain weighs a
  cost-6 zone against its current task: **not measured**.
- Suggested, for the bots' owner: `ai_counters` rows for `totenross` and `totenross_fuhrmann` (`boss: true`,
  `keep_distance_m` about 7 so they stay out of the stomp, `focus_when_vulnerable` so they pour fire in during a wall
  stagger, where `damage_taken_mult()` is 1.5); a rule to aim at limb `back` (the rib gaps, x2); and "never stand
  behind it" if the brain has a flanking habit.
- Bots do not ride: `may_mount` refuses them and nothing in the bot code looks for the horse.

## 7. What I need from the kit (worked round in the subclass; nothing in the kit was edited)

- `BossFx.tele` drives `_tele_light`, but `HomageBoss._physics_process` also eases that light toward `_tele_glow()`
  every frame; `HorseBoss._tele_glow()` returns the light's own energy so the kit's shape survives. A flag on the base
  ("the kit owns the light") would be cleaner.
- The telegraph light hangs on the framework body's chest attachment; the horse re-parents it to its own neck.
- `HomageBoss._footstep` fires the kit's footfall from the framework body's (hidden) feet; the horse overrides it to
  nothing and calls `fx.stomp` from its own hooves.
- `HomageBoss._update_audio` plays the Cousins' hum; overridden to nothing.
- A co-op client still sees the framework's generic puppet for every homage boss, so a client would see a zombie
  where the horse is. That is the existing limit of the framework, not new, but it is worse for a horse.

## 8. Every edit outside my own new files

| File | Edit |
|---|---|
| `gravelight/player/player.gd` | 7 lines: `var carry_fire: bool = false`; `"fire_block"` and `"mantle"` in `_gather_intent` read `carry != null and not carry_fire` instead of `carry != null`; `begin_carry` and `end_carry` reset it to false. Nothing in the movement code. |
| `gravelight/player/move_intent.gd` | none |
| `gravelight/maps/map_root.gd` | 2 lines: `Horse.spawn_all(self, map_id)` after `ZipLine.spawn_all`, `HorseRound.attach(self)` before `LazarusCinema.attach`. |
| `data/gravelight/map00.json` | appended keys `horses`, `round_bosses`, `round_boss_arena` (63 lines at the end). |
| `data/gravelight/map01.json` | appended keys `round_bosses`, `round_boss_arena` (25 lines at the end). |
| `data/gravelight/audio.json` | 200 lines appended as one block at the end of `sounds` (16 `horse_*` keys); nothing else changed. |
| `data/gravelight/capture_cams.json` | one set appended at the end of `sets`: `u15_horse` (17 cameras). |

Not touched: `gen_map00.gd`, `boss_fx.gd`, `dread_fx.gd`, `homage_boss.gd`, `gravelight/enemies/zombie*.gd`,
`gravelight/bots/`, `data.gd`, PROGRESS, DECISIONS, `morning/*.md`.

New files: `gravelight/world/horse/` (5 scripts), `gravelight/enemies/homage/horse_boss.gd`, `horse_round.gd`,
`data/gravelight/horse.json`, `data/gravelight/bosses/horse.json`, `gravelight/audio/horse/` (37 ogg),
`gravelight/tools_src/gen_audio_horse.py`, `horse_shots.gd/.tscn` (a turntable for the model, seconds to run),
`smoke_horse.gd/.tscn`, `smoke_horse_boss.gd/.tscn`, `gravelight/tests/unit/test_horse_gait.gd`,
`test_horse_boss.gd`, this file.

RESULTS_PLACEHOLDER
