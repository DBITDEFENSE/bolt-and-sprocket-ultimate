# CHARACTER_PIPELINE: making a skinned human for GRAVELIGHT (T-091)

Every humanoid in the game (the Gänger hordes now; the squad, Jakub, the patrons and the Cousins next) is built by
script in headless Blender, skinned to the one shared skeleton (`ZombieRig`, 19 bones named after Godot's
`SkeletonProfileHumanoid`), and merged in Godot into a two-surface mesh that every MZ clip, posture layer, IK
modifier, gore cut and ragdoll already understands. Nothing is painted by hand and nothing is downloaded: the bodies,
clothes and skin textures are all "Ours" (`assets/ours/characters/LICENSE.txt`). This page is the how-to.

## 1. The pieces

| File | What it does |
|---|---|
| `tools/export_rig.tscn` (`export_rig.gd`) | Exports the rig (anim.json "skeleton" through `ZombieRig`) to `tools_src/blender/characters/rig.json`: bone names, parents, rest heads in model space, the hitboxes, the build scales. Re-run when the skeleton changes. |
| `tools_src/blender/characters/common.py` | Godot-frame helpers (a Godot point (x, y, z) is Blender (x, -z, y); the glTF exporter maps it back), mesh/weight/UV/armature/export utilities. |
| `make_body.py` | The parametric body: `Params(build, female, living)` → `build(P)` → arrays (verts, faces, 4 bone weights, region per vertex: 0 trunk / limbs, 1 head, 2 hands), the face parts, two hair cuts. Run alone it exports one body GLB. |
| `make_kits.py` | The nine outfit kits as clothing meshes fitted to a built body, plus the body vertices each kit hides. |
| `make_textures.py` | The shared skin texture set (albedo / normal / ORM) baked with Cycles on the canonical body's UVs, and the armband emblem. |
| `build_all.py` | Everything: six bodies (thin / medium / heavy × m / f) with kits and LODs into one GLB each, then the textures. |
| `preview.py` | Workbench renders (front / side / three-quarter / face) for iterating without Godot. |
| `tools/build_characters.sh [--living] [--only=m_medium] [--no-textures]` | Runs build_all, writes the `.import` files from the presets and imports (a worktree falls back to the main checkout's Godot). |
| `data/gravelight/art/characters.json` | Part keys, kit bit order, file names, budgets, body knobs (A-pose angle, subsurf level, head resolution, how sunken a living face is), LOD mode, hair per kit. |
| `gravelight/enemies/zombie_body.gd` | Loads the GLBs (`base_parts`), merges a body + kit (`build_skinned` for zombies, `build_living` for people), cuts gore pieces, owns both shaders. |

Output: `assets/ours/characters/zombie_base/char_zombie_base_<m|f>_<build>.glb` + `tex_zombie_skin_*.png`, and
`assets/ours/characters/human_base/char_human_base_<m|f>_<build>.glb` + `tex_human_skin_*.png` (`--living`).

## 2. How a body is made (make_body.py)

1. **Block-out.** A skin-modifier skeleton in an **A-pose** (arms 42° out, so the weights can tell an arm from the
   ribs): seven trunk nodes from the hips to the top of the neck, nine per leg (hip, thigh, above the knee, knee, calf,
   shin, ankle, ball, toe + a heel), eight per arm, each with an elliptical radius scaled by the build
   (`anim.json builds`: w, shoulder, female w / shoulder / hip) and the limb factor. Note the skin modifier turns its
   frame on the legs: radii there are (depth, width).
2. **Subdivide** (Catmull-Clark, `body.subsurf` = 2) and **sculpt** with smooth displacement fields in the Godot
   frame: pecs or breasts, collarbones, trapezius slope, shoulder blades, spine groove, buttocks, a heavy belly, the
   sunken belly of a thin corpse, knee caps. Each field is a few lines in `sculpt_torso`; add your own the same way.
3. **Weights** (`bone_segments` + `distance_weights`): each rig bone is a segment with a radius; a vertex's raw
   weight is (radius / distance)^6, left / right bones masked to their side, top four kept, tiny ones pruned. Then
   **unpose**: the A-pose is taken back to the rig's rest (arms hanging, identity rest rotations) by inverting the
   same linear-blend skinning Godot runs, so what you weighted is how it bends.
4. **Head** (`head_mesh` / `head_shape`): a quad-sphere (`body.head_res` per cube face) pushed into a skull by
   displacement terms you can read and tune: jaw narrowing, back of the skull tucked into the neck, chin, brow ridge,
   **eye sockets** (depth = 10 mm + 12 mm × `sink`), cheekbones and hollow cheeks, temples, ears, the nose profile,
   nostrils, lips and the mouth slit (faces between the lips are removed: the mouth is a real opening). Weights:
   Head; the jaw region (below the mouth, in front of the ears) on **Jaw** (so the MZ slack-jaw keys open it); the
   neck stub blends into Neck.
5. **Hands**: a rounded palm, four three-segment fingers curled into a claw (`claw` 0.55 dead, 0.3 living) and a
   thumb, on Hand with the wrist blended into LowerArm.
6. **Parts** (kit surface, keyed): eyes (dead: a flattened violet lens deep in the socket, key `eye`, emissive;
   living: `eye_white` + `iris`), upper teeth (Head), lower teeth (Jaw), the dark mouth cavity (half Head, half Jaw).
7. **Hair**: `Hair_m` (short crop) and `Hair_f` (drawn back into a low bun) are the head surface floated above the
   skin inside a smooth hairline and sunk under it outside, so the edge is the curve, not the quad grid.
8. **UVs**: the medium male is smart-projected, the head scaled ×2.2 and the hands ×1.4 in texel density, re-packed.
   Every other body transfers that layout (`build_all.transfer_uvs`: each face casts its corners out from its bone's
   axis onto the canonical surface; the head and hands copy directly), so **one texture set fits all six bodies**.
9. **Budget**: the body is collapse-decimated to `body.body_tris` (7 200) after the UVs; `Body_LOD1` / `Body_LOD2`
   (50 % / 25 %) are exported too.

### Parameters you will touch

| Knob | Where | Effect |
|---|---|---|
| `Params(build, female, living)` | make_body | thin / medium / heavy, sex, dead or alive |
| `w`, `shoulder`, `hip` | anim.json `builds` (exported into rig.json) | trunk width, shoulder width, female hips |
| `belly`, `lean`, `limb` | `Params.__init__` | belly forward, ribs / sunken belly (dead only), limb thickness |
| `sink` | characters.json `body.living_sink` (living) / 1.0 (dead) | eye-socket depth, hollow cheeks, temples |
| `head_res`, `subsurf`, `body_tris` | characters.json `body` | head detail, body smoothness, triangle budget |
| `a_pose_deg` | characters.json `body` | only for weighting (larger = cleaner armpits, more shoulder stretch) |

## 3. How a kit is authored (make_kits.py)

A kit is a function `kit_<name>(body, P) -> Kit` built from four garment tools:

- `shell(body, predicate, thickness, key)`: the body faces whose vertices satisfy a region predicate (`P_torso(y_lo,
  y_hi)`, `P_arms(y_lo)`, `P_legs(y_lo, y_hi)`, `P_boots(y_hi)`, `P_hands()`, combinable with `P_or`), pushed out
  along the normals (thickness may be a function: thicker on the trunk than the sleeves), with a hem lip. It takes
  the body vertices' weights exactly, so it deforms with them. `push=` reshapes it (`boot_push` soles and toes,
  `flare_push` bell-bottoms). `add_shell(..., cover=True)` also records the body vertices it hides.
- `skirt(body, trunk(piece), y_top, y_hem, key, flare=, ease=, ragged=)`: a double-sided lofted skirt that hugs the
  trunk at y_top and clears both legs below; weights slide from the hips into each thigh (and a little into the
  shins under the knee).
- `band(body, points, y, height, key)` (belts, collars, hems) and `cuff_band(body, side, y, ...)` (cuffs, knee
  patches, trouser ties): sections swept around the cross-section underneath; weights from the trunk / that limb.
- `stud(piece, key, x, y, size)` and `stud_top(...)`: buttons, pouches, pockets, tabs, a buckle, sitting on a piece's
  surface and riding its weights.

Every piece has one **part key** (`characters.json part_keys`: cloth, cloth2, leather, metal, brass, white, knit,
rubber, navy, ...). The key goes into the GLB as `COLOR_0.r = index / 255`; ZombieBody colours it per kit
(`KIT_CLOTH` for cloth / cloth2, `KEY_LOOK` for the rest: colour, roughness, metallic, emission) and gives it the
fabric or leather detail class. Keep a piece single-key (decimation interpolates colours inside a connected piece).
Kits are decimated to `budget.kit_tris` (3 000).

Coverage: a kit's hidden body vertices (inside its shells, eroded two rings from the edge) become bit *i*
(`kit_order`) of the body vertex's mask in `COLOR_0.b` (bits 0-7) and `.a` (bit 8, alpha < 0.5), and since T-192
bits 9-16 in `.r` (the body's own part key is `skin`, index 0, so a body built before reads 0 there). The merge drops a
skin triangle only when all three vertices carry the kit's bit, so edges never open a gap. The Soviet risen kits
(T-192: `soviet`, `soviet_tunic`, `soviet_burial`) are bits 9-11; they also show how a zombie kit uses the people's
finishing helpers (`pstud`, `pocket`, `buckle`, `welt`, `grime`: build_all keeps a piece's AO in `COLOR_0.g`).

To add a kit: write `kit_<name>`, register it in `KITS` (make_kits) and `kit_order` (characters.json, append only:
the bit order is baked into the GLBs), add its colours to `ZombieBody.KIT_CLOTH` and its spawn data to anim.json
`kits`, run `tools/build_characters.sh`.

Gear that is rolled per spawn (helmets, caps, goggles, the Wiederkehr armband, packs) stays on bone attachments
(`ZombieBody.gear_mesh`), because it is optional per instance; clothing every member of a kit wears goes in the kit.
Insignia: only the fictional marks of `docs/ART_FACTIONS.md`; the armband's mark is generated by
`make_textures.emblem()`.

## 4. Skin textures (make_textures.py)

Per-vertex masks (frost: fingers, toes, nose, ears, lips, cheeks; Nachtglas origin: eyes, mouth, hands; sockets;
lividity low on the legs; vein density) become colour attributes; a Cycles node tree turns them plus noise and a
warped Voronoi vein network into albedo, a bump for the normal map and a roughness, baked at 1K: albedo (sRGB,
around linear 0.5, alpha = Nachtglas origin), normal (OpenGL +Y), ORM (baked AO, roughness, metallic 0). The
`--living` set drops the veins to a trace at the wrists and temples, has no frostbite or lividity, warms the base and
adds rosy lips and cheeks; its alpha is 0.

The infection shader (`ZombieBody.skin_shader`) multiplies the albedo × 1.5 by the kit's skin tone and the instance
tint, reads the normal map and ORM, and keeps everything it did before: veins pulsing with `gl_hum`, cracks
thresholded by `gl_round_k` (opening first where the albedo's alpha marks the origin), dirt, frost, char, fuel,
dissolve as instance uniforms.

## 5. Faces and blendshapes (not built yet: how to add them)

The people need blink, jaw and a few expressions (UPDATE_05 §4). The jaw already opens on the **Jaw** bone. For the
rest, add shape keys in `make_body.py` after `head_mesh` (the head's vertex order is fixed by `quad_sphere`, so a
shape is a per-vertex offset array computed by the same kind of displacement field as `head_shape`):

1. build the base head, then each target by changing the field (`blink`: close the sockets by pulling the upper
   lid band down over the eye; `brow_up` / `brow_down`: move the brow ridge term; `smile` / `frown`: move the mouth
   corners; `jaw_open` if you prefer a shape over the bone);
2. after joining, add them as Blender shape keys on `Body` (`ob.shape_key_add(name=...)`, write the coordinates);
   the exporter already has `export_morph=True`, the GLB carries them as morph targets;
3. in Godot, `base_parts` reads `ArrayMesh.surface_get_blend_shape_arrays` alongside the surface; pass them into
   `ImporterMesh.add_surface(..., blend_shapes)` in the merge (add `set_blend_shape_name` first) and drive
   `MeshInstance3D.set_blend_shape_value` from the VO lip flap. Decimation would destroy them: give the shaped
   body its own decimation that keeps the head (the head is only ~1.7k triangles).

## 6. Retargeting onto the MZ rig

The GLB's skin joints carry the rig's bone names; `ZombieBody.base_parts` remaps the skin's bind indices to
`ZombieRig.bone_index` by name, and the merged mesh is used with the Zombie's own `Skeleton3D`
(`create_skin_from_rest_transforms`). So any MZ clip, the posture layers, foot IK, look-at, ragdoll and gore work on
a new body without retargeting. A body modelled elsewhere (Mixamo, a CC0 humanoid) must be posed into the rig's rest
(arms straight down, identity rest rotations, rig.json heads) and weighted to bones of those names; then it loads
the same way. Animation from another skeleton goes through `ZombieRig.bone_map()` (the SkeletonProfileHumanoid
BoneMap) at import, then into `ZombieClips.library()`.

## 7. API for the people builder

```gdscript
# a living human, dressed in any kit ("" = none), cached
var mesh: ArrayMesh = ZombieBody.build_living("villager", "thin", true, Color(0.62, 0.5, 0.44))
var skel: Skeleton3D = ZombieRig.build_skeleton()
var mi := MeshInstance3D.new(); mi.mesh = mesh; skel.add_child(mi)
mi.skeleton = NodePath(".."); mi.skin = skel.create_skin_from_rest_transforms()
# the raw GLB objects (Body, Parts, Hair_m, Hair_f, Kit_<kit>, Body_LOD1/2) as arrays, bones remapped to the rig
var parts: Dictionary = ZombieBody.base_parts("medium", false, true)
```

New clothes for a named character: write a kit function (or a `kit_<character>`), build with
`tools/build_characters.sh --living`. A distinct face: a `Params` subclass / extra fields fed into `head_shape`
(nose length, jaw width, brow height are single constants there), exported under its own file name.

## 8. Checks

- GUT `test_zombie_body`: every kit × build × sex merges into two surfaces, every influence names a rig bone and
  weights sum to 1, each hitbox's bone geometry sits inside its box (+6 cm) and fills it, the gore split gives every
  `LIMB_BONES` piece at its joint, LODs exist with fewer triangles, the budget holds, the maps load, the living set
  has no Nachtglas and no glowing eyes.
- `shots_zombie_anim -- --only=lineup` (rendered, off-screen): the lineup, before / after close-ups (front, side,
  damaged, crawler, ragdoll), faces, the living set. `--only=emerge`: the T-085 rise sheets.
- `smoke_zombie_anim`: foot-slide, climbs, gore, knockdown, deaths and ragdolls.

## 9. The named people (T-092)

The squad (Dutch, Peg, Deacon, Wren), Jakub, the Map 0 patrons (Rother, Kubiak, Frau Pohl, Trudi, Gefreiter
Sobotta), the three survivors upstairs (Wiesner, Fräulein Brandt, Ida Kroll) and the Cousins (the Hammer, the Reach,
Alix) are built by the same scripts, one GLB per person.

| File | What it does |
|---|---|
| `data/gravelight/art/people.json` | Per person: build / sex / body overrides (`w`, `sh`, `limb` multiply; `belly`, `sink` set), face knobs (`head` scale, `jaw`, `chin`, `brow`, `nose`, `nose_w`, `lips`, `ears`, `mouth_close`), hair style, kit, skin tone (linear), palette (sRGB per part key), skin paint, height, VO speaker, face driver (blink range, rest face), `look` (porcelain). Also the shape list, the budgets and the expressions (shape weights per expression). |
| `tools_src/blender/characters/make_face.py` | The people's face: eyes placed by ray-cast onto the sculpted socket (white, iris, pupil), upper / lower **lids** and lash lines (spherical patches at an edge angle), **brows** (ribbons on the brow ridge), teeth and the mouth cavity, a moustache; hair styles (crop, bun, braid, bob, two buns, via `dome()` for smooth edges); the skin paint; the **shape keys** as displacement fields (the lids and brows are regenerated at each shape's edge angles / offsets). |
| `tools_src/blender/characters/make_kits.py` (section "the named people") | `kit_<person>(body, P)` for all sixteen, plus `head_piece` (helmet with netting, beret, knit cap, flat cap, peaked cap, kerchief, side cap), `sash` (straps laid on a garment by ray), `pstud` (studs placed by ray, not snapped to the nearest vertex), `P_coat` (a coat over the hip sides), `cut_front` (an open coat), `P_palm` (fingerless gloves), `stitches` (the Cousins' seams), `mottle` (camouflage / grease as per-vertex AO). |
| `tools_src/blender/characters/build_people.py` | Builds one person: body (with the face knobs) → UVs transferred from the canonical living medium male (the shared living skin textures fit) → the kit → the skin under the kit deleted → decimated to `budget.body_tris` sparing the face and hands → paint → shape keys → `Body` / `Parts` / `Hair` / `Kit` + the rig into `assets/ours/characters/people/char_person_<id>.glb`. `--preview=<dir>` / `--faces=<dir>` render Workbench sheets (every shape). |
| `tools/build_people.sh [--only=dutch,peg]` | Runs it and imports. |
| `gravelight/world/people/people_bodies.gd` | `PeopleBodies.mesh(id, risen=false)`: the GLB merged into the two-surface layout with the six blend shapes on both surfaces and mesh LODs; `dress_risen(zombie, id)` puts the same person, risen (infection skin, violet eyes), on the zombie a patron / survivor turns into; `legacy` / `-- --legacy-people` for before shots. |
| `gravelight/world/people/person_rig.gd` | `PersonRig`: the person's mesh on a ZombieRig skeleton, driven from a procedural puppet's pose (`drive()`: hips, chest / head rotations split over the spine and neck, the puppet's leg angles, two-bone IK from the rig's shoulders to the puppet's hand targets, the lower foot planted). RemoteBody (squad, Jakub) and PatronBody (patrons, survivors) keep every pose, action and timing they had and hand it over each frame. |
| `gravelight/world/face_driver.gd` | `FaceDriver`: blinks on a timer, eases to the owner's expression (RemoteBody: downed = pain, low health = fear, shooting / reloading = determined, a smile in an idle fidget; PatronBody: panic / run / cower = fear, falling = pain, eyes shut once dead, the rifle = determined, a smile at the table), lip flap on `GLBus.vo_line_started` for its speaker (a syllable rhythm from the line's vowel groups over its duration). |

Shape keys: `blink`, `jaw_open` (the jaw region rotated about a hinge below the ear; the lower teeth and the cavity
ride it), `fear` (brows up, lids wide, mouth corners out and down, jaw a little open), `determined` (brows down and
in, a squint, lips pressed), `pain` (inner brows up and pinched, eyes screwed shut, a grimace, teeth showing),
`smile` (corners up and back, cheeks up, lower lids up). Bodies keep the Jaw bone too (the Cousins' MZ clips still
key it).

The Cousins wear their person mesh on their own Zombie skeleton (`HomageBoss.modelled()`): the costume primitives
for hair and clothes are skipped, the maul, the Reach's telescoping arms and stretch fillers, Alix's third arm and
the HomagePoseMod layer are untouched, and the hitboxes are the same nodes (test_people_bodies compares them with
the legacy bodies).

Checks: GUT `test_people_bodies`; shots `gravelight/tools_src/shots_lineup.tscn` (the lineup, faces per expression,
the Cousins' faces, a risen patron) and `shots_people_ingame.tscn` (patrons at their tables, the bots, a fight, the
Cousins' round), both with `-- --legacy-people` for the before set.

### T-099 fixes (the T-092 known issues)

- **Gun hold.** `RemoteBody.hold_of(gun, id)` measures each held gun: a long gun's hold point is its butt (the back
  of its meshes), a pistol's its grip; `sight_y` from SightPoint; the support grip's axis / radius (`lh_axis`,
  `lh_radius`) and the firing grip (`grip_r`). The gun turns about that point, placed on the body actually drawn
  (`_hold_anchor`: the rig shoulder and eye times the person's height): a long gun's butt tucked under the right
  shoulder at the hip, in the shoulder pocket with the sight under the leaning eye aimed (PF_ADS); a pistol out in
  both hands at chest height, at eye height aimed. Behind a long gun the body turns side-on (`_blade`, the feet and
  hips with it, the head and gun turned back to the front) so the support hand reaches; if it still can't, the
  support grip slides back along the handguard (16 cm at most). `hand_on_gun` puts the wrists back from the grips
  and gives each hand a basis (support palm up under a handguard, thumb along the left; round an upright foregrip;
  cupping a pistol hand; the firing palm on the grip); `PersonRig.drive` takes `hand_basis` / `hand_w` and turns the
  Hand bones to them (wrist bend capped at `WRIST_MAX`). The elbows hang down and a little out on the gun.
- **Hair under hats.** `make_kits.head_piece` records the hat's dome on `P.hat` (not for the beret or side cap, which
  sit on the hair); `make_face.under_hat` pulls the hair inside the hat, and in a 24° band under its edge, in to the
  hat's inner surface, and drops the faces hidden inside it.
- **Necks.** `build_people.shorter_neck` (people.json `neck`: `lift`, `thick`, per person overridable) raises the base
  of the neck, the collarbones and the trapezius and thickens the neck, after the UV transfer (the shared skin
  textures still fit) and before the kit (the collars sit on it). No bone or hitbox moves.
- **Zombie cuffs.** The soldier, dockworker and nurse cuff bands take only the arm's vertices (`bones=`), the fix
  T-092 made for the people: a band at wrist height used to average in the thigh beside it and stretch a ring from
  the wrist to the thigh.
- **Risen people.** Their severed pieces are cut from their own risen mesh (`PeopleBodies.piece_mesh`, used by
  `ZombieGore._throw_piece` when the zombie has a `person` meta); the host sends the person id as field 9 of the
  zombie spawn event and the co-op client calls `dress_risen` on its puppet; `Zombie._reset_presentation` drops the
  meta when the pool reuses the zombie.
- **Detail pass (T-134).** people.json `budget`: `head_res` (20; the zombies keep characters.json's 16) and
  `hand_res` (1: rounder palm, 8-sided fingers with knuckles; `make_body.fine_finger`) make the people's heads and
  hands finer; their UVs map through the canonical head / hand surface (`build_all._region_uvs`). `hair_tris` caps
  the hair; the kit is decimated to `min(kit_tris, hero_tris - body - parts - hair)` with the small finishing pieces
  (≤ 120 faces) spared. The finishing helpers in `make_kits.py` (`pocket`, `buckle`, `keepers`, `welt`,
  `collar_points`, `cuffs`, `back_seams`, `boots_finish`, `grime`, `scuff`) lay pieces on a garment by ray and skin
  them to the vertex under them; grime and scuffs go into the kit's `.g` AO channel. Buckles and patches stay plain
  (no badges or emblems).
