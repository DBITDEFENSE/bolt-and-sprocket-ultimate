# Claude Fable 5.2 — finish the zombie overhaul

Prepared 2026-11-11 at Devin's request. Continue the existing work; do not restart the audit or
replace the project. The latest verified runtime checkpoint is **bf395bc3** on
**codex/zombie-overhaul**. The full premium art/animation target is **NOT finished**.

## Start in the correct checkout

```powershell
Set-Location 'C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate\.wt\zombie-overhaul'
git status --short
git branch --show-current
git log -5 --oneline
```

Main repo: `C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate`.
Work only in the worktree above. Another agent works on the main checkout. The branch was
created from owner-approved `master e96a0188` because there was no `main` branch. Do not create
a replacement branch, reset, switch the main checkout, or collect another agent's changes.

Read `CLAUDE.md`, the newest `PROGRESS.md` entry, `docs/ZOMBIE_OVERHAUL_PLAN.md`,
`docs/ZOMBIE_ANIM_SPEC.md`, `docs/ART_BIBLE.md`, `docs/CHARACTER_PIPELINE.md`, `ASSETS.md`,
`docs/work_orders/ASSET_SHOPPING_LIST.md`, and the relevant `docs/DECISIONS.md` entries.
Earlier progress/plan sections are dated history: their claims that the pack is missing or
that pushing is forbidden have been superseded. Read the newest sections first.

Devin explicitly authorized pushing the branch. **No merge into main/master, replacement of
the main playable build, or export has been requested.** Keep future commits on this branch.
Use the session's required Co-Authored-By identity. End each slice with a commit, a PROGRESS
entry, and one precise `RESUME HERE:` line. Keep communication short and spend usage on work.

Leave these older untracked diagnostics alone:

- `docs/captures/before/cleanup_check/`
- `docs/captures/before/leak_probe.log`
- `docs/captures/before/leak_probe/`

## Non-negotiable owner requirements

- **Preserve current gameplay speeds and existing jitter.** The tiers remain shamble1.3,
  walk2.0, jog3.4, run4.8, sprint5.6 m/s; crawl remains0.8. Existing jitter is5%, intentionally
  preserved despite the older spec requesting10%. Keep attack timings/ranges, navigation and
  collision shapes intact during this art pass. Bone-attached hitboxes follow animation.
- Motion must come from licensed recordings. Do not generate gait, attack, turn or death bone
  keys with code. Retargeting, trimming, root extraction, contact cleanup, blending, procedural
  additive posture/IK/look-at, and physics are permitted. Existing procedural clips remain as
  fallback; do not count them as newly delivered mocap or disguise aliases as distinct takes.
- Stylized-realistic late-2000s horror is the target. The current simplified bodies are still
  below it. Do not try to sculpt a replacement human with code. Secure an artist-authored
  sample and fit/validate it through Blender before extending the roster.
- Original designs and fictional unit markings only. No real Nazi insignia, copied Call of Duty
  characters, prisoner/forced-laborer enemies, unofficial downloads, or installers.
- Every used asset goes in ASSETS.md with source, license and use. Purchased packs go in
  `assets/user_supplied`. Do not publish raw/derived standalone licensed animation assets.
- Run Godot and Blender checks before making claims. Measure 24-active performance and foot
  contact; do not infer quality from test counts alone. Keep rendered automation offscreen and
  silent, and never kill Godot processes you did not start. Do not interrupt Devin's playtest.

## The purchased pack is already here

Owner supplied `C:\Users\Devin\Downloads\FBX_Zombie_27_Starter` on 2026-11-09. Untouched
sources are already copied to the worktree's ignored
`assets/user_supplied/mocap_online/zombie_starter_2_7/`.

- 26 unique Root_Motion FBXs, plus 26 in-place duplicates of those performances. Not52 takes.
- Unused demo body/rig/textures are retained locally; they are not the game's zombie models.
- Standard License/source URLs and each source clip are recorded in ASSETS.md. The receipt was
  not included; do not invent purchase proof or ask Devin to buy/download this pack again.
- 30 derived clips are built in ignored `assets/zombies/anims/`: the original26, two single-swipe
  trims, and two cleaned root-yaw turn versions. These are not30 distinct performances.
- Source FBXs, derived GLBs and the local `mocap_manifest.json` are intentionally outside Git.
  Code, license notes, metrics and game-footage comparisons are committed. A fresh clone needs
  the owner's sources and the build command below. Runtime has a legacy fallback; the playtest
  launcher checks the licensed bank instead of silently accepting that fallback.

## What is implemented and where

| Area | Current implementation |
|---|---|
| Pipeline | `tools/blender/zombie_anim_batch.py`, `tools/zombie_mocap_build.ps1`, `tools/blender/zombie_anim_import.gd`, `tools/zombie_mocap_check.gd` |
| Source/config | `data/gravelight/zombie_mocap.json`; shared 19-bone ZombieRig and Humanoid BoneMap; source hashes/contact windows retained |
| Runtime bank | `gravelight/enemies/zombie_mocap.gd`, `zombie_clips.gd`; import once, remap tracks to `Skel:Bone`, copy only animation |
| Locomotion | `mco_chase` at shamble/walk; `mco_fast_chase` at jog/run/sprint; recorded idles; actual body speed/height determines cadence; delayed random phase; source-contact footsteps; additive turn lean |
| Contact cleanup | `zombie_contact_lock.gd` pins source toe contacts after additive pose; bounded horizontal correction. `ZombieBodyModifier` handles vertical terrain adaptation separately |
| Swipes | `swipe_l/r` visually map to two reviewed single-strike trims of one arm-loop performance. Original windup, .35s recovery, damage and network names retained |
| Deaths | `death_sit/back` map to the two supplied recordings; visual root displacement, per-clip1.0/.4s handoff, measured per-bone momentum into ragdoll; cap6 and pooling retained |
| Turns | New visual-only `Turn` tree state, `zombie_turn_motion.gd`; cleaned `mco_turn_l/r_45_yaw`. Root-yaw extraction avoids double rotation; visual pivot follows source yaw while gameplay body faces as before |
| Turn boundaries | Stationary upright CHASE/TO_WINDOW below.5m/s, 25-65degree requests, native1.267s clips; source-contact IK/events; movement/attack/state-change cancellation and pool resets; tuning in JSON |
| Clothing | `data/gravelight/zombie_materials.json`, `zombie_kit_detail.gdshaderinc`; existing CC0 Fabric031/Leather014 normal/ORM detail, rest-space triplanar projection, two body surfaces. Zombie-only material cache; living people retain their prior material |
| Preview | `tools/zombie_gallery.tscn`, `tools/zombie_turn_check.tscn`, `tools/zombie_state_check.tscn`; `tools/zombie_playtest.ps1` opens this checkout, while normal main `Play.bat` still opens main |

Useful history: `4177e459` pipeline; `eabd2799` locomotion/contact; `baa71d96` swipes/deaths;
`e8bc3d67` material detail; `24f8078a` playtest launcher; `bf395bc3` stationary turns.

## Verified evidence at the turn checkpoint

| Executed check | Result / qualification |
|---|---|
| Blender5.1.2 headless, two new turn conversions | Exact world-pose reconstruction after root-yaw factorization, worst4.5e-16m; only cleanup/retargeting |
| Godot4.7.2 imported bank | 30/30; rest/BoneMap/provenance/finite-pose checks; Root yaw tracks match curves at60Hz |
| Zombie unit suite | 46/46, 4,066 assertions; includes both turn directions at35/45/60degrees, root extraction, contact, facing, attack interruption, pooling |
| Script scan | 860 scripts,0 failures. Root `tools/` scenes are additionally verified by running them |
| License gate / manifest | 4/4,367 assertions;108 folders current |
| Stationary turn studio, headless + rendered | 175 source-contact samples, toe drift p95.008172m/s; max visual heading step11.25 ->1.7943degrees/frame at60Hz; body-facing error<.000006degrees |
| Turn interruptions | Movement and attack checks passed; angle compensation clears. Subsequent fast gameplay facing is intentionally retained |
| 60s rendered near-player24-active gallery | frame interval p954.5455ms; synchronous zombie callback CPU p95.192ms/actor/frame |
| 60s fixed-60 headless motion gallery | 51,308 source contacts; toe drift p95.01245m/s; root/body mismatch p95.5694% |
| Both60s horde checks | minimum24; no missing clips or sampled identity/rest poses;83,520 poses each |
| Map2 integration smoke | PASS;9 walkers worst median root mismatch.7%; climb, severs/Gore Off, knockdown/get-up,8 deaths, ragdoll peak6/cap6, corpse return, distance IK/look-at gates |

The machine is Ryzen7800X3D / RTX5090. This is not mid-range hardware or full-map performance
acceptance. The moving-horde run is not a24-simultaneous-stationary-turn benchmark. Fixed-fps
timing is not a performance result. Contact measurements exclude entry blends/track wraps;
identity-pose sampling does not prove zero semantic T-poses or all pose pops.

Final scoped logs had no script/shader/engine/leak errors. Existing Unicode/NUL startup warnings
remain; the actual menu can also report the shared SSR-setting deprecation. An initial license
command used a nonexistent test filter and ran no tests; the correct filter below was rerun.
Verify test counts as well as exit status (GUT can exit0 after a filter matches nothing).

Evidence paths:

- `docs/captures/after/mocap/turns/comparison.mp4` and `turns/README.md`: latest turn comparison,
  rendered/headless and interruption reports. Left prior turn; right recorded turn.
- `docs/captures/after/mocap/acceptance_turns_motion/horde.json` and
  `acceptance_turns_rendered/horde.json`: latest60s acceptance.
- `docs/captures/after/mocap/godot_import.json`, `conversion.json`: import/conversion reports.
- `docs/captures/after/mocap_compare/`: existing tier comparisons.
- `docs/captures/after/mocap/states/`: swipes/deaths with actual state callbacks and handoffs.
- `docs/captures/after/mocap/materials/`: clothing close-ups. Earlier hardware/results are history.
- `.mocap_work/zombies/turn_*.log`: local detailed run logs; raw captured PNGs are also ignored.

Current subjective scores for the reviewed soldier/Ganger: locomotion2->3, two swipes2->3,
two deaths2->3, stationary turns2->3, variety3->3, model2->2 out of5. Other types/reactions
were not freshly scored. Do not turn these limited reviews into a full-roster sign-off.

## Next work, in order

1. **Close the co-op turn gap.** `_face` gives the host controller its intended destination,
   but `_puppet_tick` supplies observed interpolated yaw. Small per-snapshot increments can
   remain below the25degree trigger. Reproduce with a real host/client pair and a stationary
   facing target; then use a stable presentation trigger/accumulated angle or appropriate
   existing animation-event transport. Do not simply lower the threshold until network jitter
   triggers step animations. Preserve gameplay-facing response, snapshot semantics and attack
   timing; test interruption, redirect, wraparound, pool reuse and packet jitter. Keep any shared
   networking change minimal and identify it in the commit message.
2. **Stairs/rubble and special-body coverage.** Build repeatable cases using real collision and
   foot rays. Check all three builds/sexes/height variants, crawler, Glasshide, Bellringer and
   other special enemies; Foreman has a bespoke rig. Test turn-to-move/attack/death, rapid target
   changes, large turns and animation LOD distances. Capture actual evaluated/rendered feet and
   pose continuity, not only root-speed agreement. Diagnose limits before tuning tolerances.
3. **Review the unused supplied states.** Raw90degree turns, reach/attack loops, stand-up and
   knockback variants exist locally. Review timing and semantics before promoting them. The
   raw90degree turns last over5seconds; they are not a direct replacement for fast gameplay
   facing. The supplied crawl moves only about.085m/s; forcing it to the preserved.8m/s was
   rejected as roughly9x playback. The slow walk is preview-only. Never alias an unreviewed
   multi-hit barrage to a single existing damage event.
4. **Fill genuine recording gaps** from the list below. Continue the reusable tooling with
   existing sources; do not invent eight deaths or multiple gaits from the same performance.
5. **Bring one artist-authored soldier to the art bible.** Fit head/body/clothing/PBR and
   deformation weights to the shared rig, check texel density/normals/UVs, build LOD0-2,
   dismemberment pieces/stump caps and modular swaps with Blender. Review close-ups in the
   actual game's light. Then extend the roster. Current generated anatomy/clothing geometry
   is the main visual limitation; adding texture noise alone will not solve it.
6. **Finish Stage4 evidence.** Per-type before/after scores, state coverage, real pose-pop/T-pose
   checks,24-active soak, ragdoll saturation and mid-range/full-map profiling. Keep remaining
   unsupported claims marked partial/missing in the plan. Preserve source-asset license records.

## Assets still needed

- Original artist-authored WW2-style zombie head/body/distressed clothing sample with editable
  meshes, clean deformation weights, albedo/normal/roughness and LOD0-2; fictional marks only.
- Distinct appropriate-speed gait variants, especially upright shamble/walk and a usable.8m/s
  crawl. Existing active upright motion uses two recordings, not the full per-tier variant count.
- Two more distinct swipes, runner lunge, sprinter grab, crawler bite and armless attack set.
- Barricade tear/reach/vault and climb/mantle/drop, emerge/water/portal recordings as required
  after reviewing what's already supplied. List actual uncovered states, not blanket rebuy requests.
- Directional hit reactions and front/back knockdown/get-up coverage.
- At least six more distinct death performances to reach eight licensed deaths.

Keep `docs/work_orders/ASSET_SHOPPING_LIST.md` current. The Starter pack is received and must
not appear as something Devin needs to purchase again. There is no new approved asset purchase.

## Commands you can repeat

Use the existing installations; install nothing. From the worktree:

```powershell
$zombieGodot = 'C:\Users\Devin\PROJECTS\bolt-and-sprocket-ultimate\tools\dl_godot\Godot_v4.7.2-stable_win64_console.exe'
$zombieBlender = 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe'
$zombiePython = 'C:\Program Files\Blender Foundation\Blender 5.1\5.1\python\bin\python.exe'

# Full repeatable build: Blender retarget + Godot import/presets + verification.
./tools/zombie_mocap_build.ps1 -Godot $zombieGodot -Blender $zombieBlender

# Scoped verification after relevant changes; inspect the actual summaries and errors.
& $zombieGodot --headless --audio-driver Dummy --path . res://tools/zombie_mocap_check.tscn
& $zombieGodot --headless --audio-driver Dummy --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gselect=test_zombie -gexit
& $zombieGodot --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/check_scripts.gd
& $zombieGodot --headless --audio-driver Dummy --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gselect=test_license_gate -gexit
& $zombiePython -I tools/assets_manifest.py --check
& $zombieGodot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_zombie_anim.tscn
& $zombieGodot --headless --audio-driver Dummy --path . res://tools/zombie_ragdoll_check.tscn

# Turn state: real facing/tree, plus separate move/attack cases if changed.
& $zombieGodot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/zombie_turn_check.tscn -- --out=res://.mocap_work/zombies/fable_turn
& $zombieGodot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/zombie_turn_check.tscn -- --interrupt=attack --out=res://.mocap_work/zombies/fable_turn_attack

# Fixed timestep for contact acceptance; serial real-time rendered run for performance.
& $zombieGodot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/zombie_gallery.tscn -- --horde --full-rate --near-player --seconds=60 --verify-motion --out=res://.mocap_work/zombies/fable_motion
& $zombieGodot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools/zombie_gallery.tscn -- --horde --full-rate --near-player --seconds=60 --verify-performance --out=res://.mocap_work/zombies/fable_performance

# Offscreen capture/review, when Devin is not playing. ffmpeg is already on PATH.
./tools/zombie_turn_compare.ps1 -Godot $zombieGodot
./tools/zombie_state_compare.ps1 -Godot $zombieGodot

# Interactive only when requested; defaults silent, add -Sound for audio.
./tools/zombie_playtest.ps1
./tools/zombie_playtest.ps1 -Mode Gallery
```

Use the console Godot binary for build/capture scripts. PowerShell invocation of the GUI binary
returns immediately; the playtest launcher explicitly waits during its headless check. Native
stderr warnings may produce PowerShell error records without an engine failure: capture
`$LASTEXITCODE`, inspect logs, and require the expected PASS/test count. Use `login:false` with
exec tools. Never print huge one-line cached motion JSON; parse just the fields needed.

The source-cache retargeter renames source Root to MotionRoot before mapping because Motus has
both Root and Hips. Do not remove that fix. Imported GLBs already have the target identity rests;
do not apply a second automatic T-pose/rest conversion. For cloth normals, runtime reconstructs
Z from RG; do not reject the resized source image just because its unused blue channel differs.

RESUME HERE: In `.wt/zombie-overhaul` on `codex/zombie-overhaul`, reproduce and fix the co-op
stationary-turn trigger with real snapshot traffic, then run the terrain/special-body matrix.
Preserve all gameplay speeds. Commit each verified slice, update the plan/progress, and continue
the remaining recording/art work until the original premium target is actually supported by evidence.
