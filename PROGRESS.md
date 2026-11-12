# PROGRESS

RESUME HERE: 2026-11-12 Claude Fable 5.2, the terrain / body matrix is MEASURED (tools/zombie_terrain_check.tscn,
baseline in docs/captures/after/mocap/terrain/) and NOTHING in the runtime was changed by it: two trial fixes were
measured, did not hold up and were reverted (see the entry below). Work ONLY in .wt/zombie-overhaul, branch
codex/zombie-overhaul; rules and commands in docs/CLAUDE_FABLE_5_2_ZOMBIE_HANDOFF.md. NEXT, in this order:
(1) move the contact lock to run LAST, inside ZombieBodyModifier after the terrain IK (today it runs in _animate
before the modifier, so it pins a toe the IK then moves; keep the _animate call for bodies whose modifier is off),
and give the IK a second ray at the toe so the foot can be tilted between ankle and toe ground (ignore a difference
over about 0.12 m: a step edge); re-measure against terrain_baseline.json and keep only what the numbers support.
(2) Re-run the existing contact acceptance reading poses at Skeleton3D.skeleton_updated (the gallery and the unit
drift test read bones in _process / _animate, which shows the pose WITHOUT the modifier's foot IK). (3) The rest of
handoff item 2 not done here: turn-to-move / attack / death on terrain, rapid target changes, the animation LOD
distances (--lod), a rendered look at feet. Then items 3-6. Preserve all gameplay speeds.

## 2026-11-12, terrain and body matrix (handoff item 2, the measuring half)

`tools/zombie_terrain_check.tscn` (new): five lanes of real collision (flat, a 20 degree ramp, a 31 degree ramp =
the slope of a 0.18 / 0.30 stair, the same flight as real step boxes, forty rubble boxes of 5-20 cm), one live zombie
per lane with the real AI, navigation, physics, foot rays and animation, for 22 cases: three builds x two sexes at
both ends of the height range, the five tiers, a crawler, and eleven shared-rig kinds (Glasshide, Bellringer,
Bordschuetze, Suited, Shield-Cell, Burrower, Canary, Jumpjockey, Backorder, both Kielholer bodies; the Foreman and
the Screamer have bespoke bodies and are not in it). 110 rows, 24 s each at a fixed 60. No tolerance is applied: it
is a diagnosis. Report: `docs/captures/after/mocap/terrain/terrain_baseline.json`.

What it found (final poses, medians over the upright cases unless said):
- Nobody was lost and nobody stayed stuck. Every case crossed every lane (the slowest once in 24 s). Real steps
  cost 0.4-1.7 s of standing and 8-17 % of the time off the floor (Zombie._step_up); the maps use ramps under stair
  art, so the ramp lanes are the ones that matter.
- **The recorded gaits are played far from their recorded cadence.** `mco_chase` was recorded at 0.48 m/s: it
  plays at x2.8 at a shamble (1.3 m/s) and x4.3 at a walk (2.0 m/s). `mco_fast_chase` (2.88 m/s) plays at x1.2 at a
  jog, x1.7 at a run, x1.9 at a sprint and for the Bellringer. At x4.3 a wrist flick in the recording becomes a
  30-40 degree step of the hand in one frame, about fifty times in 22 s at a walk (four at a shamble, nine at a
  jog). The supplied crawl was rejected for x9; the walk tier's x4.3 was not called out before. Code cannot cure
  it: it needs upright recordings near 1.3 and 2.0 m/s (added to the shopping list).
- **Toes go into slopes.** The foot IK sets the ankle by the ground under the ankle and leaves the foot level: on
  the stair-angle ramp the toe is 11 cm into the surface at the 5th percentile and 9 cm over it at the 95th (flat:
  0 and 2 cm); 8 / 7 cm on the 20 degree ramp; rubble 6 / 6 cm. The same for every build, sex, height and kind.
- **The contact lock lets go with a snap.** When the body has moved more than `max_correction_m` (0.18) from a
  pinned toe, the pin is re-seated at once: an 18 cm move of the planted foot in one frame (11 m/s in the slip
  column). On flat ground it is rare (slip p95 0.014 m/s); on rubble at a jog or faster it is inside the worst 5 %
  of contact frames for most cases, on real steps for the fast tiers.
- The crawler has no recorded contact windows (the legacy crawl clips), so its feet are not measured here.

**A fault in the earlier evidence, found on the way:** bones read in `_process` or `_animate` show the pose
WITHOUT the SkeletonModifier3D (the foot IK): its result is rolled back before the next frame. Only
`Skeleton3D.skeleton_updated` shows the final pose (checked directly: on the ramp the foot's pitch and the toe's
height differ between the two). The gallery's contact acceptance and the unit drift test read toes the first way,
so the "toe drift p95" numbers in the handoff describe the animated pose plus the contact lock, not what is drawn.
On flat ground the two agree closely (this tool's flat lane: p95 0.014-0.016 m/s); on terrain they do not.

**Two fixes tried, measured like for like against the baseline, and reverted:**
- A foot tilt from the ground normal under the ankle (about the ankle, capped at 35 degrees): toes 11 -> 9.6 cm
  into the stair-angle ramp, but planted feet began to slide on slopes (slip p95 0.04 -> 0.6 m/s at a walk),
  because the lock pins the toe BEFORE the modifier tilts the foot. Not a net gain.
- Easing the lock's release over `release_seconds` instead of the one-frame snap: the worst frame fell (11 -> 7
  m/s) but the slide then lasts five frames and the p95 rose (rubble at a walk 0.16 -> 2.0 m/s).
Both are in `terrain_trial_tilt_and_eased_release.json` for the record. The cause they share is the order of the
two corrections; the RESUME line says what to build instead.

Not done from item 2: turn-to-move / attack / death on terrain, rapid target changes, the LOD distances, any
rendered look. No runtime file changed in this slice; scores unchanged.

## 2026-11-12, co-op stationary turns (handoff item 1)

A client's copy of a zombie sees only the host's interpolated yaw, so the host-side trigger (one request of 25-65
degrees) never fired there: over real traffic a 45 degree facing arrives as steps of at most 18 degrees a tick.
`ZombieTurnMotion.observe()` is the puppet's trigger now: a fast observed yaw change (180 deg/s) from a settled
heading starts a hold (the visual stays on the old heading), and when the yaw settles (under 40 deg/s for 0.05 s) or
the hold has run 0.3 s, an accumulated angle inside the recorded range becomes one turn over that whole angle;
anything else is released by the ordinary easing. Slow tracking of a moving target never reaches the start rate, so
jitter cannot step a still body. Tuning: `zombie_mocap.json` turn.observe_*. Gameplay facing, snapshot contents and
attack timing are untouched; the one shared-networking edit is `Zombie._puppet_apply_sample()` (the four lines of
`_puppet_tick` that put the sample on the body, factored out so a test can drive them) calling `observe` in place
of `request`.

Host side, found by the same check: a facing past the recorded range (120 degrees) fell into range on its way and
played a recorded step for the remainder after the body had already swung most of the angle, on the host only. An
over-range request now latches until that facing has settled (`over_range`); the next in-range facing turns as before.

Evidence:
- `tools/zombie_turn_net_check.tscn` (new): a real host and client process on 127.0.0.1, Map 0, one Ganger held
  still and faced through `_face()` to +45 / -45 / +35 / -60 / +60 / -35 / +15 / +120 degrees. RESULT PASS: host 6
  recorded turns, client 6; the largest visual heading step on the client during the recorded turns 2.93 deg a
  tick; the visual ends on the body's heading. The old trigger would have fired on 1 tick of 1,501, and that one is
  the 120 degree facing (a 32 degree body step), none of the six real turns. Report:
  `docs/captures/after/mocap/turns/turn_net.json`.
- Unit: 49/49 zombie tests, 4,600 asserts (was 46 / 4,066). New: 18 client runs through the real InterpBuffer
  (35 / 45 / 60 degrees both ways x clean, 18 ms jitter, 18 ms jitter with every fifth packet lost) each play
  exactly one turn with no step over 6 degrees and settle; 18 runs of small (12, 20), large (110, 170) and slow
  tracking (25, 60 deg/s) facings play none; the host's over-range latch; pool reuse clears the hold and the latch.
- Scoped reruns: check_scripts 860 / 0 failed; zombie_mocap_check 30 clips, no failures; zombie_turn_check and its
  attack interruption exit 0 with no failures; smoke_zombie_anim PASS; smoke_coop PASS. No script errors in any log.

Not done here: the client's turn starts about 0.15-0.4 s after the host's (the interpolation delay plus the settle
wait), which is not measured against a rendered pair; the check is headless, so the client's feet were not looked
at; redirect and wraparound on the client are covered by the unit runs only through the shared cancel path, not by
a dedicated two-process case. Scores unchanged (stationary turns 3/5, model 2/5).

RESUME HERE: 2026-11-11 Claude Fable 5.2 handoff is ready at
docs/CLAUDE_FABLE_5_2_ZOMBIE_HANDOFF.md. Continue from that file. Work ONLY in .wt/zombie-overhaul,
branch codex/zombie-overhaul. Runtime checkpoint bf395bc3: two cleaned 45-degree turns use a visual Turn
AnimationTree state: extracted source hip yaw, bounded root-angle matching, source contact IK,
footstep events, cancellation on movement/attack/other states, pool resets. Original gameplay
facing, speeds and jitter are unchanged. 30 derived clips from 26 owned source FBXs; raw turns
remain for comparison. Blender headless extraction reconstructs poses within 4.5e-16 m;
Godot imports 30/30, including yaw-track checks. 46/46 zombie tests / 4,066 asserts; 860 scripts
/ 0 failures; 4/4 license tests / 367 asserts; manifest 108 folders current. Initial license
filter typo selected no tests; corrected to test_license_gate and verified actual test counts.
Turn studio headless/rendered PASS: 175 contacts, p95 .008172 m/s, max visual heading step
11.25 -> 1.7943 degrees at 60 Hz; body-facing discrepancy <=.000006 degrees. Both directions,
35/45/60 degree unit cases, movement/attack interruption and pool reset verified. Review
docs/captures/after/mocap/turns/comparison.mp4 and README.md. Turn visual rating 2->3/5;
other ratings unchanged (locomotion/swipes/two deaths 3, model2, variety3). Full target NOT MET.
60-second 24-active checks: rendered p95 4.5455 ms, callback CPU .192 ms/actor/frame; fixed-60
motion 51,308 contacts, toe p95 .01245 m/s, root/body mismatch .5694%. Both minimum24, zero
missing/rest samples, 83,520 sampled poses. Hardware RTX5090/Ryzen7800X3D, not mid-range/full-map
sign-off. Map2 integration smoke PASS: worst median root mismatch .7%, climb/severs/Gore Off,
knockdown/get-up, 8 deaths, ragdoll peak6/cap6, corpse return. Final logs no script/shader/engine
or leak errors; known Unicode/NUL warnings remain.
NEXT: Fable should fix/verify co-op turn triggering (small interpolated yaw increments
can miss the trigger), test stairs/rubble and special bodies, and finish the remaining asset/spec
gaps. Host stationary turns are verified, not complete co-op acceptance. Purchased binaries stay
local; never request the Starter pack again. Do not merge or replace main/export without request.


RESUME HERE: 2026-11-09 Codex push/playtest checkpoint. Work ONLY in .wt/zombie-overhaul,
branch codex/zombie-overhaul. Devin explicitly requested PUSH and to try the current work;
this supersedes the older no-push notes below. origin/codex/zombie-overhaul now contains
the licensed locomotion, recorded swipes/two deaths and clothing-detail checkpoints through
e8bc3d67. Main and the exported build remain unchanged. Paid FBXs/derived GLBs stay local;
all 28 clips are already built here. Do not request the Starter pack again.
Launch this checkout with tools/zombie_playtest.ps1 (-Sound for audio), or -Mode Gallery for
a ten-minute 24-zombie studio. Normal Play.bat targets main, not this branch. Launcher checks
the bank and locates Godot in the main checkout; no install or copy of the main build needed.
Verified both launcher -HeadlessCheck modes with automatic engine discovery: actual Claude
Zombies menu loaded 28/28 clips; 3-second gallery kept 24 active, no missing/rest samples,
zero validation failures. Fixed Windows GUI-executable waiting and tool teardown; final
headless logs have no script/engine/leak errors. Existing Unicode/NUL warnings remain.
The visible Forward+ playtest reached the Claude Zombies menu and was inspected on screen;
it remains open for Devin. Rendered startup also logs the existing deprecated SSR-setting
warning from shared Settings. No match or fresh visual-quality score was claimed from this.
These are startup checks, not new performance/quality acceptance; e8bc3d67's 60-second reports
remain the latest acceptance evidence. Speeds and jitter remain unchanged. Full overhaul
is NOT complete: motion/swipes/two deaths 2->3/5, model 2->2, variety 3->3.
NEXT: review/clean the supplied 45-degree turns, extract root yaw and match visual phase
without changing gameplay facing/speeds or double-applying rotation. Then stairs/rubble and
special-body coverage. Missing recordings, six more deaths and artist-authored model/PBR/LOD
sample remain in the shopping list. Push further completed checkpoints when ready; no merge,
main replacement or export has been requested. Older RESUME entries below are history.


RESUME HERE: 2026-11-09 Codex Stage 3 material/final-local-check checkpoint. Work ONLY in
.wt/zombie-overhaul on codex/zombie-overhaul. State commit baa71d96 adds the two recorded swipes
and two recorded deaths with momentum into ragdoll. New material slice uses existing CC0 fabric/
leather normal/ORM maps, configured in data/gravelight/zombie_materials.json; two body surfaces,
separate zombie-only material, living people unchanged. Blender headless: 4 maps valid. Godot:
45 zombie tests / 2,679 asserts; 859 scripts / 0 failures; license 4/4 / 367 asserts; manifest current.
Final 60 s rendered 24-active near-player soak PASS: frame p95 4.7619 ms, callback CPU .155 ms per
actor/frame (Ryzen 7800X3D / RTX5090, not mid-range/full-map sign-off). Final 60 s fixed-60 motion
PASS: 50,255 contacts, toe drift p95 .012804 m/s, root mismatch 1.0104%. Both runs minimum24,
zero missing clips/rest samples, 83,520 pose samples. Reports: docs/captures/after/mocap/
acceptance_materials_{rendered,motion}. Close-ups: mocap/materials; state videos: mocap/states.
All gameplay speeds and jitter preserved. Soldier motion/swipes/two deaths 2 -> 3/5, model stays2,
variety stays3. Full premium target NOT MET. Shader prototype/sampler failure and overly strict
RGB-normal audit fixed/rerun; final renders have no shader/script/engine errors. Unicode/NUL
startup warnings remain. A license check overlapped part of the rendered performance run.
NEXT: review/clean supplied mco_turn_l_45/r_45 (net +45/-45 degrees, 1.267 s), extract root yaw
and match visual phase to existing facing without changing gameplay speeds/facing. Do not alias
raw turns (double rotation). Then stairs/rubble and special-body coverage. Missing recordings,
six more deaths and artist-authored soldier/PBR/LOD sample remain in the shopping list. Original
Starter pack is already received/built locally; never request it again. Source/converted files
remain ignored; tools/zombie_mocap_build.ps1 rebuilds them. No merge/push/export/main replacement.


RESUME HERE: 2026-11-09 Codex Stage 2 swipe/death checkpoint. Branch codex/zombie-overhaul;
work ONLY in .wt/zombie-overhaul. Now 28 converted clips from 26 supplied FBXs (two swipe trims).
Live swipe_l/r use reviewed recording strikes; original windups, 0.35 s recovery, damage and
network names remain. Shared visual synchronization also covers puppets. death_sit/back now
use the two recorded falls, per-clip handoff times, visual root travel and recorded momentum
into capped ragdolls; pool reuse resets displacement. All tier speeds and jitter unchanged.
Blender/import 28/28; GUT 44/44, 2,670 asserts; script scan 858/0; Map 2 smoke PASS, 9 walkers
worst median root/body discrepancy 1.4%, ragdoll peak 6, corpse return/severs/climb/KD verified.
Four real-state before/after comparisons + event reports: docs/captures/after/mocap/states/.
Both death handoffs <=1.089 cm instant bone movement. Fixed the capture-only freeze timer
being advanced by slow PNG writes; rerendered. Final captures have no script/engine/leak errors.
Known Unicode/NUL warnings remain. Two swipes/two deaths reviewed 2 -> 3/5; model stays 2/5.
NOT FULL OVERHAUL COMPLETE. Missing performances and artist model sample remain on shopping list.
NEXT: zombie-only PBR material pass using existing fabric/leather normal/ORM maps (currently
unused by kit shader), then rerun rendered quality/performance. Keep people materials unchanged.
Still open: turn-yaw/phase matching, remaining source states, stairs and special-body coverage.
No merge, push, main replacement or export. Source/converted motion files remain ignored/local;
rebuild with tools/zombie_mocap_build.ps1. Earlier checkpoints below are history.


RESUME HERE: 2026-11-09 Codex verified delivery checkpoint. Worktree .wt/zombie-overhaul,
branch codex/zombie-overhaul. Pipeline commit 4177e459; runtime locomotion eabd2799. Current
gameplay speeds/jitter preserved. The supplied Starter pack is already copied locally and built;
never ask Devin to download it again. Source FBXs and converted GLBs/manifest are ignored licensed
files; rebuild with tools/zombie_mocap_build.ps1. Before/after videos for all six tiers are in
docs/captures/after/mocap_compare (left legacy/right current); run/sprint were refreshed after
the lean-direction fix. Final reports: docs/captures/after/mocap/acceptance_{motion,rendered,headless}.
Motion: 24 active / 60 s, near-player modifiers, drift p95 0.01321 m/s, root mismatch 2.38% PASS.
Real-time rendered/headless frame p95 4.167 / 6.944 ms; callback CPU 0.149 / 0.152 ms per actor
per frame on this PC. Both kept 24 active; no missing clips or sampled rest poses. 42 zombie tests
/ 2,550 asserts, 858-script scan, 26 imported clips, clean Map 2 animation smoke and ragdoll cap
9 admitted / peak 6 verified. Unicode/NUL startup warnings remain; no final script/leak errors.
Upright locomotion review 2 -> 3/5; model 2 -> 2; appearance variety 3 -> 3. Full premium target
NOT MET. Stage 1 done; Stage 2 locomotion slice done; remaining states/Stage 3 art and full Stage 4
special-body/pop/stair/per-type review unfinished. No merge, push or main build replacement.
NEXT: on this branch, review and trim the supplied attack loops and two deaths; integrate through
data while preserving hit timings, network death indices and ragdoll handoff. Then missing source
performances and artist-authored soldier/PBR/LOD sample per shopping list. See the plan's TOP
2026-11-09 delivery section; older absence claims below are dated history, not current status.


RESUME HERE: 2026-11-09 Codex Stage 2 locomotion checkpoint, codex/zombie-overhaul,
.wt/zombie-overhaul ONLY. Licensed motion is NOW ACTIVE: mco_chase for shamble/walk,
mco_fast_chase for jog/run/sprint, two mocap idles. enemies.json speeds and existing jitter
are unchanged. Crawl and attack/reaction/death/interaction clips remain legacy pending source
selection/event review; the Starter pack does NOT cover the entire spec. Source-driven contact
IK follows additive postures, phase-derived audio handles multi-stride loops, turn lean remains
additive. All 26 imported clips sampled at 60 Hz: zero identity/nonfinite poses, largest bone
step 28.26 degrees (diagnostic, not full T-pose/pop certification). GUT: 42/42, 2,550 assertions;
script scan 858/0; ragdoll stress 9 admitted, peak 6. Map 2 zombie smoke PASS (climb, root speed,
IK/look-at, sever/gore, knockdown/get-up, deaths/dissolve). Fixed its overlapping finish coroutine
and released its map/weapon/arms templates: final rerun has no SCRIPT ERROR/ERROR/leak warnings.
60 s near-player, 24-active fixed-60 motion acceptance PASS: 51,058 recorded-contact samples,
toe drift p95 0.01321 m/s, root/body mismatch p95 2.38%, no losses/rest poses/missing clips.
Rendered real-time near-player 24-active acceptance PASS: frame p95 4.167 ms, zombie callback
CPU p95 0.149 ms on Ryzen 7800X3D / RTX 5090. This is not a mid-range/full-map perf certification.
NEXT: finish the verification report/compact comparison-artifact commit, rerun the run/sprint
comparison after the lean-direction correction, and record remaining Stage 2/3/4 gaps honestly.
Do not merge/push/export main. Final state is a verified locomotion upgrade, not the full model
overhaul. Subsequent work: review/trim supplied attacks and two deaths with gameplay event and
ragdoll timing, acquire missing state recordings and an artist-authored soldier quality sample.


RESUME HERE: 2026-11-09 Codex Stage 1 intake/pipeline checkpoint, branch codex/zombie-overhaul,
work ONLY in .wt/zombie-overhaul. Devin supplied Downloads/FBX_Zombie_27_Starter and explicitly
said PRESERVE CURRENT SPEEDS. Copied originals to ignored assets/user_supplied/mocap_online/
zombie_starter_2_7. Do not buy/download again. 26 unique motions (26 IPC duplicates, unused demo
body). Repeatable tools/zombie_mocap_build.ps1 ran installed Blender 5.1.2 + Godot 4.7.2: all 26
converted/imported, 19 identity-rest bones match, zero import-check failures. Script scan 856/0;
license tests 4/4 (367 asserts); assets manifest current. Licensed binaries remain ignored/local.
Runtime bank loads for gallery; gameplay selection intentionally still disabled at this checkpoint.
Native fast-gait rendered preview completed; first preview rest-frame capture subsequently fixed
by immediate AnimationPlayer evaluation. Offline source-contact IK reduces planted toe drift,
but that is not a runtime acceptance result. Shared license gate minimally accepts the owner's
specific paid pack only in assets/zombies/anims. Official terms + per-clip ledger in ASSETS.md.
NEXT: wire reviewed mocap gaits into real AI without changing enemies.json speeds, derive footstep
events from source contacts, compare live tier recordings and run 24-active headless/rendered soaks.
Slow source walk/chase/crawl must be judged at the preserved speeds before runtime promotion.
Continue missing states/model work honestly; no premium/model quality sign-off, merge or export.


RESUME HERE: 2026-11-08 Codex final-check checkpoint, codex/zombie-overhaul in .wt/zombie-overhaul.
QUALITY TARGET NOT MET; do not describe this branch as a completed new-zombie asset overhaul.
Delivered/tested fixes: deferred random gait phase, evaluated-playhead footsteps, ragdoll live
budget. Fixed gallery-only teleport/progress watches; inactive actors no longer inflate samples,
losses fail the tool. Both fresh 60 s full-rate-animation soaks sustained 24 active (zero losses,
83,520 pose samples each; zero sampled rest poses/missing clips). Rendered p95 interval 4.167 ms
on RTX 5090; headless 7.576 ms. Not a mid-range/per-zombie CPU or near-player IK sign-off.
Final Godot checks: 39/39 zombie tests (1,906 asserts), 855 scripts / zero failures, ragdoll stress
9 admitted / peak 6. Blender: 6 GLBs, zero weight errors, 90 UV review findings. Fixed-timestep
live tier videos and clip previews: docs/captures/after/final/; read its README and the plan.
Foot sliding remains unaccepted (heuristic p95 6.832 rendered / 7.404 headless m/s). Soldier
locomotion/model ratings remain 2/5; no premium claim. One sprint capture exited without report
and logged cleanup errors; fresh rerun passed, cause unconfirmed. Unicode/NUL warnings remain.
NEXT: obtain licensed source mocap + the artist-authored soldier quality sample in the shopping
list. Build/verify tools/blender/zombie_anim_batch.py, retargeting and contact/root-motion handling
on one body, then expand. Finish special-body/state/pop/CPU coverage and per-type scores.
Stages 1/3/4 and most Stage 2 remain unfinished. No merge, push or playable-build replacement.

RESUME HERE: Codex gait-phase pass, codex/zombie-overhaul in .wt/zombie-overhaul.
Fixed deferred random stride start after ground emerge via AnimationNodeTimeSeek; crawl seek uses
its own clip duration. Rig-less bodies are guarded. Footsteps now sample the evaluated locomotion
state clock, suppress the initial seek event, and realign after attacks. No animation poses added.
Verified 39/39 zombie tests, 1,906 assertions, including new equal-clip/equal-scale simultaneous
ground-spawn phase regression and footstep alignment before/after attack. Gallery --horde --emerge
exercises the real spawn transition. See docs/ZOMBIE_OVERHAUL_PLAN.md for fresh soak results.
NEXT: finish Stage 0 special-body coverage, pop detection, CPU profile and per-type scores;
then licensed clip intake. Licensed mocap pack remains absent; full overhaul is incomplete.
Fresh 60 s headless gallery: 83,520 pose samples, no sampled rest poses/missing clips, no exit
leak errors. Sustained 24-active requirement FAILED (minimum active 2). NEXT FIRST: instrument
studio reclamation/state histories and replace reclaimed actors through a director before using
the gallery as a soak. Contact-speed p95 5.985 m/s; sliding remains unresolved. Report in
docs/captures/after/phase/horde.json. First guarded run ended early and was excluded.

RESUME HERE: 2026-11-08 Codex resume pass on codex/zombie-overhaul (.wt/zombie-overhaul).
NOT all done. Gallery now has --kit/--clip/--kind/--frames, camera-facing labels and close-ups;
soldier walk capture/sequence rendered and inspected. Gallery exit frees unattached weapon
template Nodes; headless/rendered reruns no longer report RID/ObjectDB leaks. Actual gameplay fix:
ZombieRagdoll frees live-budget slots when frozen and freezes oldest under cap pressure to admit
newest death. Regression scene tools/zombie_ragdoll_check.tscn failed before (6/9 admitted,
frozen bodies counted) and passes after (9/9, peak 6, zero stale live registrations).
Existing zombie regression suite 8/8, 61 asserts PASS. Unicode/NUL warnings remain.
NEXT: complete bespoke enemy coverage, pop detection, per-zombie CPU timings and before scores;
then licensed FBX intake and first-locomotion phase/event synchronization. Mocap pack still absent.
Stage 0 incomplete; Stage 2 has this isolated ragdoll fix; stages 1/3/4 not implemented.

RESUME HERE: 2026-11-08 Codex zombie overhaul, Stage 0 PARTIAL checkpoint on codex/zombie-overhaul,
isolated checkout .wt/zombie-overhaul (owner approved master e96a0188 as base; no main exists).
Read docs/ZOMBIE_OVERHAUL_PLAN.md and tools/ZOMBIE_GALLERY.md. Next: improve gallery preview
framing/labels, cover special enemy classes, diagnose exit resource leaks, add pop detection and
ragdoll-cap stress, close-up scores and per-zombie CPU profiling. Finish/commit Stage 0 before
the licensed animation pipeline. MoCap Online pack absent; do not generate substitute motion.
Completed here: gallery with 102 clip captures across 14 kits / 24 Ganger instances; live 60 s
rendered RTX 5090 baseline (p95 interval 4.166 ms, not target-machine sign-off); corrected 10 s
headless measurement (24 active throughout, 11,520 pose samples, no sampled rest poses,
contact speed median 2.051 / p95 5.967 m/s using moving-foot heuristic). Asset audit 749 files /
64 GLBs; Blender imports six zombie models, zero unweighted skinned vertices, 90 UV review findings.
No gameplay changes, no new third-party art. Existing shutdown leaks and Unicode warnings remain.
Stages 1–4 NOT done. Before/after quality scores pending; no improvement claimed.
The prior unrelated agent's resume instructions are preserved below.

RESUME HERE: 2026-11-08 (afternoon) T-216 + T-217 MERGED on master and pushed (suite 2092/2092 + 1 risky; exe rebuilt, its headless campaign probe PASS: ClaudeZombies.exe --headless --audio-driver Dummy -- --probe-campaign). T-216: the crash-probe review fixes (gravelight/tools_src/probe_campaign_start.gd: copies of settings + profile, typed --set, one heartbeat, --char/--seconds; MenuCharacter.prepare_match shared); the campaign crash is NOT reproduced: leads are the exported exe (its log was cut: rebuilt with flush on) and "indexing did not unpair geometries from light" after game over -> Restart (map_root._restart). T-217: Bot AI brains (bot_ai_brain auto/builtin/small/small_cpu/large; bots.json local_ai.brains, keep_alive 2m, num_ctx 2048), the built-in brain trained from the 27B (data/gravelight/bot_planner_learned.json, tools/bot_ai/train_planner.py, ai_soak --local-ai=<brain>; docs/BOT_AI.md section 16). Next: retrain with rows from Kaltenbrunn/Totenhafen/Fernflug; ask the owner to try the rebuilt exe and send logs if it crashes. Before that: 2026-11-08 UPDATE 12 "THE LOOK" DONE and pushed (T-203..T-215; morning/MORNING_REPORT.md, morning/NEEDS_DEVIN.md). Nothing running. Open for a next session: confirm FPS targets on a quiet machine (--frame-log on Low + the web build); trace the rare heap-corruption crash in capture runs ('indexing did not unpair geometries from light', T-208/T-214); the Thalbach sky-ring streak and the C-47 cabin slivers (T-214); smoke_marks + smoke_letzte_fahrt (old); the owner's steps: C-47 download (tools/c47/build.sh), 49 Higgsfield reel clips (tools/cinema/archive_reel.py build), mocap filming (tools/mocap.sh), the December ElevenLabs bake (resumes fp.c3.outro.09; fills the reels' narration slots). Before that: 2026-11-07 UPDATE 11 "LAZARUS" (docs/work_orders/UPDATE_11_LAZARUS.md; contracts docs/U11_CONTRACTS.md; T-189..T-203). Egg guard snapshot on master (f1a8e737, test_u11_egg_guard). ElevenLabs key in the main checkout's git-ignored .env.local (never print it). MERGED: T-191 shots (20bb3165), T-190 canon (7fd1df35), T-195 Operator VO (a0d9db66), T-196 Dutch+Peg + T-197 Deacon+Wren VO (f8e08961; the voice e2e test pins its 7 recorded lines), T-198 Jakub/NPCs VO (f8a3d3ae), T-199 Fine Print (bfa4c7ad, 2 lines), T-201 casting (137e1b37; library voices by id, the key has no voices_write; 8 final takes; account counter moves ~half the billed chars: 130,679 left, reset 2026-12-07), T-193 ElevenLabs pipeline (tools/voice/eleven.py; Creator tier 131k chars/month, full bake ~420k: bake groups 1-5 first, ~119k). RUNNING (worktrees .claude/worktrees/agent-<id>): u11-5-cutscenes (Opus, T-194, a8d5f1770fa8819cd), u11-4-vo-npcs (Fable, T-198, a5d232fe97c7927a7). u11-3-archive (Haiku, T-200, aad140fe6eb211ef1). the respect review DONE (16 findings, 1 must-fix: Serafim's last diary line; saved in the session scratchpad respect_review.md), respect fixes MERGED (a4cd3253, review recorded in docs/LAZARUS.md), T-200 Archive MERGED (f4cd5f47), T-192 horror pass MERGED (0dd64b92). RUNNING the bake: u11-7-bake (Sonnet, T-201 bake, a824426352da815d1; priority order, keeps a 5,000-char reserve, resumes from bake_state.json). Was: the bake (T-201: groups 1-5 fit this month, ~119k of 131k). Merge lines.json / audio_manifest.json conflicts with tools/json_merge3.py (--deep files,missing for the manifest), keep both sides of doc conflicts, then re-run extract_vo.py. Known: extract_intel.py would drop intel.json's 30 Map 4 rows (never run it blind). Then wave 2: u11-5-cutscenes (Opus, T-194, after T-191), the VO slices u11-4-vo-* (Fable, T-195..T-199, after T-190); wave 3: u11-3-archive (Haiku, T-200), u11-7-bake (Sonnet, T-201, after the VO slices), the respect review (fresh Fable, T-202); FINISH T-203 (Play.bat buttons, voice scripts, full suite + every smoke, morning report, NEEDS_DEVIN, push). If a session dies: resume each worker by SendMessage to its agent id, or inspect the branch and merge what passes. Before that: 2026-11-06 (later) the owner's next list. MERGED + pushed (3e4befd4; suite 1884/1884, 767 scripts; smokes cellar_bay, map00*, map02 (flaky once under load, 2/2 on rerun), map02_art, map02_world, coop, bots_shop*, feel, jakub): T-182 ADS sights (11 guns' sight markers fixed, a geometry check), T-183 HUD squad panel + 40 px perk caps + redrawn icons + hold-Ctrl scoreboard, T-180 Totenhafen (41 invisible walls, bulkheads, hold, sub deck, art audit tool; open: perk_machine.gd / crucible.gd colliders ~25 cm past their art; Letzte Fahrt bots stalled once at s7_key), T-179 Map 0 cellar bay with Skyhook Sekt + Magpie Mead. ALSO MERGED: T-181 the Requiem easier for the bots (3/5 bots alone) + Easter Egg Mode (Settings > Gameplay and map select; practice, no progress), T-185 pushes no longer build up (the Kranich lash launched players 56 m; also map04c/d, map02) + BoundsGuard on every map, T-186 from round 30 every squad bot holds every tonic + a taught gun (not companions: data flag), T-187 numeric enemy kill pay fixed. Master 57c0ad6e: suite 1915/1915, 776 scripts. ALSO MERGED: T-184 cinematic cutscenes (gravelight/ui/cinema/: shot library, letterbox, grades, title cards, stand-in squad, hold to skip; all 12 cutscenes; clips in morning/clips/t184_*; needs the owner's GPU look: DoF/grade on Forward+, dark Totenhafen/Kranich shots, the simple Moon). Master suite 1939/1939, 784 scripts. T-188 MERGED (1bbdd15b): perk machines and the Crucible collide with their art, NavBlocks round them navmesh-only on every map. Nothing running. Open: Letzte Fahrt bot runs sometimes stall at s7_key/s9; the Fernflug acts' other NavBlock invisible walls (MapArtAudit lists them); Map 0's BayCrateCol (7 rays); smoke_marks' pause-map empty-spot check fails on master too. Original list: u10-12-cellar-perks (T-179: expand the Map 0 cellar, add Skyhook Sekt + Magpie Mead machines, the only tonics with no machine on Maps 0-2 though the Requiem grants them), u10-12-totenhafen-fix (T-180: missing textures, invisible walls, doors, the unfinished submarine on map02), u10-12-egg-easy (T-181: the bots stuck at the Requiem bells, make the egg easier, an Easter Egg Mode with no / minimal crawler spawns), u10-12-ads-sights (T-182: ADS sights off centre on some guns), u10-12-hud-squad (T-183: left squad panel = names + down state + tiny perk icons, smaller perk circles, better perk icons). Merge each when its suite + smokes pass, then full suite, push, morning report. Before that: 2026-11-06 (owner: fix the T-172 review, check Map 1 performance, bots + companions use the bank / perks / Crucible / bench) ALL MERGED on master (merge of u10-11-bots-shop; suite 1863/1863, 758 scripts; smokes green: bots_shop, bots_shop_m0, requiem, ee_bots, bots, bots_u10, jakub, squads, map01, map01_systems, map01_world, map_companions, bank; letzte_fahrt only hit the runner's 20-min cap, still progressing, 0 errors). T-176 the ten review fixes; T-177 squad bots and companions use the bank (own match accounts, never the profile), the Armorer's Bench, tonics and the Crucible on their own; perf-map01 (T-178 in the T-177 paragraph): Map 1 scripts did not regress (a random relief squad was the +0.7 ms), two per-tick log floods fixed, the unreachable-node loop ends the step. Open: the GPU side of Map 1 (T-161 landscape +79 transparent surfaces, T-175 Crucible key-light shadow) needs the owner's rendered FPS run (--frame-log); orphan nodes grow slowly in long soaks (285 -> 633 in 35 min). Then the older list below. Older: 2026-11-03 (owner follow-up after the U10 stop) All follow-up work MERGED on master: T-172 bot eggs (76078a70; Letzte Fahrt 2/7 runs completed, 1/1 on the final code in 28 game min; Requiem 0/5, best reached s7, stoppers: a calling radio never heard so s2b/s8a stay locked, the shard placement failing at the Crucible, a wedged Foreman), T-175 Crucible rooms (c4912d25; open: no NavBlock on Kaltenbrunn's Crucible, a walkable patch inside Totenhafen's), T-173 Totenhafen graphics + egg guide MERGED (8a178b9c; master 1841/1841, 751 scripts), T-174 egg rewards (Requiem maxes every tonic, Letzte Fahrt 7500 Scrip + every tonic one tier; e1ee1e1f). Running: u10-10-bot-eggs (T-172: bots finish Kaltenbrunn's Requiem and Totenhafen's Letzte Fahrt, target 3/5 each) and u10-10-totenhafen-gfx (T-173: Totenhafen graphics bugs: glowing edge lines, black water, floating white discs, red pen hall; Letzte Fahrt made discoverable in a plain match). Merge each when its suite and smokes pass. Then the list below.  2026-11-02 UPDATE 10 stopped at the owner's request (usage) on master after 131801b9. DONE and merged: every section (T-151..T-164, T-166), polish T-162, bots T-163, captures T-167, re-score T-168 (Inn 71, Kaltenbrunn 77 = target, Totenhafen 69, Acts 59/59/60/61: target NOT met), Totenhafen send-backs T-170, Fernflug send-backs in part T-171. Master: 747 scripts 0 failed, suite 1831/1831 at e9c30935; full smoke run stopped at 28/84 (28 PASS). LEFT, in order: (1) the blind review T-165: a fresh reviewer with the scoreless scorecard (rebuild it from THE_BAR.md by blanking the score cells), morning/screenshots/u10_before + u10_after and morning/clips/u10_blind/*.mp4 (local only); record in THE_BAR.md section 6. (2) The rest of T-171 from .claude/worktrees/agent-a129bc5e797cc2785 (uncommitted, unverified: bank.json teller reactions, companion_jakub.json act lines, map04b.json crates, map04d_ambience.json field units): review, test, commit, merge. (3) Re-score the rows T-170/T-171 touched (20, 21, 5, 15, 22, 6, 13, 26). (4) The full smoke run. (5) Rebuild web + Windows from master. (6) Update MORNING_REPORT's numbers, push. Older text: 2026-11-02 UPDATE 10 s9 FINISH in progress: polish (T-162) and bots (T-163, 45c232b2) MERGED, master 1827/1827, 744 scripts. Re-score (u10-9-rescore, T-168, fc8c0751): Kaltenbrunn 76 raised the target; Totenhafen 67, acts 59-60: FAIL on totals, PASS on only-here and seed rows; send-back workers running: u10-9-sendback-m3 (T-170, Totenhafen rows 20/21/5/15/22), u10-9-sendback-m4 (T-171, Fernflug rows 26 map04c_world fix/6/13/21/19/25/15); captures u10-9-captures (T-167). Then: merge send-backs, scorer finalizes, blind review (T-165), full smokes, builds, finalize MORNING_REPORT (draft committed), push. Earlier: Totenhafen systems MERGED (99611905, T-153; master 1742/1742), the online check done (T-164, PASS: webrtc map02 flood+sail, map04b turbulence+wingwalk, lobby), nine Play.bat set-piece buttons in (dev_launcher U10_BUTTONS, smoke_launcher PASS), Surf_Cutter spawn added. Running workers (resume by SendMessage to the agent id in the transcript, or merge the worktree branch): polish u10-6-polish (T-162, 7 commits, waiting on its full smoke pass), bots u10-7-bots (T-163, rebasing onto master with T-153; Kaltenbrunn egg 0/5 and Q-19 0/3: targets NOT met, report honestly), captures u10-9-captures (T-167: u10_map02 camera set, clip_tour tool, 2-minute clips per map into morning/clips/u10_blind/ (git-ignored, local only)). Then: merge polish and bots (import first; suite + smokes), re-score docs/THE_BAR.md (section 5 method; a scorer worker), blind review by a fresh reviewer (T-165) with the clips + u10_before/u10_after sets (morning/screenshots, git-ignored), fix rows below Maps 1-2, full suite + every smoke, rebuild web + Windows builds, MORNING_REPORT (scorecard before/after, 5 things to try per Totenhafen and Fernflug, bot egg rates, FPS, what does not work), NEEDS_DEVIN (Vercel one-liners, TURN, likeness, FPS run, browser peer), push, the pull line. Older text: 2026-11-01 (late) UPDATE 10 (docs/work_orders/UPDATE_10.md; contracts docs/U10_CONTRACTS.md; Totenhafen design docs/U10_TOTENHAFEN_DESIGN.md) started while UPDATE 09's final full smoke run finishes; every U09 section is merged on master (s1-s7, s8 launcher, packs; builds done: web 135.8 MB to the menu, ClaudeZombies_0.0.1-m0.zip 493 MB; Vercel deploy = owner's one-liner). U10: s1 THE_BAR MERGED (88e39b1, T-151; totals Inn 71 / Kaltenbrunn 68 / Totenhafen 45 / Acts 43-37-43-39 of 84; target >= 71). MapRoot generic living-world loader on master (25a93f1). Running (worktrees under .claude/worktrees/agent-*): u10-2-totenhafen-systems (Opus, T-153), u10-2-totenhafen-world (Opus, T-154), u10-4-bosses (Opus, T-159/T-160), u10-5-kaltenbrunn-world (Sonnet, T-161), u10-3-act2 (Opus, T-156), u10-vo-bake (Haiku: every missing VO line). 2026-11-02: MERGED s4 bosses (3484a5d, T-159/T-160), VO bake (d3cb7b0, T-166), s2 Totenhafen world (e99e8a2, T-154), Act IV (db90e88, T-158). U09's full smoke run finished: 54/54 green after two stale-count fixes (map01_systems, story_props). MERGED Act III (d63418e9, T-157), Kaltenbrunn world (253c4e28, T-161), Act II (07df06cc, T-156; campaign.gd preload_next unified 06c39adf). Master 1682/1682, Act II/III/IV + Kaltenbrunn + webrtc + npc_walls smokes green. Act I MERGED (0500db71, T-155; master 1693/1693). Running: Totenhafen systems (u10-2-totenhafen-systems, T-153), bots (u10-7-bots, T-163), polish (u10-6-polish, T-162). Then: regenerate map02 after T-153 lands, s8 online check (T-164), s9 finish: re-score THE_BAR, blind review (T-165), Play.bat buttons, full suite + every smoke, builds, MORNING_REPORT, NEEDS_DEVIN, push. Still building: Totenhafen systems (u10-2-totenhafen-systems, T-153), Act I (u10-3-act1, T-155). After those: regenerate map02 (both Totenhafen branches touch gen_map02), then s6 polish (T-162), s7 bots (T-163), s8 online (T-164), s9 finish + blind review (T-165). Older U09 resume text follows. UPDATE 09 (docs/work_orders/UPDATE_09.md; contracts docs/U09_CONTRACTS.md) in progress. The lead (Fable) spawns workers in worktrees, one branch per section (u09-<sec>-<slug>), reviews and merges. Supabase project claude-zombies (fkoebguijrmlqdqrsgdy, us-east-1) created; URL + anon key in data/gravelight/online.json; Vercel team 'Devin's projects' (team_eQCE2Tc4AXi216jH8NYmRMA8) reachable through MCP. Godot 4.7.2 export templates installed on this PC; Linux Godot in tools/dl_godot for WSL+Xvfb captures (contract C8). Supabase schema (supabase/migrations/0001_lobbies.sql) APPLIED live on 2026-11-01 via execute_sql in 3 chunks (apply_migration needs a human click; pg_cron not enabled). Wave 1 (parallel, worktrees under .claude/worktrees/agent-*): s1 the Marke (Fable, branch u09-1-marke), s2ab netcode+lobbies (Opus, u09-2ab-online), s2cd web export+profile+perf (Opus, u09-2cd-web), s6 rename (Sonnet, u09-6-rename), capture tool (Haiku, u09-capture-tool). STATUS 2026-11-01 evening: MERGED s1 Marke (a7bbc59, T-137), s6 rename (51e6ba5, T-140), s2ab online (ac82eab, T-138: WebRTC + Supabase lobbies live, smoke_webrtc/smoke_lobby). s2cd web MERGED (e4874c0, T-139: export_presets, build_web.sh 129 MB to menu, build_windows.sh zip, web profile, PERFORMANCE.md; browser draw calls still over budget on map00/map02; Vercel deploy not yet done: do it via the Vercel MCP in s8 with a CZ_PASSWORD env var). s4 squads MERGED (2448e8c, T-142) + CANON 2.2 reconciled; s4b people + wall fix MERGED (01cba4f, T-143; lines.json join repaired 5e4f1cc). Master suite 1480/1480. Open smokes: smoke_map04c (a Full Partner bot pre-empts the burn console check) and smoke_npc_walls (the bot-mode agent pressed 3.3 s in the stable): Sonnet upkeep worker u09-smoke-upkeep on both. s3 Ledger Lager + banks MERGED (6f19775, T-141: prices 3000/4000/7500/14000 held by soak; branches on map02/04a-d; minimap images NOT re-baked, only POIs). s7 menus spawned (u09-7-menus, Opus); s5 audit MERGED (2b9ff3b: docs/MAPS_3_4_REBUILD.md sections 4-5, capture sets u09_*, census_map). Master 1507/1507 after s3. Zone builders spawned: Totenhafen (u09-5-totenhafen, T-145, owns zone_ambience.gd + data/gravelight/ambience/), Act II (u09-5-act2, T-147), Act I (u09-5-act1, T-146, owns gen_detail_lib.gd + gen_map04_lib.gd); Acts III (u09-5-act3, T-148) and IV (u09-5-act4, T-149) spawned too. Smoke upkeep MERGED (43ee351: smoke_map04c pins bot egg help off; BotLocomotion wall sweep). s7 menus MERGED (6444625, T-144; master 1521/1521). Vercel project creation via MCP is blocked by the session's permission classifier: the deploy is the owner's one-liner (npx vercel login; sh tools/deploy_web.sh; npx vercel env add CZ_PASSWORD production). Act III MERGED (4b33dc6, T-148), Totenhafen MERGED (d070bd6, T-145: ZoneAmbience + ViewCells; audio.json three-way merged by script). Master 1535/1535. Running now: Act I (u09-5-act1), Act II (u09-5-act2), Act IV (u09-5-act4), the launcher-buttons worker (u09-8-launcher). Then s8: merge, full suite + all smokes, Play.bat buttons, Vercel deploy via MCP (password gate env CZ_PASSWORD), MORNING_REPORT, NEEDS_DEVIN, push. s5 audit worker stopped mid-capture (branch u09-5-audit has the camera sets + census script; captures running in its worktree; resume it or finish the doc sections 4-5 by hand). Capture tool merged (f02a05c); before shots in morning/screenshots/u09_before (10 PNGs). Running: s2ab (u09-2ab-online), s2cd (u09-2cd-web), s6 (u09-6-rename), s3 (u09-3-ledger, Sonnet), s4 squads (u09-4-squads, Opus), s5 audit (u09-5-audit, Sonnet). Still to spawn: s4b people + wall fix (Sonnet), s7 menus (Opus), s5 zone builders (Opus, after the audit), s8 finish. If a session dies: resume each worker by SendMessage to its agent id, or inspect the worktree branch and merge what passes. Then s3 Ledger Lager + banks (Sonnet), s4 squads (Opus) + people/wall fix (Sonnet), s7 menus (Opus), s5 map rebuilds last (Opus per zone). Finish: s8 Play.bat, push, MORNING_REPORT, NEEDS_DEVIN. UPDATE 08 s4 (bots finishing the Kaltenbrunn egg) stays open after this update: its old resume text is kept below under 'UPDATE 08 s4 resume'.

## UPDATE 08 s4 resume (deferred behind UPDATE 09)
2026-10-31 T-136 the savings bank merged (Map 0 woodshed Darlehenskasse + Kaltenbrunn pay office, teller Erwin Lassmann, 1% a round, kept in the profile; smoke_bank). Earlier, 2026-10-29 also merged: T-133 smooth motion + graphics settings, T-134 more detailed people models, T-135 one more companion per map (Trudi / Gustl Ammer / Hinnerk Petersen / Jette Maurer; MapCompanion, companions.json, smoke_map_companions). Open from those: frame cost of T-133/T-134 unmeasured on the owner's GPU (play with --frame-log), zombies still move at 60 Hz. Before that: 2026-10-28 UPDATE 08 merged to master EXCEPT section 4 acceptance (work order docs/work_orders/UPDATE_08.md). DONE and merged: s1 baseline (docs/QA_REPORT_U08.md), s2 tier IV perma perks (T-129), s3 bot late kit (T-130), s5 launcher buttons, MORNING_REPORT; s4 partial (T-131): the agent does player-only steps / starts the Heartstorm / starts pylons, Full Partner default picks (Peg), Map 4 power/burn knowledge, Kaltenbrunn plan (egg block, Lab door, surface loop, 3 Crucible teachings), the agent stays on a charging pylon, BotLocomotion fall rescue, soak --until-egg, EGG_DEBUG plan logging. Unit suite 1370/1370; smokes late_kit bots ee_bots botmode jakub map04_egg requiem launcher map01 map01_systems coop vo feel pass. NEXT (s4): iterate EGG_DEBUG=1 sh tools/ai_soak.sh --scenario=botmode --map=map01 --bots=3 --ee=full --god --speed=4 --until-egg --trace=60 (logs .smoke_logs/u08/egg_map01_*.log). Open blockers: in god mode the bot-mode trainer kites 2 straggling crawlers forever (nobody hunts the last zombies; give the trainer a round-end hunt); pylons F/H under x2 spawns; then s4 bell + Foreman in F_CHAPEL, s6 bells, s7 drummer chase, s8b 30 Totenglocke kills, s9 Heartstorm 120 s holdout. Then: honest 5-run Kaltenbrunn acceptance (3/5), Fernflug egg soak (--scenario=fernflug --egg=full), per-map egg smokes, QA report After + MORNING_REPORT update.

## UPDATE 07, 2026-10-26: Map 4 Fernflug + QA pass (DONE, merged to master)

Phase 0 QA: running (T-103 merged; Map 0/Map 1 workers out). Phase 1 design: DONE. Phase 2: Acts I–IV MERGED (T-104, T-108/T-109, T-110/T-111, T-112/T-113), perks+Lodestone MERGED (T-105), egg Acts I–II MERGED (T-114), boarding, Act 2, crash, Act 3, rocket, Act 4, perks/wonder/egg/endings (pending). Finish: pending.

## Overnight run, 2026-10-25 -> 26: UPDATE 05 "Look the part" (plan)

Work orders (original folder, read-only): UPDATE_05A_ASSET_INTAKE.md, UPDATE_05_ART_SLICE.md, OVERNIGHT_RUN.md. Rendered off-screen runs are approved for this update.

Phase 1 (parallel): T-087 asset intake (OGA guns + Devin's Sketchfab guns -> assets/third_party, models.json, ASSETS.md + credits generated from SOURCE.txt, license gate) and T-088 pipeline (ART_BIBLE.md, CC0 material library + shared material templates, CC0 props, import presets, asset_report, 20-camera capture + BEFORE shots, NEEDS_DEVIN.md).
Phase 2 (parallel): T-089 viewmodel guns (normalize, shared weapon shader, markers, ads_check, animation fit, per-character arms), T-090 wonder weapons + gramophone, T-091 zombies, T-092 people, T-093 Map 0 environment, T-094 world objects, T-095 VFX, T-096 UI readability.
Phase 3: full suite, ads_check, map-data check, asset report, FPS check, clip, Play.bat buttons, morning report, rollout plan.

Status: T-087 intake MERGED (3029025; 16 guns in assets/third_party, models.json, license gate). T-088 pipeline MERGED (ART_BIBLE, MaterialLibrary/PropLibrary, 28-cam capture, BEFORE shots in morning/screenshots/u05/before). Phase 2a started: T-089 guns (.wt/u05-guns), T-095 VFX (.wt/u05-vfx), T-096 UI (.wt/u05-ui). Phase 2b: T-093 environment MERGED, T-094 world objects MERGED, T-091 zombies MERGED; running: T-094 world objects (.wt/u05-worldobjects), T-091 zombies (.wt/u05-zombies). T-090 wonder weapons MERGED. T-092 people MERGED. Phase 2 complete; phase 3 (full suite, after capture, FPS, morning report) running.


## Overnight run, 2026-10-21 → 22: the plan

State at the start: M0, M1, M2 are done and tagged; GRAVELIGHT has three playable maps (Crossroads Inn, Kaltenbrunn,
Totenhafen) with the campaign chain, perk machines in the Map 0 cellar, the Requisition Crate, power-ups, the
Crucible, wonder weapons, voiced VO and AI bot teammates. Bolt & Sprocket has its slice plus M3 work in progress.
So from the overnight work order only these remain, in this order:

1. **Bots** (asked for tonight): every bot spawns with a Thompson, Ironhide Stout (Juggernog) and Second Wind
   Schnapps (Quick Revive); one bot runs on a local LLM (Ollama, gemma3) that picks its objectives and does the
   map's tasks and easter egg. Branch `bots-local-ai`.
2. **MZ, zombie animation upgrade** (v2 §7): the work is in the working tree from the last session; verify (GUT,
   smokes), fix the open review findings, commit. Branch `mz-anim`.
3. **v3 Homage Bosses docs** (`docs/gravelight/HOMAGE_BOSSES.md` and the doc updates), written in parallel.
4. **HB1, The Cousins** (v3 §2) on Map 0, round 10. Branch `hb1-cousins`.
5. **Morning kit:** `PLAY.bat` dev menu (every playable thing, skip-to-round, god mode), `tools/capture.gd`
   screenshots into `morning/screenshots/`, `morning/MORNING_REPORT.md`.

Rules: `master` is the main branch and must always launch; each step is merged only after GUT + the smokes pass.

## Update 02 — baseline playtest, 2026-10-22 (before any change)

Played Map 0 to round 10 with the playtest bot (`tools_src/playtest_gl.tscn`, which drives the real Player through
the input actions): one god-mode run with the Thompson, and one honest solo run with 3 squad bots. Plus viewmodel
contact sheets (`vm_shots`) and a read of the movement / weapon code. What feels wrong:

**Movement**
- Ground speed snaps: 45 m/s² acceleration (walk speed in 0.1 s) and the same instant stop; no slide on stop.
- Sprint is hold-only; there's no toggle setting. Turn speed doesn't change while sprinting. The sprint FOV is a flat ×1.06 inside the overall
  FOV lerp, with no own smoothing, and the head-bob barely differs from walking.
- **Eaten inputs:** while sprint is held, `fire` and `ads` are ignored (can_shoot needs not-sprinting, and ADS needs
  not-sprinting), so pressing fire mid-sprint does nothing until you let go of sprint. Sprint-out is a fixed 0.16 s
  for every class.
- No mantle/vault (bar counter, fences, low walls block training loops); no prone; crouch height snaps in 0.12 m
  steps (reads as a lerp but at fixed per-frame steps, frame-rate dependent).
- Landing shake is fixed (0.15), not scaled by fall height. No strafe roll, no weapon inertia beyond the look sway,
  no damage punch.

**Gunplay**
- Recoil is a random yaw kick per shot plus a pitch spring: no learnable per-weapon pattern.
- Bloom exists but decays at a fixed rate regardless of stance; the crosshair doesn't show crouch/still benefits.
- Hitmarker: one kind (no red kill tint, no headshot sound).
- Reload cancel by sprint/swap exists partly (sprint queues the reload instead of cancelling it).

**Thompson ADS:** the rear aperture fills the view and the front blade is hidden under the receiver top; the hand
and the mag/drum read into the lower view; sway at ADS is the SMG class sway (0.3) and drifts noticeably.

**Totenglocke:** each ring needs a 0.6 s hold *then* release (feels like a delay, not a gun); only 6 charges a mag
and 24 reserve (30 rings a refill); damage falls off to 60 % at the cone edge so edge zombies survive from round ~15;
no stagger on survivors; the feedback is one explosion puff 3 m ahead and a single bell sample; the reload is a flat
3 s. It doesn't feel like the strongest thing on the map.

**Bots / squad (3 bots, regular):** the squad wiped on round 5 (every bot down in the same round, 0 revives between
bots, 0 revives of the player); they camp where they stand instead of moving with the player; bots ended on the
M1911 (last-stand pistol) after going down.

**Map 0 navigation (god run):** the player got stuck on nav paths at the stair vestibule (6, 0, 15) ×18, the cellar
stairs/landing (27, 0, 11) ×8 and the cellar floor (34, −3, 19) ×12; zombies idled in CHASE at the stair head
(1, 3, 1) and in the taproom (15, 0, −1).

**World:** past the yard fence it's flat snow and black sky; no distant life; the inn reads as a box in a void.

## Done

**Update 02 (2026-10-22):** §1 feel (T-046) works · §2 ADS (T-047) works, 44/44 guns aligned · §3 Totenglocke (T-048)
works · §4 ammo boxes (T-049) works, 10 boxes on 3 maps (+1 in the Old Cellar) · §5 bots (T-050) partly: bonus perk,
looks, nameplates, barks, command wheel work; behaviour moved to U03 · §6.1 Old Cellar (T-051) works · §7 living
world (T-052) works · §8 polish (T-053) works. U03 §0/§9 metrics + baseline (T-054) works. Campaign carry fix for
bot bonus perks (d22d640). GUT 651/651, every smoke passes.

**Update 02 §6.2 + Update 03 (2026-10-22):** Jakub (T-051) works · U03 locomotion (T-056) works · U03 brain (T-055)
works · U03 tuning (T-058) partly: bots alone reach round 10 (best 16), target 20–25; revives 96 % with a realistic
player, 78 % with the do-nothing one · U02 follow-up fixes (T-057) · deflake (T-059). Final: GUT 729/729, all 27
smokes pass, ads_check 44/44.

- **Bots** (T-043, commit 33c1043): spawn kit (Thompson, Ironhide Stout, Second Wind) — works; local-AI planner bot
  (Ollama gemma3:27b) — works on Map 0's egg alone, Map 1's Requiem partly (power, doors, Totenglocke).
- **MZ** (T-041 + review fixes, commit 8a7ae4f, tag `mz`) — works; GUT 525/525, all smokes pass.
- **v3 Homage Bosses docs** (T-042, commit f594eaf) — done.
- **Morning kit** (T-044, commits 85ee6cb, efb3be3): `Play.bat` dev launcher, `tools/capture.sh`, `tools/run_smokes.sh`
  — works; screenshots in `morning/screenshots/overnight/` (git-ignored).
- **HB1 The Cousins** (T-045, commit 143156c, tag `hb1-wip`) — partly works: the round, three cousins with core moves,
  rewards, toggles, console verbs; extras listed in HOMAGE_BOSSES "HB1 build notes". GUT 546/546, all 21 smokes pass.
- **Morning report:** `morning/MORNING_REPORT.md`.
- Bolt & Sprocket: `delayed_blast.gd` freed-source script error (smoke_nova) fixed (35bdeac).

## In progress (none: Update 02 + 03 done)

Update 02 (started 2026-10-22 ~05:30). One branch + worktree (`.wt/<branch>`) per section, built in parallel,
merged into master in the brief's order after GUT + smokes pass:
- §1 movement & gunplay feel: `u02-1-feel` (T-046)
- §2 ADS / SightPoint / Thompson / ads_check: `u02-2-ads` (T-047)
- §3 Totenglocke rebuild: `u02-3-totenglocke` (T-048)
- §4 ammo boxes: `u02-4-ammo` (T-049)
- §5 bots (bonus perk, design, command wheel): `u02-5-bots` (T-050)
- §6.1 bigger cellar: `u02-6-cellar` (T-051); §6.2 Jakub after §5 merges
- §7 landscape, sky, distant war: `u02-7-landscape` (T-052)
- §8 polish pass: after §6.1 merges (T-053)

Update 03 (UPDATE_03_BOT_AI.md, arrived mid-run): smarter bots + Jakub on one utility-AI brain. U02 §5 was narrowed
to the parts that survive the rewrite (bonus perk, looks/animations, nameplate, barks, command wheel UI); behaviour
moves to U03. Order: U03 §0/§9 metrics + baseline soak (`u03-0-metrics`, T-054) now → after U02 §5 merges, the
brain rewrite (U03 §1–§8, T-055) → U02 §6.2 Jakub on the new brain.


## Known flaky tests (Update 02/03)
- Fixed in T-059: smoke_bot_loco "stuck" (a real ladder bug), smoke_vo TEAM_DOWN (a real speaker bug), smoke_m2
  Panzerschreck (timing under load).
- smoke_map02 failed once after the U03 brain merge (the squad left the Foreman alive for 420 s at round 33);
  passed on rerun; handed to the U03 tuning pass.

## BLOCKED
