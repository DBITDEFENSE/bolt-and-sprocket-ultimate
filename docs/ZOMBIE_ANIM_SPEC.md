# ZOMBIE_ANIM_SPEC — the game-wide zombie animation and design upgrade (ULTIMATE PROMPT v2 §7; milestone MZ)

**Goal:** zombies that feel heavy, individual and reactive — a clear step up from the current procedural bodies with posed-rotation gaits — on every Gravelight map and Helvetia Works, without breaking the **24-active-zombie / 60 FPS** target (today's maps hold 240 FPS on the test machine; the budget below is for a mid-range GPU).

**Where we start (today, `gravelight/enemies/zombie_body.gd` + `zombie.gd`):** one procedural body per variant (soldier, miner, labstaff, "laborer", bellringer, nurse), built from cylinders/spheres/boxes into one ArrayMesh per bone, posed by plain local rotations on a 16-bone hand-made hierarchy; the Nachtglas crack emission already scales with the round (`update_cracks`); crawlers exist as a pose; deaths are a fall + fade; no skeleton resource, no AnimationTree, no IK, no ragdoll. The states exist (SPAWN/EMERGE/TO_WINDOW/WAIT/TEAR/CLIMB/CHASE/ATTACK/STAGGER/DEAD) and are the hooks every animation below plugs into.

**Rule carried over from v2 §0:** the `laborer` outfit variant is **retired** in MZ (forced laborers are never zombies). Its slot in `enemies.json ganger.variants` moves to a `villager` kit on Map 0 and `technician` on Map 1; the Map 1 "Intake" story context keeps the laborers as story only.

---

## 1. Rig and pipeline

| Item | Spec |
|---|---|
| Skeleton | **One shared humanoid `Skeleton3D`** for every zombie type, Godot 4's `SkeletonProfileHumanoid` with a `BoneMap`, so every animation source retargets onto every body. The current 16-bone hand hierarchy is replaced; bone names follow the profile (Hips, Spine, Chest, Neck, Head, Jaw, L/R UpperArm, LowerArm, Hand, UpperLeg, LowerLeg, Foot). |
| Bodies | The procedural body builder stays (originality rule) but now skins to the shared skeleton: each body part is a cylinder/sphere mesh weighted to one or two bones. A `ZombieBody.build_skinned(variant)` returns a `MeshInstance3D` + `Skin`. |
| Animation sources | Authored in-engine (Godot's animation editor / a procedural-pose library baked to `Animation` resources) and licensed packs (Mixamo retargeted, CC0 packs). **Every imported animation's source and license goes in `ASSETS.md` §MZ**; nothing from a commercial game. |
| AnimationTree | one per zombie: a `AnimationNodeStateMachine` **Spawn / Emerge / Climb / Barricade / Locomotion / Attack / React / Crawl / Death** with `BlendSpace1D/2D` inside Locomotion (speed, turn) and Attack (variant); an **additive layer** for posture traits and flinches; a `OneShot` for reacts. |
| Root motion | locomotion clips carry root motion; `NavigationAgent3D.max_speed` is matched to the clip's stride speed (tier speed ± jitter) so **no foot-sliding**; a `RootMotionView` check is part of the acceptance capture. |
| Data | `data/gravelight/anim.json`: clip lists per state and tier, variation ranges, LOD distances, ragdoll caps. Nothing hardcoded in `zombie.gd`. |

## 2. Locomotion

- **Clips per speed tier**, chosen at activation: shamble ×3, walk ×3, jog ×2, run ×3, sprint ×2, crawler ×2 (belly-drag, four-limb scuttle). `enemies.json tiers` keeps the speeds; `anim.json` maps tier → clips.
- **Per-instance variation:** playback-speed jitter ±10% (`speed_jitter`), a random start phase (no synchronized hordes), and one **posture trait** as an additive pose: limp L / limp R / hunch / dislocated hanging arm / broken-neck tilt / dragged foot (weights in `anim.json postures`).
- **Turn-in-place** clips below 0.5 m/s; **lean into turns** (a 2D blend space speed × turn-rate) at run and sprint.
- **Foot IK** on stairs, slopes and rubble: two raycasts per frame within 15 m, a hip offset to the lower foot (`SkeletonIK3D` or a `SkeletonModifier3D`), off beyond 25 m.
- **Head look-at** toward the nearest player: `LookAtModifier3D`, 60° cone, 0.2 s smoothing, off beyond 25 m.

## 3. Interactions

- **Barricades:** 3 tear-board clips (grab-and-rip, two-hand wrench, shoulder slam), a **reach-through swipe** at a player within 1.2 m of the window (new attack hitbox through the gap), 2 vault/climb-in clips, and a drop-down for high windows (Map 0 porch ledges, Map 1 balcony, Map 2 catwalk points).
- **Climbing (new, for the Bergwacht and for Map 2's cliff ladders):** a wall/cliff climb loop with ledge mantle and drop-in, driven by authored **climb volumes** (`NavigationLink3D`s whose `travel` triggers the Climb state; the link's start/end set the clip's length). Zombies on a climb are vulnerable and cannot attack.
- **Attacks:** 4 swipe variants, a runner lunge, a **sprinter grab** that briefly pulls the player's view (0.4 s camera yank, cancelled by melee), a crawler bite, and armless zombies switching to headbutt/bite only.
- **Spawn / emerge:** ground emerge ×2 (dig-out, roll-up), portal step (Bellringers), ceiling drop (Map 1 chutes), water surface (Map 2 surf stairs: a wade-up clip).

## 4. Hit reactions and physics

- **Directional additive flinches** by hit zone (head / torso / L-R arm / L-R leg) blended for 0.25 s on the additive layer; never interrupts locomotion below the stagger threshold.
- **Stagger** at damage thresholds (per-weapon `stagger` property and the existing `force_stagger`).
- **Knockdown + get-up** (front and back) from explosives, traps and the shatter shockwave; the get-up is interruptible by damage.
- **Partial ragdoll on flinch:** arms and head blend into physics for 0.3 s (`PhysicalBoneSimulator3D` on the arm/head chain only).
- **Deaths:** 8+ authored deaths (headshot snap, gut collapse, spin, knee-drop, backward fall, face-plant, sit-down, sprint tumble) that blend into **full ragdoll** after the key pose; explosive deaths launch the ragdoll. **Caps:** max 6 simultaneous ragdolls (older ones freeze), corpses settle then fade or sink with the Nachtglas dissolve shader after 8–12 s.

## 5. Dismemberment

- **Separable pieces:** forearms, upper arms, lower legs, head (pops on a headshot kill), jaw. Each piece has a **stump cap** mesh and a wound decal; severed pieces are physics props with a 4 s lifetime (cap 12 live pieces).
- **Gameplay hooks:** losing an arm removes that arm's attacks (bite/headbutt when both are gone); losing a leg mid-run plays a **fall-into-crawler** transition (replaces today's instant pose swap); a headless body staggers 1–2 steps before dropping.
- **Gore setting:** Off / Low / Full (Off hides dismemberment and blood, keeps the shatter VFX; Low keeps severs but no spray).

## 6. Visual design

- **Modular build:** base bodies (3 builds × 2 heights, male and female) + an **outfit kit per map/faction** (Crossroads villagers and soldiers, Kaltenbrunn miners and lab staff, Totenhafen sailors and dockworkers, Basel dockworkers, Morgenrot rocket troops / technicians / fuel crews / mountain troops) + gear pieces (helmets, caps, packs) + random tint, dirt and frost. Marks per `ART_FACTIONS.md` only.
- **Nachtglas infection shader:** violet veins under the skin whose emission **pulses with the map's low hum** (a global shader parameter driven by AudioDirector's hum envelope); glowing eyes with bloom; crystal cracks that **grow with the round** (today's `update_cracks`, extended with a crack-density mask).
- **Damage-state materials:** wound decals at hit points, burn char, frost crust, LOX-frozen (Morgenrot), soaked-in-fuel sheen (Treibstoff-Gänger).
- **Silhouette discipline:** every special enemy reads from 40 m in fog by shape **and** by audio tell (Glasshide grind, Bellringer wheeze, Frostbiss creak, Bergwacht axe-clink, Faller whistle).

## 7. Audio sync and performance

- **Animation events** drive footsteps (surface-aware: snow / wood / stone / metal grate / water), board rips, attack whooshes, and per-type vocal breaths and snarls, so sound matches motion.
- **Animation LOD:** full rate within 15 m, half at 15–35 m, quarter beyond; no IK or look-at beyond 25 m; impostor-light distant crowds (a 4-clip `MultiMesh` billboard set) if a map ever shows more than 24 at once (Totenhafen's hall is the stress case).
- **Budget:** ≤ 0.35 ms CPU per active zombie at full rate on the mid-range target; skinning on the GPU; one material per outfit kit (texture atlas) so a horde is ≤ 12 draw calls per kit.
- **Acceptance test (v2 §7.7):** `tools_src/shots_zombie_anim.tscn`, a side-by-side capture (before / after) of 10 zombies walking, tearing a barricade, getting shot in each limb, and dying, posted in the milestone summary; `perf_map01` and the Morgenrot perf tool at 24 active zombies at 60 FPS on the target; a foot-slide check (root-motion speed vs. nav speed within 5%).

## 8. Migration plan (MZ, before M8.5)

1. `anim.json`, the shared skeleton + BoneMap, the skinned procedural body (no visual change yet).
2. AnimationTree with today's states driven by procedural clips (locomotion variants, posture traits, flinches); swap the pose code in `zombie.gd` for tree parameters.
3. Barricade and climb interactions; the climb links on Map 2 (surf stairs, catwalk ladders) as the first test.
4. Hit reactions, ragdoll, deaths, dismemberment with the gore setting.
5. Outfit kits and the infection shader; retire the `laborer` variant.
6. LOD and the acceptance capture; retrofit every map; perf sign-off.

Each step keeps the game playable (the old body is the fallback until step 2 lands).
