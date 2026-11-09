# Zombie overhaul audit — 2026-11-08

Base: master e96a0188; branch codex/zombie-overhaul in .wt/zombie-overhaul.
The owner approved master because main does not exist. No new animation poses or assets authored.

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
