# UPDATE 12 contracts (the lead's rules for the workers)

Work order: `docs/work_orders/UPDATE_12_LOOK_AND_CUTSCENES.md`. DECISIONS paragraphs T-207..T-2xx (U11 follow-ups use T-204..T-206).

## C1. Branches and ownership
| Section | Branch | Owns (others don't edit) |
|---|---|---|
| §1 bible + grades + style frames | `u12-1-bible` | `docs/ART_BIBLE.md` (rewrite, keep the old asset rules as a section), `data/look/*.json` (values), `docs/look/` |
| §2 post stack + materials | `u12-2-post` | `gravelight/world/look/look_post.*`, the post shader(s), `tools/look/material_audit*`, material edits on maps |
| §3 archive reels | `u12-3-reels` | `tools/cinema/`, `docs/cutscenes/`, `assets/user_supplied/cutscenes/`, the `cinema_video` shot type |
| §4 mocap + lip sync | `u12-4-mocap` | `tools/mocap/`, `docs/MOCAP_GUIDE.md`, `assets/user_supplied/mocap/`, `gravelight/world/lipsync*` |
| §5 GRAVELIGHT ONE | `u12-5-c47` | the Map 0 wreck art, `assets/user_supplied/u12/c47/`, the C-47 Blender build, minimap re-bake of Map 0 |
| §6 background aircraft | `u12-6-aircraft` | the living-world aircraft data + models |

## C2. The look data (`data/look/<map_id>.json`), applied by `gravelight/world/look/look_grade.gd`
`look_grade.gd` (class `LookGrade`) is written by §1 first (Environment-only), and extended by §2. Map ids are the MapRoot `map_id`s (`map00_crossroads`, `map01_kaltenbrunn`, `map02_*`, `map04a..d`), plus `menu` and `cinema_reel`.
```json
{
  "map": "map00_crossroads",
  "tonemap": "filmic", "exposure": 1.0, "white": 6.0,
  "adjust": {"brightness": 1.0, "contrast": 1.08, "saturation": 0.62},
  "lut": null,
  "tint": {"shadows": "#2a3340", "highlights": "#d9c9a8", "amount": 0.25},
  "ambient": {"energy_scale": 0.7},
  "fog": {"density": 0.012, "color": "#5b6672", "volumetric": 0.02, "sky_affect": 0.6},
  "post": {"grain": 0.05, "vignette": 0.35, "edge_soft": 0.2, "ca": 0.0015},
  "accents": {"violet": "#8a4dff", "red": "#8f1d1d"},
  "zones": {"<zone or sub-area id>": {"...": "any of the keys above, merged over the map's"}}
}
```
- Absent keys = leave the map's current value alone. A map with no file = untouched.
- `LookGrade.apply(env: Environment, map_id: String, zone := "")` and `LookGrade.post_params(map_id) -> Dictionary`. Cutscenes on a map use that map's grade; reels use `cinema_reel`.
- The graphics settings toggle each piece (grain, vignette, CA, fog quality); the web profile uses `data/look/_web.json` overrides.

## C3. Rendered runs on the owner's PC
The owner is away and the work order needs captures, so off-screen rendered runs are allowed: ALWAYS `--position -4000,-4000 --audio-driver Dummy`, short, and ONE GPU run at a time across all workers. Take the lock first with an atomic mkdir, release it after:
```sh
L=/c/Users/Devin/PROJECTS/bolt-and-sprocket-ultimate/.claude/gpu.lock
until mkdir "$L" 2>/dev/null; do sleep 20; done; echo "$$ $(date +%T) <who>" > "$L/owner"
... the run ...
rm -rf "$L"
```
If a lock is older than 30 minutes, check its owner file and the process list before taking it over. Never kill a Godot process you didn't start.

## C4. Files only the owner can supply
Never block on them: build a stand-in, auto-pick-up when the file appears, and write one exact line for `morning/NEEDS_DEVIN.md` in your report (the lead writes the file).

## C5. Always
`master` launches; the egg guard test stays green (quest files frozen); licence gate (`SOURCE.txt` + `LICENSE.txt`, `python -I tools/assets_manifest.py`); headless tests; commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; don't push or merge to master (the lead merges).
