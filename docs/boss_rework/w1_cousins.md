# W1: THE COUSINS reworked (T-232 draft for DECISIONS; docs/BOSS_REWORK.md 4.1)

Branch `w1-cousins` (from `claude/boss-rework` at 5c4987bb, the shared kit). Files: `gravelight/enemies/homage/cousin_hammer.gd`,
`cousin_reach.gd`, `cousin_alix.gd`, `cousins_round.gd`, `data/gravelight/bosses/cousins.json` (version 2),
`gravelight/tools_src/smoke_cousins.gd`, `gravelight/tests/unit/test_homage_cousins.gd`, the `u14_cousins` key in
`data/gravelight/capture_cams.json`, `docs/HOMAGE_BOSSES.md` section 4 (in place), this file.

**T-232, 2026-11-10: the Cousins reworked (W1 of the boss rework; the owner: "make their models and effects better,
make them scarier").** The doll register was pushed with the kit's helpers on top of the modelled doll bodies
(`PeopleBodies "cousin_*"` stay): a porcelain glaze shell on the face (a thin glossy alpha shell, roughness 0.05),
glass eyes that catch the light (`eye_glow`, a pale cold glint; the Hammer blinks every 9 s, the Reach every 7 s, Alix
never), and hairline cracks that spread as a cousin takes damage: three tiers of `cracks()` on the head and both arms,
hidden until her HP falls under `crack_tiers` 0.75 / 0.5 / 0.25, each opening with `boss_doll_crack` and chips off the
limb that was hit; death opens every crack. The Hammer's braid is three blonde `strips` from the nape that swing with
her skip and whip round on the throw's spin; the maul head now scrapes a `sparks` emitter off the floorboards while she
drags it. The Reach's stretched arms carry dark red veins (`cracks` in red along the stretch below the elbow) that
widen x1.5 when she enrages, the sleeve torn only at the elbow as short flannel strips, and her breath frosts in the
cold taproom (a `frost` emitter with `boss_breath` every 3-5 s). Alix's ribbon has two swinging tails from the bow and
Nachtglas `motes` rise off the Third Hand whenever it opens for someone (the hold's telegraph and the hold, always
once she drips); she rises from the hatch in dust and old ice (`dust` + `frost` bursts). Silhouettes, clothing and the
Likeness Sheet are unchanged; nothing is framed below eye level.

Effects: every cousin has a `dread` block (surface porcelain, radius 18 / 18 / 20 m, near 5 / 5 / 6 m; the Hammer's
footfalls shake 0.08, the Reach's 0.05, Alix none: her steps make no sound). Every telegraph goes through `fx.tele`
(the base's `_tele_glow` is overridden to return the light's own energy so the kit owns the light's shape; the
weak-point flash still works). Every generic sound is replaced: `board_slam` / `grenade_explode` / `knife_swing` /
`zombie_gib` / `zombie_sprint` / `powerup_expire` are gone from the Cousins' files. The pack on every move: the giggle
stopped short (`boss_doll_giggle`, cut at 0.32-0.5 s) on the Hammer's catch and her hurt-player pick and on every grab
that lands; `boss_doll_crack` on each crack tier, each enrage, each death; `boss_hum_wrong` as a positional loop
replacing the shared hum once a cousin is enraged (stopped dead for the throw's beat and the hold, like the hum was);
`boss_bone_crack` on the Reach's coil, shoot, retract and window punch, the Hammer's haft creak, Alix's Lash whip;
`boss_breath` for the Reach's frost, the Hammer's pre-spin breath, Alix's held breath before the Lash, her kneel, and
the lamps' breath-out in the setup; `boss_hit_iron` for the maul banking off a wall and off the vestibule wall in the
tumble; `boss_stomp` for the maul into the floor (the Split), the door, the dropped maul and the hatch; `stable_creak`
(a world sound that fits) for the boards creaking under Through-the-Wall and at the window. The kit's `lights_dim` +
`lights_flicker` gutter the lamps near a cousin for a breath when she enrages, when Alix rises from a grief and when
she emerges (only before any death), and for the dark hunt's start. Light ownership: the kit captures a lamp's
*current* energy as its base and writes it back on `lights_restore`, so every cousin flicker restores itself 0.1 s
after it ends (`_flicker_room`), the enrage flicker runs *before* the round relights the next group, and the dark hunt
restores the kit's capture before the round's own lamp code takes the lamps out; otherwise a cleanup 12 s after the
round would have put relit lamps out again.

Battle (every v1 move, telegraph, break-free, the enrage chain and the 6:00 fail-safe kept; every v1 number
unchanged; everything below is additive, in `cousins.json` v2): **the dark hunt** (`dark_hunt`: after 3.0 s,
flicker 1.6 s): the lamps still come back one group per dead cousin, but 3 s after the second death the last cousin
standing puts them out again: the lit lamps gutter, every group goes out and only the hearth relights (to its base);
she hunts in the dark until the clear relights everything, each with her own moving light (the maul head's violet
glow, the Reach's wrist glow, Alix's drip) and `extra_dread` 0.25-0.3 on the kit. **The Hammer** picks the one who is
bleeding (`hurt.fraction` 0.5): the Mallet Throw aims at the most hurt player in range with a clear line instead of
the nearest; her locked head turns to them first and a short giggle comes with the wind-up, so the tell stays fair.
Her enraged Ricochet (two banks) was already built; the banks now ring iron with sparks. **The Reach** grabs
through a boarded window (`window`: telegraph 1.0 s, near_window 4.5 m, min_dist 7 m, arm speed 20 m/s, drag 2.0
m/s, crush at 1.4 m, 1 board torn, cooldown 14 s / 10 s enraged): when the target stands by a boarded window of their
zone and she has no line to them (or is 7 m+ off), the boards creak twice and rattle in their frame under a violet
glow outside the glass, then her arm punches through from outside, tears a board, takes the player and drags them to
the sill for the Hug-Crush; the same breaks as the Long Reach (its wrist is a weak-point hitbox the bots shoot). Her
squad rule (`lone`): a lone player (one on their feet) is held 4.5 s instead of 6 and dragged at x0.8, so the solo
break stays fair, while her walls come alive sooner (Through-the-Wall cooldown x0.7). **Alix** hesitates longer and
hits harder: the grief window is `seconds + seconds_step x (dead - 1)` (3.0 s, then 4.5 s) and every rise adds
`damage_step` 0.15 to all her hits on top of her double damage (swipe 100 -> 115 -> 130). Her squad rule (`step`):
inside her 8 m walking band a player who turns their back on her (over 100 deg) for 0.6 s hears the dress rustle and
she takes a step, a 0.45 s glide at her unseen speed that stops 2.6 m short (outside her 2 m grab: no step chains
into a grab), no damage, 5 s cooldown. HOMAGE_BOSSES 1.2 holds: modest clothing intact, no suggestive framing,
deaths authored (the sit-and-topple, the reach, the fist), dismemberment untouched.

Verification (headless, in the worktree): check_scripts 880 scripts / 0 failed; smoke_cousins PASS, 90 checks (69 in
v1 + 21 new: the kit on the Hammer, the modelled doll with its tiers, a crack tier opening, Through-the-Window with
the creak, the torn board, the held player and the wrist break, the arm withdrawing, the frost breath, the look-away
step and that it never steps into a grab, the death opening every crack, the harder hits after the first rise, the
flat hum loop playing on the enraged Reach, the longer second grief window, the dark hunt with the lamps out again
and the hearth relit), no forced moves, no script errors; GUT test_homage_cousins 34 / 34 (198 asserts; 25 v1 tests
+ 9 new pure-rule tests: dread blocks, crack tiers, the hurt pick, the lone grab terms, the window rule, the grief
length and damage, the look-away rule, the dark hunt trigger and its scheduling), test_boss_fx 4 / 4 (152),
test_map00* 7 scripts, 60 / 60 (1149). A worktree note for the lead: a fresh `git worktree` has LFS pointers, not
files, and the first headless import writes `valid=false` into ~2900 git-ignored `.import` files, which later import
passes never retry; `git lfs checkout`, `git checkout -- assets` (the tracked `.import` files), deleting the
`valid=false` ones and three more passes made the worktree whole (9574 imported). Renders: `u14_cousins` (7 cams,
WSL, Compatibility renderer with the light-cap `override.cfg`) in `morning/screenshots/u14_cousins/w1/`; what the
frames showed is in the report and below.

Open issues / for the lead: (1) `HomageBoss.take_damage` still plays `impact_flesh` on every bullet (base class, not
mine); the kit's porcelain hit plays over it, so the Cousins sound right but the flesh thud is under it; drop it for
`surface != flesh` in the base. (2) Sound ids I would like in the pack (I kept the nearest fit meanwhile):
`boss_maul_scrape` (a loop: the maul head dragged over floorboards; now `board_place` -12 dB), `boss_maul_bank` (iron
off plaster; now `boss_hit_iron`), `boss_wood_split` (the Split's floorboards; now `boss_stomp` + `boss_bone_crack`),
`boss_boards_creak_1..2` (a barricade's boards bowing; now `stable_creak`), `boss_dress_rustle_1..2` (Alix's only
sound; now `boss_breath` at -16 dB), `boss_doll_clap` (the setup's clapping upstairs; still pitched `knife_hit`),
`boss_hatch_creak` (the ice cellar's lid; now `door_creak`). (3) The Window Spider, the ceiling crawl, the arm sever
and the Kinderhammer drop stay stubbed as in HB1. (4) Co-op clients still see the puppet body (HB1 note).
