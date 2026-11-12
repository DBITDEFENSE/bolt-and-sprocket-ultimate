# Try the pushed zombie branch

Run from this checkout, not the main checkout's `Play.bat`:

```powershell
./tools/zombie_playtest.ps1
```

This opens the Claude Zombies menu using the worktree's code and its locally converted mocap.
Choose Play and Solo to try a match. The launcher finds the existing Godot executable in the
main checkout; it installs nothing and leaves the main checkout/build unchanged. Audio is
silent by default; add `-Sound` for normal game audio.

For a ten-minute live 24-zombie studio preview:

```powershell
./tools/zombie_playtest.ps1 -Mode Gallery
```

`-HeadlessCheck` verifies startup and exits automatically. Pass `-Godot <path>` if needed.
Logs live in `.mocap_work/zombies/playtest_game.log` or `playtest_gallery.log`.

The new stationary-turn comparison is `docs/captures/after/mocap/turns/comparison.mp4`:
prior turning on the left, recorded stepping turns on the right. Run
`res://tools/zombie_turn_check.tscn` for its live six-second studio sequence.

The branch on GitHub includes code, reports and comparison videos. Purchased FBXs and derived
animation GLBs remain local under `assets/user_supplied/` and `assets/zombies/anims/`.
They are already built in Devin's `.wt/zombie-overhaul` worktree. A fresh checkout needs the
owner's source pack and `tools/zombie_mocap_build.ps1`; the launcher checks this instead of
silently showing fallback animation.
