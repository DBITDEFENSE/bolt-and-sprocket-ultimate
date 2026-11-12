# Zombie overhaul audit — 2026-11-08

Base: master e96a0188; branch codex/zombie-overhaul in .wt/zombie-overhaul.
The owner approved master because main does not exist. No new animation poses or assets authored.

## 2026-11-11 recorded stationary turns

The bank now contains 30 derived clips from 26 owned source recordings. Two additional versions
of the 45-degree turns extract source hip yaw into Root after contact cleanup. Blender checks
world-pose reconstruction (worst 4.5e-16 m); Godot checks all 30 imported rigs and the new Root
rotation curves at 60 Hz. Raw versions remain available for comparison.

A presentation-only `Turn` AnimationTree state plays the recorded step below 0.5 m/s in CHASE
and TO_WINDOW. Data permits 25-65 degree requests and bounds rotation lag; the pivot compensates
for the original fast body-facing response, then follows recorded yaw. Gameplay body facing,
speed, attack timing and networking state enums remain unchanged. Source-contact IK and audio
run with the turn. Movement/attack/other states cancel it; residual rotation releases and pooled
reuse resets it. No new gait or turn poses were generated.

Executed: 46/46 zombie tests, 4,066 assertions; 860 scripts/0 failures; license 4/4, 367 assertions;
108-folder manifest current. The first license-filter command matched no tests; it was corrected
and the actual passing count verified. Final scoped logs have no script/shader/engine/leak errors;
known Unicode/NUL warnings remain. Map2 smoke passes root speed (worst median discrepancy .7%),
climbing, severs/Gore Off, knockdown/get-up, deaths, cap6 and corpse return.

| Check | Result |
|---|---|
| Stationary turn contact drift p95 | .008172 m/s; 175 source-contact samples after entry blend |
| Max visual heading step, fixed 60 Hz | 11.25 -> 1.7943 degrees; original body-facing error <.000006 degrees |
| Turn interruption | Movement/attack passed; 35/45/60 degrees both ways and pool reset covered by unit tests |
| Fresh 60 s rendered 24-active gallery | frame p95 4.5455 ms; zombie callback CPU .192 ms/actor/frame |
| Fresh 60 s fixed-60 motion gallery | 51,308 contacts; toe p95 .01245 m/s; root mismatch .5694% |
| Both horde runs | minimum24; no missing clips/rest samples; 83,520 pose samples each |

Evidence: `docs/captures/after/mocap/turns/comparison.mp4`, `turns/README.md`, and
`acceptance_turns_{motion,rendered}/horde.json`. RTX5090/Ryzen7800X3D results do not certify
mid-range hardware or full maps; the moving horde is not a 24-simultaneous-turn benchmark.
Captured soldier stationary turns rate **2 -> 3/5**; locomotion/swipes/two deaths stay3,
model stays2, variety stays3. Other types are not newly scored. Full premium target is unmet.

RESUME HERE: use docs/CLAUDE_FABLE_5_2_ZOMBIE_HANDOFF.md (runtime bf395bc3), prepared for the
**2026-11-12: co-op turn triggering is closed** (`ZombieTurnMotion.observe`, verified over real host/client traffic by `tools/zombie_turn_net_check.tscn`: 6 of 6 turns on both machines; see the newest PROGRESS entry). Next is the terrain / special-body matrix. The text below is the plan as it stood before that slice.

owner-requested Claude Fable 5.2 continuation. First finish co-op turn triggering:
puppets receive observed yaw, so small interpolated increments can miss the 25-degree trigger.
Host stationary turns are verified; network parity is not. Then stairs/rubble, special bodies,
remaining licensed states and artist-authored model/PBR/LOD sample. No main merge or export.

## 2026-11-09 push and local playtest

Devin explicitly requested pushing the current work. `codex/zombie-overhaul` is now on origin;
this supersedes older no-push notes. Main and its exported build remain unchanged. Run
`tools/zombie_playtest.ps1` from this worktree for the game, or add `-Mode Gallery` for a
ten-minute live 24-zombie studio. See `tools/ZOMBIE_PLAYTEST.md` for audio and rebuild details.
Licensed sources and converted GLBs remain local and are already built in this worktree.

Both launcher headless checks passed using automatic Godot discovery: actual menu startup
loaded 28/28 clips; the short gallery maintained 24 active with no missing clips, sampled
rest poses or validation failures. Fixed the launcher's wait for the Windows GUI executable
and explicit test-menu teardown; final logs have only the known Unicode/NUL warnings.
These startup checks do not replace the 60-second acceptance reports below. No new visual
scores are assigned for a launcher change. Full overhaul remains incomplete.
The visible Forward+ Claude Zombies menu was inspected and left open for Devin. Rendered
startup additionally reports the existing shared Settings SSR deprecation warning.

RESUME HERE: source root-yaw extraction/phase matching for the supplied 45-degree turns,
then stairs/rubble and special-body verification, preserving existing gameplay speeds.

## 2026-11-09 latest checkpoint — zombie clothing detail and final local acceptance

State work is committed as `baa71d96`. The next Stage 3 slice activates the repo's existing
CC0 fabric/leather normal and ORM maps for zombie clothing. Tuning is in
`data/gravelight/zombie_materials.json`; two body surfaces remain. Shared `ZombieBody` gains an
opt-in material path: living people keep the existing defaults and severed pieces retain the
zombie material. No model topology, skin weights, base poses or gameplay speeds changed.

Blender headless material audit: 4 maps, zero failures. Godot: **45/45 zombie tests, 2,679
assertions; 859 scripts, zero failures; 4/4 license tests, 367 assertions; 108-folder manifest
current**. Three before/after material close-ups are in `docs/captures/after/mocap/materials`.
The effect is modest: model quality remains **2/5**, not premium acceptance. The shader sampler
prototype failure and an audit rule that incorrectly checked source blue instead of the actual
RG decode were corrected and rerun; raw diagnostics remain documented. Final captures have no
shader/script/engine errors; Unicode/NUL startup warnings remain.

Fresh near-player 24-active checks, 60 s each:

| Check | Result |
|---|---|
| Rendered real-time frame interval p95 | **4.7619 ms**, under 16.667 ms |
| Zombie synchronous callback CPU p95 | **0.155 ms/actor/frame**, under 0.35 ms |
| Fixed-60 headless planted toe drift p95 | **0.012804 m/s**, under 0.10; 50,255 source-contact samples |
| Fixed-60 root/body mismatch p95 | **1.0104%**, under 5% |
| Both runs | Minimum 24 active; no missing clips/rest samples; 83,520 pose samples each |

Reports: `acceptance_materials_rendered` and `acceptance_materials_motion` under the mocap
capture folder. Hardware remains Ryzen 7800X3D / RTX 5090; this does not certify mid-range/full-map
performance. A license-check process overlapped part of the rendered run, so timing differences
cannot be attributed solely to materials. Fixed-step frame timing is not a performance result.

RESUME HERE: review the supplied 45-degree turns and implement root-yaw/visual-phase matching
without changing gameplay facing or speeds; preserve original clips for comparison. Existing
`mco_turn_l_45` / `mco_turn_r_45` carry +45 / -45 degrees over 1.267 s, unlike the fast existing
facing response. Then stairs/rubble and special-body coverage. Complete the missing source
states and artist-authored model sample in the shopping list before claiming the full overhaul.
No merge, push, export or main-build replacement. Full Stage 2/3/4 acceptance remains open.

## 2026-11-09 previous checkpoint — recorded swipes and deaths active

This section supersedes the earlier locomotion-only state inventory below. The bank now has
**28 converted clips from 26 source FBXs**. Two single-swipe trims sample the supplied arm loop;
no poses were authored. `swipe_l/r` keep their gameplay identities, original enemy windups and
0.35 s recovery. The shared animation path synchronizes the recorded strike for host and puppet
presentation without dealing damage. Existing attack selection still respects severed arms.

Two death visuals are active: logical `death_sit` -> `mco_death_back`, `death_back` ->
`mco_death_hit_back`. Network indices are unchanged. Per-clip key-pose times are data (1.0/0.4 s).
Root travel stays on the visual pivot, resets on pooling, and the evaluated per-bone momentum
continues into ragdoll. Velocity limits are data. The existing explosive impulse and cap remain.

Verification run: Blender/Godot 28/28 imports, **44/44 zombie tests / 2,670 assertions**,
858-script scan with zero failures, Map 2 integration smoke PASS (9 walkers, worst median
root/body discrepancy 1.4%; climbs, severs/Gore Off, knockdown/get-up, deaths, corpse return,
ragdoll peak 6). Four rendered state comparisons and event reports are under
`docs/captures/after/mocap/states/`; both ragdoll handoffs moved bones at most 1.089 cm instantly.
The capture-only early freeze caused by slow PNG writes was corrected by normalizing its clock
to simulated time and rerendering both deaths. Console input is disabled in this silent tool;
final renders have no script/engine/leak errors. Known Unicode/NUL warnings remain.

Soldier visual review: the two swipes **2 -> 3/5**, the two recorded deaths **2 -> 3/5**.
Upright locomotion **2 -> 3**, variety **3 -> 3**, model **2 -> 2** remain the previous ratings.
Reactions/other types are not newly scored. This is still **not** full premium acceptance.
Gameplay speeds, jitter, damage timing, attack ranges and navigation data remain unchanged.

RESUME HERE: finish the remaining state/per-type/stair coverage and Stage 3. The existing
licensed fabric/leather normal and ORM maps are present but the kit shader currently consumes
only their albedo detail: investigate a zombie-only material pass before requesting new art.
An artist-authored soldier head/body/clothing sample is still required for the model target.
Turn recordings are available: 45-degree clips are 1.267 s and 90-degree clips over 5 s;
they require yaw extraction/phase matching to the existing fast facing changes before promotion.
Do not blindly alias them and double the turn. Remaining source gaps are in the shopping list.

## 2026-11-09 earlier delivery checkpoint — licensed locomotion active, full overhaul incomplete

`4177e459` adds the repeatable licensed source pipeline. `eabd2799` enables upright mocap and
contact cleanup. Work remains isolated in `.wt/zombie-overhaul`; main/builds were not replaced.
**All existing gameplay tier speeds and speed jitter are preserved.** No gameplay hit timings,
navigation rules or hitbox sizes changed.

| Runtime tier/state | Current recording | Status |
|---|---|---|
| Shamble 1.3 m/s / walk 2.0 m/s | `mco_chase` | Active; source cadence retimed to actual navigation speed and body height |
| Jog 3.4 / run 4.8 / sprint 5.6 m/s | `mco_fast_chase` | Active; random phase, contact-aligned footsteps, upper-body turn lean |
| Upright idle | `mco_idle`, `mco_idle_2` | Active; selected per activation |
| Crawl 0.8 m/s | Existing crawl clips | Unchanged; supplied crawl's 0.085 m/s stride would need about 9x retiming |
| Attacks, reacts, deaths, interactions | Existing clips | Source alternatives previewable; event trims/root-yaw/ragdoll handoff review still required |

There are **two distinct active recorded gaits**, not five new performances or the full per-tier
variant count. The supplied slow walk remains preview-only. Starter supplies two deaths, not eight.
All 26 original recordings are available in the gallery with their `mco_` names and provenance.
Original model meshes/materials are unchanged; they do not meet the requested premium art bar.

Posture blends initially reintroduced foot drift. The runtime now pins source-annotated toe
contacts after the additive layer using a bounded analytic two-bone correction. Release blends
back into swing; transitions, shoves/teleports and pooled reuse clear the anchors. Precision in
the existing IK arc solve was tightened to avoid discarding small corrective rotations. Footsteps
use each recording's contact onsets, including multi-stride loops, instead of two equal phases.

### Executed verification

| Check | Result / scope |
|---|---|
| Blender 5.1.2 headless conversion | 26/26 FBXs converted; finite poses, loop seam <0.002 rad, source hashes retained |
| Godot imported rig/animation evaluation | 26/26, identical 19-bone rests; 60 Hz pose samples finite, zero identity poses; largest adjacent bone step 28.26 degrees |
| Zombie GUT regressions | 42/42 tests, 2,550 assertions; includes all five preserved speed tiers, source footsteps, contact IK with additive limp and pool reset |
| Script scan | 858 scripts, zero failures |
| License tests / asset manifest | 4/4 tests, 367 assertions; manifest current (108 folders) |
| Near-player 24-active motion acceptance, 60 seconds, fixed 60 Hz | PASS: toe drift p95 **0.01321 m/s** against 0.10 limit, 51,058 source-contact samples; root/body mismatch p95 **2.38%** against 5% limit |
| Near-player 24-active rendered real-time soak, 60 seconds | PASS: frame interval p95 **4.167 ms**, callback CPU p95 **0.149 ms/actor/frame** |
| Near-player 24-active headless real-time soak, 60 seconds | PASS: frame interval p95 **6.944 ms**, callback CPU p95 **0.152 ms/actor/frame** |
| Population / missing clips / sampled rest poses | All three 60-second runs: minimum 24 active, no losses, zero missing clips/rest samples; 83,520 pose samples each |
| Actual Map 2 integration smoke | PASS: nine sampled walkers within 2.6% median root/body speed error in the first run; climb links, IK/look-at gates, sever caps/Gore Off, knockdown/get-up, deaths, capped ragdolls and corpse return checked |
| Ragdoll saturation regression | PASS: 9 admitted, peak 6; frozen/freed slots release their budget |

Hardware: Ryzen 7 7800X3D / RTX 5090. Callback timing wraps the zombie's synchronous process and
physics callbacks; it excludes deferred engine work/GPU cost and other map systems. Full-rate
animation and nearby modifiers were enabled. These are local studio measurements, **not** a
mid-range-machine or full-map GPU performance certification. Fixed-step captures measure motion,
not performance. Old low-foot/low-vertical-speed heuristics remain in reports for comparison and
are not the source-contact acceptance metric. Phase-bin peaks include the emerge transition;
the equal-clip simultaneous-emerge unit regression is the direct synchronization check.

The map smoke previously quit with its map and cached weapon/arm template Nodes alive. Its
finish coroutine now runs once, frees the map, and releases those tool-owned caches. Final rerun:
RESULT PASS, exit 0, zero SCRIPT ERROR/ERROR/leak warnings. Existing Unicode/NUL startup warnings
remain. Earlier validation-only failures (checking consumed engine CLI flags, ffmpeg's missing
font configuration, preview's first unevaluated frame) were corrected and rerun. A full semantic
T-pose/pop detector and every special body's state coverage remain open; identity tests alone
do not certify them.

### What to review / scores

Open `docs/captures/after/mocap_compare/walk_comparison.mp4` and `sprint_comparison.mp4`.
Left is legacy, right is current; same camera/seed/kit/speed. Six tier comparisons and frame
sheets are included. The crawl comparison documents that it is unchanged. Gallery scene:
`res://tools/zombie_gallery.tscn`; use the commands in `docs/captures/after/mocap/README.md`.

Review scale remains 1 placeholder, 2 visibly unfinished, 3 competent motion, 4 premium target,
5 exceptional. **Ganger/soldier upright locomotion: 2 -> 3; appearance variety: 3 -> 3;
model quality: 2 -> 2.** Crawl is unchanged. Reaction and death visual scores are not yet assigned;
their gameplay regressions pass but this pass does not add licensed reactions/deaths. Other enemy
types share the rig but have not received comparable per-type close-ups; they remain unscored.
Do not copy the soldier rating to Foreman/Screamer or claim the full requested scorecard complete.

### Remaining stages / RESUME HERE

Stage 1 is runnable and verified. Stage 2 upright locomotion is delivered; remaining Stage 2
state replacements and most Stage 3 art remain open. Stage 4 now proves the tested motion slice,
not the entire requested overhaul. Next: review/trim the supplied attack loops and two deaths,
preserve attack hit events/network death indices, validate their transitions and ragdoll key-pose
handoff; then implement missing recordings as they arrive. Add special-body captures and real
stairs/rubble tests. Keep all work on this branch and leave main untouched.

ASSETS STILL NEEDED: more distinct compatible-speed gaits (including crawl), missing barricade
tear/vault and climb/emerge performances, directional reactions/knockdown-getup pairs, crawler
bite/armless attacks, and at least six more death performances. Review supplied attack loops
before buying attack gap fillers. Model work needs an original artist-authored soldier head/body
and distressed WW2 clothing sample with albedo/normal/roughness, deformation weights and LOD0-2;
fictional markings only. The supplied Starter pack is already received; do not buy it again.

## 2026-11-09 supplied mocap / Stage 1 checkpoint (supersedes absence below)

Devin supplied `Downloads/FBX_Zombie_27_Starter` and chose **preserve current speeds**.
The local worktree now contains 26 original root-motion FBXs and 26 IPC duplicates, plus unused
Motus demo-model files. They are ignored under `assets/user_supplied/mocap_online/zombie_starter_2_7`.
The manifest-driven Blender converter retargets every source to the 19-bone ZombieRig, preserves
identity rests, closes loop residuals, extracts horizontal root travel and cleans source-detected
upright foot contacts. No locomotion/attack/death performance is invented in code. Turn yaw
remains on the hips; turns are preview-only until root-yaw gameplay handling is validated.
The two 45-degree files are deliberately nonlooping because their end facing differs.

Executed: one-command build, all 26 GLBs imported/checked in Godot with shared Humanoid BoneMap,
856-script scan (zero failures), four license tests (367 assertions), current assets manifest,
and native fast-gait rendered sequence on the soldier. Paid binaries remain local/ignored;
committed hashes/measurements allow reproduction without distributing animation data.
See `docs/captures/after/mocap/` and `tools/zombie_mocap_build.ps1`.

Offline source-contact horizontal toe speed p95: walk 0.119 -> ~0, chase 0.240 -> ~0,
fast chase 0.329 -> ~0 m/s at 30 Hz. Same source masks before/after. These numbers do not
establish runtime foot locking: interpolation, modifiers, blends and navigation need measurement.
The slow crawl is not foot-locked (hand/knee contacts require a different solve). Native target
stride speeds: walk 0.210, chase 0.477, fast chase 2.885, crawl 0.085 m/s. Gameplay tiers stay
1.3 / 2 / 3.4 / 4.8 / 5.6; crawl stays 0.8.

Stage 1 pipeline is runnable. Runtime promotion, event integration and quality review are NEXT.
Stage 3 model quality and full Stage 4 acceptance remain open. Existing verdicts below are dated
baseline history, not a statement that the supplied pack is still absent.

ASSETS STILL NEEDED: additional distinct gaits at compatible speeds, barricade tears/vaults,
climbs, ground emerges, directional flinches, knockdown/get-up pairs, bite/armless attacks and
six or more further death performances (Starter has two); an artist-authored soldier quality
sample with distressed clothing, PBR maps, deformation weights and LOD0-2. See shopping list.

## Final check verdict — not ready for premium-quality sign-off

The branch contains tested phase/footstep and ragdoll-budget fixes, plus reproducible review tools.
It does **not** contain the requested mocap/model overhaul. Do not describe the existing procedural
clips or original body block-outs as new premium zombies. No merge or playable-build export made.

Final checks executed on 2026-11-08:

| Check | Result |
|---|---|
| Godot headless zombie suite | PASS: 39 tests, 1,906 assertions |
| Godot headless script scan | PASS: 855 scripts, zero failed |
| Ragdoll budget stress | PASS: all 9 deaths admitted; peak 6; frozen/freed slots released |
| Blender 5.1.2 headless body import | PASS: 6 GLBs, zero unweighted-vertex errors; 90 UV review findings remain |
| 60 s rendered, full-rate animation, 24 actors | PASS for population: minimum 24, no reclamations, 144 track wraps |
| 60 s headless, full-rate animation, 24 actors | PASS for population: minimum 24, no reclamations, 147 track wraps |
| Missing clips / sampled identity poses in these soaks | Zero / zero, 83,520 pose samples in each run |
| Rendered frame interval on RTX 5090 | p95 4.167 ms; capped bare studio, not per-zombie CPU or target-machine acceptance |
| Headless frame interval | p95 7.576 ms; excludes rendering cost |
| Foot contact | NOT ACCEPTED: heuristic speed p95 6.832 m/s rendered, 7.404 m/s headless |
| Full zero-pop / T-pose certification | NOT ESTABLISHED by the rest-pose heuristic |
| Licensed mocap / polished models | MISSING / below the requested art bar |

Reports and recordings are under `docs/captures/after/final/`. `rendered` and `headless` are the
60-second soaks. `motion` contains fixed-timestep close-up gameplay recordings of the six tiers;
their PNG capture stalls and fixed deltas make their timing fields unsuitable for performance.
The distant studio target leaves IK/look-at outside their normal range for much of a soak.
Full map, near-player modifiers, special bodies, reactions and interactions still need acceptance.

The previous minimum-active failure was a gallery bug: after teleporting a zombie to the back of
the track, the tool kept its old best-distance watch. Repeated laps eventually triggered the
40-second no-progress reclamation. The gallery now rebases those watches at its own teleports.
It does not disable ordinary stall handling or silently replace a reclaimed actor. It records
state counts/losses and returns failure if the requested population drops. Gameplay navigation
and reclamation are unchanged. Inactive actors no longer inflate pose samples.

Visual review finds the soldier's uniform/head too simple and smooth, the movement mechanical,
and foot planting unconvincing. Correct phase variation does not fix those source limitations.
The remaining existing Unicode/NUL startup warnings do not fail the executed checks.
One sprint recording exited without its completion report and emitted renderer/resource cleanup
errors. Its cause is unconfirmed. It was excluded; a fresh sprint rerun completed with its report,
exit 0 and no cleanup errors. This intermittent exit is not claimed fixed.

RESUME HERE: Work only in .wt/zombie-overhaul on codex/zombie-overhaul. The gallery reclamation
defect is fixed and both 60 s / 24-active reruns pass their population checks. Obtain the licensed
source mocap and an artist-authored soldier quality sample listed below; then build and validate
tools/blender/zombie_anim_batch.py, retarget/stride/contact handling and materials on that sample
before expanding the roster. Finish missing Stage 0 special-body/state/pop/CPU coverage alongside
that work. Stages 1/3/4 and most of Stage 2 remain unfinished; do not mark the overhaul delivered.

## Current findings

The spec's opening description is obsolete. The runtime uses ZombieRig (19 bones), ZombieClips,
ZombieBody, ZombieBodyModifier, ZombieGore and ZombieRagdoll. anim.json contains the tuning.
The active clips are generated pose functions, NOT mocap. No MoCap Online zombie pack, FBX or
BVH files were found in assets/user_supplied or assets/third_party in the original checkout.
The supplied ZIP is a weapons pack. docs/ASSETS.md is the existing asset ledger.

| Spec item | Status | Evidence / remaining work |
|---|---|---|
| Shared Skeleton3D / humanoid BoneMap | partial | zombie_rig.gd; imported clip compatibility untested |
| Skinned bodies / builds / kits / LODs | partial | CHARACTER_PIPELINE; six original GLBs, visual quality not scored |
| State machine / blend spaces / additive layers | partial | zombie_clips.gd builds all nine states; procedural sources |
| Root motion / planted feet | partial | root track exists but movement drives playback; existing test only compares speeds |
| Random phase | done | Deferred TimeSeek; equal-clip ground-spawn regression passes |
| Speed jitter +/-10% | partial | activate reads enemies.speed_jitter=0.05, anim.speed_jitter=0.1 is not used there |
| Locomotion variants / turns / lean / posture | partial | configured and generated; licensed motion missing |
| Foot IK / head look | partial | modifiers present; stairs/rubble verification pending |
| Barricade tears / reach / vault / drops | partial | existing hooks and clips; mocap and interaction captures pending |
| Climb links / mantle | partial | existing smoke checks Map 2; not yet rerun |
| Swipes / lunge / grab / crawl bite / armless | partial | _pick_attack handles these; clips procedural |
| Spawn / emerge types | partial | existing rise system; licensed clips absent |
| Directional flinches / stagger | partial | zone clips exist; direction inferred from side, not incoming vector |
| Knockdown / getup | partial | gameplay states exist; verification pending |
| Partial physical bone hit blend | missing | modifier uses damped angular springs, not physical bone simulation |
| 8+ death clips / explosive ragdolls | partial | nine deaths plus crawler, all procedural; physics exists |
| Ragdoll cap / corpse dissolve | partial | live cap stress passes 9 admissions / peak 6; dissolve visual acceptance pending |
| Severed pieces / caps / wounds / gore modes | partial | existing gore system; mesh validation pending |
| Modular gear / tint / infection / damage shader | partial | existing system; 24-instance visual uniqueness not proven |
| Normal maps / texel density / PBR | partial | texture pipeline present; visual and UV validation pending |
| Animation events / surface sound | partial | footsteps now follow evaluated playhead; authored contact/event timing still missing |
| Distance LOD | partial | existing tick throttling; measured cost pending |
| Distant crowd impostors | missing | no audit evidence of implemented billboard crowd |
| 24 zombies / 60 FPS / <=0.35 ms per zombie | partial | 24 active for 60 s on RTX 5090; target-machine/per-zombie CPU requirement unverified |
| Zero pops / T poses / missing clips | missing | compile checks cannot establish these |

## Priorities

1. Finish Stage 0 gallery, runtime clip/mesh inventory, planted-foot samples and rendered baseline.
   Use fixed seed and identical camera/timesteps for comparisons. Keep clip previews distinct from
   real AI tests. Measure actual foot position: matching root speed alone proves too little.
2. Add a manifest-driven licensed clip intake/retarget pipeline. Validate source provenance,
   rest-axis mapping, loop residuals and root displacement in Blender, then import into Godot.
   Do not fabricate missing clips or replace gameplay with unverified retargets.
3. Fix phase initialization and event synchronization, load licensed clips, then validate stride,
   turn blending, modifiers, reactions and caps under a real 24-zombie soak.
4. Validate existing model LODs, UVs, weights, stump caps and materials before changing them.
5. Capture after, compare, score each type, and run full acceptance checks.

## Verification so far

Original checkout: Godot 4.7.2 headless script checker: 854 scripts, zero failed, exit 0.
Unicode/NUL warnings emitted. First sandboxed run had log/certificate access errors; unrestricted
rerun also finished with zero failed. Blender 5.1.2 factory-startup headless probe exited 0.
These are tool/compile baselines, not acceptance results. No art quality or performance pass claimed.

## Scores (1–5)

Scale: 1 placeholder, 2 playable with obvious art/motion defects, 3 production competent,
4 requested premium target, 5 exceptional. Scores are review judgments, not test results.

| Reviewed sample | Locomotion before / after | Reactions | Deaths | Variety before / after | Model before / after |
|---|---|---|---|---|---|
| Ganger / soldier | 2 / 2 | Not scored | Not scored | 3 / 3 (shared horde) | 2 / 2 |

Before: `before/closeup` walk sequence and wide 14-kit previews. After: `after/final/motion`
live tier recordings and rendered horde. Different preview/live modes are explicitly identified;
these are not a controlled locomotion A/B. No change to source motion or model art was made,
and the tested phase/ragdoll fixes do not move these broad visual ratings into a higher band.
Other types and reaction/death quality remain unscored without adequate comparable close-ups.
The requested complete per-type scorecard is unfinished; no 4/5 quality claim is supported.

## ASSETS STILL NEEDED

- MoCap Online zombie pack (source FBX plus license/receipt permitting this use), absent locally.
- Licensed coverage for all required tiers, turns, attacks, barricades, climbs, crawl transitions,
  directional reactions, knockdowns/getups and 8+ deaths. Exact gaps require auditing the supplied pack.
- An original artist-authored zombie soldier head/body and distressed WW2-style outfit with
  PBR maps, deformation weights and LOD0-2 (or commercially licensed editable sources).
  The rendered soldier sample establishes this quality gap. Validate one fitted sample before
  purchasing/commissioning the remaining roster; fictional markings and no prisoner enemies.

## Stage 0 checkpoint results (not stage completion)

- Asset audit executed: 749 files, 64 GLBs, zero malformed-GLB errors. Includes ignored supplied files
  from the original checkout. Full inventory: docs/captures/before/assets.json.
- Runtime inventory: 19 bones, 14 kits, 102 clips; previews captured all 102 with no missing clips.
  Capture pass completed in 117.49 s, exit 0. One additional image shows the 24-body live horde.
- Blender 5.1.2 imported all six zombie GLBs. Skinned meshes have no unweighted vertices;
  90 UV review findings (kits/hair/parts use no UV layer; procedural shader coordinates need review).
  Bone display Icospheres created by Blender's importer are excluded from the audit.
- Rendered bare-studio run: 60.00 s on RTX 5090 / Vulkan Forward+, p95 frame interval 4.166 ms.
  This is neither mid-range sign-off nor per-zombie CPU timing. The initial report includes stationary
  contact samples, so do not treat its median 0 as a sliding pass. Final headless rerun excludes bodies
  below 0.4 m/s and records minimum active count; see before/headless/horde.json.
- 83,520 sampled poses in the rendered horde were not identity/rest poses. This does not establish
  zero T-pose/pop frames. Foot-contact p95 was 4.01 m/s in the initial rendered run: obvious concern,
  but the low-foot/vertical-speed contact heuristic still needs real contact labels.
- Observed failures: existing Unicode/NUL warnings; shutdown RID/ObjectDB/resource leaks even after
  gallery cleanup; missing dev_console action during early rendered runs (gallery now disables that
  autoload's input callback only). Initial nav synchronization error fixed and absent on rerun.
- Stage 0 gaps: special enemy/boss classes, full gameplay state traversal, pop detection,
  active ragdoll cap stress, close-up and per-type scores, true frame sequences/contact annotations,
  per-zombie CPU profiling. Captured previews are wide roster shots, not close-up quality evidence.
- Stages 1–4 not implemented. No gameplay files changed. No locomotion/attack/death keys authored.

## Resume pass: gallery and ragdoll lifecycle

- Added camera-facing labels, single-kit close-ups, per-clip filtering, shared enemy-kind selection
  and 12 Hz PNG frame sequences. Rendered and inspected the soldier walk close-up/sequence.
  Bespoke Foreman/Screamer selection explicitly fails instead of showing the wrong body.
- Shutdown leak source isolated to WeaponModels' unattached template Nodes, loaded by the studio's
  Player. The gallery releases these only at exit. Headless 24-zombie run and rendered close-up
  now exit without RID/ObjectDB/resource-leak reports. No shared weapon code changed.
- Added ragdoll lifecycle stress scene. BEFORE: 6 admitted of 9, last 3 denied; frozen corpses
  still counted against the cap. AFTER: 9 admitted, peak 6, oldest frozen, frozen/freed count 0.
- Fixed ZombieRagdoll: live registry prunes non-simulating bodies; budget pressure freezes the
  oldest simulation and admits the newest death. max_live<=0 still disables admission.
  Existing animation clips, HP, attack timing, navigation and hitboxes untouched.
- Verified focused stress PASS and existing test_zombie_mz_fixes 8/8 tests, 61 assertions PASS.
  Missing GUT font import sidecars in the worktree were copied from the original checkout; rerun
  clean apart from the pre-existing three Unicode/NUL warnings. A temporary variable-name parser
  conflict during development was fixed before these passing runs.
- Stage 0 remains incomplete. Stage 2 ragdoll lifecycle defect fixed opportunistically after its
  baseline test failed; no claim of completed animation overhaul or licensed motion integration.

## Gait phase pass

Ground spawns previously entered Emerge before _random_phase, which only handled zombies already
in Locomotion/Crawl. Random stride offsets are now queued with AnimationNodeTimeSeek until those
states evaluate. Crawlers use their own chosen clip length. The random_phase config switch and
rig-less bodies are respected. No new bone keys or animation sources introduced.

Footstep events now follow the evaluated locomotion state's playhead. This avoids the separate
integrated phase clock drifting during idle blends, initial seeks and attack-to-walk resumes.
The first evaluation synchronizes the event cursor without firing a false step.

Headless GUT: all 39 zombie tests across six files passed, 1,906 assertions. New regression uses
eight same-frame ground spawns with equal walk clips and equal height. It verifies Emerge stays
at its start, queued seeks are consumed on first locomotion, first phases spread over more than
a quarter cycle, and the event phase matches evaluated playback before and after attacks.
Unicode/NUL startup warnings persist. Full motion-quality acceptance and scored improvement
remain unproven. Gallery --horde --emerge now preserves the actual emerge-to-chase transition.

Fresh 60 s headless emerge/horde run: no missing clips, 83,520 pose samples, zero sampled rest
poses, p95 frame interval 6.944 ms. FAILED sustained active-count requirement: minimum active
was 2, so this is not a valid 24-active performance acceptance run. The studio has no director
to replace reclaimed zombies. Investigate state histories/reclamation before using it as a soak.
Contact-foot speed p95 5.985 m/s remains high; this phase fix does not solve foot-sliding.
Full report: docs/captures/after/phase/horde.json. Normal cleanup emitted no resource leak errors.

Historical checkpoint next steps: Open .wt/zombie-overhaul on codex/zombie-overhaul. Complete bespoke enemy coverage,
pop detection and per-zombie CPU profiling; finish before scores. The gallery framing, sequences,
shutdown leak and ragdoll-budget lifecycle are now handled. Next substantive animation work:
licensed-source intake. First-locomotion random phase/event synchronization now has a tested fix.
Pack still absent.
