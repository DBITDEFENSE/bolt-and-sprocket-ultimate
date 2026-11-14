# Cinema finishing pass, 2026-11-14

Owner request: finish the scary, realistic replacements based on the existing cutscenes, improve them further, and have Claude push them.

The first pass is already committed as 15c61289 and is in current master. Current finishing edits are only ftd_front.gd and trench_water.gdshader: textured wet earth, timber revetments and broken, restrained water reflections. Preserve other agents' changes and the unrelated untracked shots_npcs_map00.gd.uid.

Please review these changes, improve remaining obvious visual defects if needed, render the nine shots via tools/cinema/review.tscn offscreen/silent, inspect the affected frame, run the relevant script/cinema checks, and commit and push the cinema changes to the intended remote branch. Do not force push or stage unrelated work. Update this note with actual validation and commit/push outcome. User explicitly requested Claude perform the push.

Godot: tools/dl_godot/Godot_v4.7.2-stable_win64_console.exe. Render approval already given: --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools/cinema/review.tscn. Output docs/captures/cinema_horror/review. No visible windows or audible audio.

## Outcome (Claude, 2026-11-14 evening)

Reviewed the finishing diff (MaterialLibrary "dirt" earth as in ftd_rear.gd, the revetment geometry against the 2 m cut, the water shader) and fixed what the render still showed:
- the revetments were a perfectly even fence: about 1 board in 10 is now missing, a quarter sag or lean, and they sit at slightly varied depths;
- the revetment loop drew from the set's shared `rng`, which moved every later prop (duckboards, wire, shell holes). It now uses its own seeded RNG, so the rest of the set keeps the layout the shots were framed on;
- the trench water still read as a flat grey sheet of sky: stronger rain ripples plus slow, dull silt patches (rougher, less specular, darker). The shell-hole ponds now use a plain dull material instead of the trench-water shader.

Validation, all on the PC, headless or off-screen and silent:
- `check_scripts.gd`: 937 scripts, 0 failed.
- GUT `-gselect=test_cinema`: 62/62 passed. `-gselect=test_look`: 29/29 passed.
- `tools/cinema/review.tscn` at 1280x720, `--position -4000,-4000 --audio-driver Dummy`: all nine frames OK, COMPLETE, no shader or script errors; the frames are re-captured in docs/captures/cinema_horror/review. `front.png` inspected: braced, boarded walls with gaps, duckboards, dark broken water. The other eight frames come from sets this pass didn't touch.
- Not re-run: the `cinema_horror_flow` smoke. Its PASS (below) predates this pass, which only changes the front set's geometry and materials.

Still open: a small pale quad sits on the far right parapet skyline in `front.png`. It was already in master's capture, and it isn't the shell-hole ponds (changing their material left it unchanged). It hasn't been identified yet.

Commit and push: on `claude/cinema-horror` (fast-forward from 15c61289), pushed to `origin/claude/cinema-horror`, then merged into local master. Master was not pushed: it was already 20 commits ahead of origin with UPDATE 18, which is the owner's call to publish.

## Earlier notes

Existing evidence: 62 cinema tests, 9 grade tests, 912 script check pass. Contrary to the previous assistant summary, .smoke_logs/cinema_horror_flow.log has RESULT: PASS at line 99: all five scenes complete and skip, first-launch menu, campaign handoff to round 1, solo Kaltenbrunn all passed. Headless shutdown then reports resource leaks; do not describe that as a failed playback test. Earlier render showed the low trench shot as bare dark walls and flat gray water, motivating this finishing edit. The other shots remain real-time 3D using existing character models; do not describe them as photorealistic video.
