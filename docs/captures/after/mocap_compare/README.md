# Motion comparisons — 2026-11-09

Open `walk_comparison.mp4` and `sprint_comparison.mp4` first. Left is the legacy animation;
right is the licensed-mocap runtime. Shamble, walk, jog, run, sprint and unchanged crawl each
have a six-second recording, 12 captured frames/s, fixed 60 Hz simulation. The matching JPEG
sheets show six timestamps. Camera, seed, kit, input speeds and tool settings match.

The supplied pack's Chase is used for shamble/walk; HyperChase for jog/run/sprint. This is two
recorded locomotion performances, not five newly authored variants. Their animation rates fit
the existing gameplay speeds. Current speed jitter remains unchanged. Crawl keeps its existing
clips: the supplied slow crawl would require about 9x retiming at the preserved 0.8 m/s speed.

Look for the planted toes during weight transfer, irregular arm/shoulder motion, and the varied
stride phase in the 24-body screenshot in `../mocap/acceptance_rendered/`. Contact correction
uses the recording's foot intervals after the additive limp/posture layer, with a bounded IK
adjustment and release into the next swing. Fast turns get an additive upper-body lean.

These videos are visual evidence, not performance measurements: frame capture stalls and fixed
deltas invalidate their frame-time fields. Real-time performance uses separate 60-second runs.
The model, clothing, attacks and deaths are unchanged in these comparisons. They remain below
the requested premium art bar. Soldier review: upright locomotion 2 -> 3/5; model 2 -> 2/5;
appearance variety 3 -> 3/5. Reaction/death art and other enemy-specific ratings remain unscored.

Regenerate with `tools/zombie_capture_compare.ps1 -Godot '<installed Godot console path>'`.
Raw frames stay local; only compact review artifacts and reports are tracked.
