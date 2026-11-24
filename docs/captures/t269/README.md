# T-269 renders

`before/` is master's zombie code (c5d5b5e0), `after/` the branch, `after_norim/` the branch with
`-- --zombie-look=norim` (no floor light, no rim). All made by `tools/wsl_zombie_look.sh` under WSL + Xvfb, Forward+ on
lavapipe, 1280x720, the 3D at two thirds. The pictures were rendered as PNG, measured (`stats.json`,
`tools/zombie_look_stats.py`), then stored as JPEG (quality 88): to measure again, render again.
`<scene>_bg` is the empty view the crowd's pixels are taken against. `look.json`: who stands in each scene (kit,
build, sex, outfit, instance parameters), surfaces and materials per walker, draw calls, the gallery's order.
Notes: `docs/u21/t269_zombie_look.md`.
