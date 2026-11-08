# Zombie overhaul audit — 2026-11-08

Base: master e96a0188; branch codex/zombie-overhaul in .wt/zombie-overhaul.
The owner approved master because main does not exist. No new animation poses or assets authored.

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
| Random phase | partial | _random_phase only advances if already in Locomotion/Crawl; ground spawn enters Emerge |
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
| Ragdoll cap / corpse dissolve | partial | config max_live=6 and 8–12 seconds; fresh cap test pending |
| Severed pieces / caps / wounds / gore modes | partial | existing gore system; mesh validation pending |
| Modular gear / tint / infection / damage shader | partial | existing system; 24-instance visual uniqueness not proven |
| Normal maps / texel density / PBR | partial | texture pipeline present; visual and UV validation pending |
| Animation events / surface sound | partial | footsteps use separate _cycle clock; can disagree with randomized tree phase |
| Distance LOD | partial | existing tick throttling; measured cost pending |
| Distant crowd impostors | missing | no audit evidence of implemented billboard crowd |
| 24 zombies / 60 FPS / <=0.35 ms per zombie | missing | fresh target-machine measurement required |
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

All types: before NOT SCORED / after NOT SCORED. No rendered frames reviewed yet. Assigning numbers
from source inspection would misrepresent evidence. No visual/runtime overhaul completed yet.

## ASSETS STILL NEEDED

- MoCap Online zombie pack (source FBX plus license/receipt permitting this use), absent locally.
- Licensed coverage for all required tiers, turns, attacks, barricades, climbs, crawl transitions,
  directional reactions, knockdowns/getups and 8+ deaths. Exact gaps require auditing the supplied pack.
- Any additional body/head/outfit assets only after rendered roster review identifies actual gaps.

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

RESUME HERE: Open .wt/zombie-overhaul on codex/zombie-overhaul. Finish Stage 0 gaps above;
first improve preview framing/labels, add special-enemy coverage and inspect shutdown leaks.
Then commit the completed baseline and proceed to licensed clip intake (pack is still absent).
