# Zombie overhaul asset usage

The project's canonical ledger remains [docs/ASSETS.md](docs/ASSETS.md).
The owner supplied MoCap Online Zombie Starter 2.7 on 2026-11-09. Original FBXs are
kept under `assets/user_supplied/mocap_online/zombie_starter_2_7/` (ignored); derived
GLBs are local under `assets/zombies/anims/`. No standalone animation files are published.

| Source | License | Used in |
|---|---|---|
| Existing six `assets/ours/characters/zombie_base/char_zombie_base_*.glb`, their embedded outfit/gear parts and existing skin textures | Project-owned original work; `assets/ours/characters/LICENSE.txt` | Zombie gallery bodies and baseline captures |
| Existing `ZombieRig`, `ZombieBody`, `ZombieClips` generated animation library and materials | Project-owned original code/art; canonical ledger MZ/T-041 and character pipeline T-091 | Gallery's 102 clip previews and live AI baseline |

All rows below: source **Motus Digital / MoCap Online Zombie Starter 2.7**, owner-supplied
`FBX_Zombie_27_Starter`; license **MoCap Online Standard License**,
<https://mocaponline.com/pages/standard-license>. Commercial game use and retargeting are
permitted for the licensee; standalone redistribution is restricted. No receipt was bundled.
The owner's explicit purchased-asset instruction supplies the exception to the project's usual
free-asset intake rule. The Motus demonstration body/textures are not used in the game.

| Source FBX in `Animation/Root_Motion` | Derived clip / use |
|---|---|
| `Zombie_Walk_F_1_Loop.fbx` | `mco_walk` / gallery, retarget/contact validation |
| `Zombie_Chase_1_Loop.fbx` | `mco_chase` / gallery, retarget/contact validation |
| `Zombie_HyperChase_1_Loop.fbx` | `mco_fast_chase` / gallery, retarget/contact validation |
| `Zombie_Crawl_1_Loop.fbx` | `mco_crawl` / gallery |
| `Zombie_Idle_1_v2.fbx` | `mco_idle` / gallery |
| `Zombie_Idle_2.fbx` | `mco_idle_2` / gallery |
| `Zombie_Reach_1_Loop.fbx` | `mco_reach` / gallery |
| `Zombie_Atk_Loop_1.fbx` | `mco_attack_loop` / gallery |
| `Zombie_Atk_Arms_3_SHORT_Loop.fbx` | `mco_attack_arms` / gallery |
| `Zombie_HyperAttack_1_SHORT_Loop.fbx` | `mco_fast_attack` / gallery |
| `Zombie_HyperAttack_1_SHORT_Idle_Loop.fbx` | `mco_fast_attack_idle` / gallery |
| `Zombie_Death_Back_Mid_1.fbx` | `mco_death_back` / gallery |
| `Zombie_Death_Hit_Back_1.fbx` | `mco_death_hit_back` / gallery |
| `Zombie_Turn_L_45_Loop.fbx` | `mco_turn_l_45` / gallery, nonlooping facing change |
| `Zombie_Turn_R_45_Loop.fbx` | `mco_turn_r_45` / gallery, nonlooping facing change |
| `Zombie_Turn_L_90_1.fbx` | `mco_turn_l_90` / gallery |
| `Zombie_Turn_R_90_1.fbx` | `mco_turn_r_90` / gallery |
| `Zombie_Walk_F_1_KnockBack_Walk.fbx` | `mco_walk_knockback` / gallery |
| `Zombie_Chase_1_KnockBack_Chase.fbx` | `mco_chase_knockback` / gallery |
| `Zombie_Stand_Walk_F_1.fbx` | `mco_stand_walk` / gallery |
| `Zombie_Stand_To_Chase_1.fbx` | `mco_stand_chase` / gallery |
| `Zombie_Stand_To_Atk_1.fbx` | `mco_stand_attack` / gallery |
| `Zombie_Stand to_Crawl_1.fbx` | `mco_stand_crawl` / gallery |
| `Zombie_OnFire_2A_SHORT.fbx` | `mco_on_fire` / gallery |
| `Zombie_Idle_1_v2_to_MOB_Stand.fbx` | `mco_idle_to_stand` / gallery |
| `MOB_Stand_to_Zombie_Idle_1_v2.fbx` | `mco_stand_to_idle` / gallery |

`tools/zombie_mocap_build.ps1` repeats conversion and import. Config/source hashes, measured
speeds and contacts are in `docs/captures/after/mocap/conversion.json`; those measurements
are not animation files. Runtime promotion is recorded separately in the overhaul plan.
