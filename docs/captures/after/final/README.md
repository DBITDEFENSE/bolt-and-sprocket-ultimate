# Final zombie review — 2026-11-08

**Quality verdict: below target.** These are recordings of the existing procedural animation
sources and original models, with phase/footstep/ragdoll fixes. No licensed mocap has been imported.
The branch is `codex/zombie-overhaul`; nothing was merged into or exported over the main game.

- `motion/walk.mp4`: live AI, soldier close-up, randomized stride and additive posture.
- `motion/shamble.mp4`, `jog.mp4`, `run.mp4`, `sprint.mp4`, `crawl.mp4`: the other live tiers.
- `preview/walk_a.mp4`, `swipe_l.mp4`, `stagger.mp4`, `death_back.mp4`: direct source-clip
  previews. These bypass the gameplay blend tree; the death preview does not test ragdoll blending.
- `rendered/horde_24.png` and `rendered/horde.json`: 60 s rendered / 24-active studio test.
- `headless/horde.json`: separate 60 s headless / 24-active test.
- `blender_meshes.json`: six Blender imports; zero unweighted vertices; 90 UV review findings.
- `motion_contact.png`: rows top to bottom are shamble, walk, jog, run, sprint, crawl;
  columns sample 2.0, 2.25 and 2.5 seconds. Use the videos for timing judgments.
- `soldier_comparison.png`: earlier preview left, final preview right. Same source art/clip;
  the final viewer removes the inherited center divider that obscured the feet. This is a
  framing correction, not improved model geometry or animation.

Raw PNG motion frames remain available locally beside each report but are not committed.
Videos encode them at 12 fps. Motion runs use Godot `--fixed-fps 60`; their reported frame
interval is a fixed simulation delta and **must not be used as a performance result**.
The unpaced 60-second runs are separate. They also do not establish mid-range hardware or
0.35 ms/zombie CPU acceptance, and the distant target leaves near-player modifiers mostly off.

The first sprint capture exited without a completion report and emitted renderer/resource
cleanup errors. Excluded from acceptance. `motion/sprint_retry/horde.json` records the completed
rerun (exit 0, no cleanup errors); `sprint.mp4` is encoded from that rerun. Cause of the first
exit is unconfirmed. An exit code alone is insufficient: verify the gallery completion report.

Observed: phase spread works; uniforms/head geometry remain simplified, feet do not read as
firmly planted, and the gait lacks the requested weight. Reviewed soldier model and locomotion
remain 2/5 before and after. Full per-type/reaction/death scores are not certified.

Full results, scope and remaining assets: [ZOMBIE_OVERHAUL_PLAN](../../../ZOMBIE_OVERHAUL_PLAN.md).
