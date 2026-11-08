# The other maps: facing report only (UPDATE 13 Part 3, T-219)

The Fernflug facing check run on every other GRAVELIGHT map, report only: **nothing on these maps was changed**.

```
godot --headless --audio-driver Dummy --path . --script res://tools/tests/test_interactable_facing.gd -- \
    --maps=map00,map01,map02,test_range --report-only
```

No interactable on Maps 0-2 or the test range faces the wrong way (0 BACKWARDS, 0 SIDEWAYS). What the check flags
(columns as in `facing_before.md`):

- **map00 Perk_ledger_lager, Perk_overclock_cordial** (UNSURE): the cellar bay's two machines face the bay (their
  backs on the cellar walls) but only a third of their front samples are on the navmesh: the bay is narrow. Fine.
- **map01 Perk_ledger_lager** (UNREACHABLE by the check): its origin (-15.2, 0, 11) is inside the admin block's
  filing cabinet collider `FilingA` (x -15.6..-14.3, z 9..12): the machine and the cabinet overlap. Worth a look
  (a position, not a facing).
- **map01 Radio_radio_admin_fasbender, Radio_radio_lab_intake, Cylinder3** (UNREACHABLE by the check): quest
  props on upper floors / shelves with no navmesh polygon within 2.5 m of their floor height; probably a table or
  shelf top the check cannot see as a floor. Not facings; worth a look in game if a bot fails those steps.
- **map02 Door_PenHall_W, Door_PenHall_E** (UNREACHABLE by the check): the pen hall doors stand in a 3 m deep
  doorway with no navmesh inside it; their use box spans it, so players reach them. Not facings.

## Summary

| Map | Interactables (windows aside) | OK | BACKWARDS | SIDEWAYS | UNSURE | UNREACHABLE | of which known | Windows |
|---|---|---|---|---|---|---|---|---|
| map00 | 43 | 41 | 0 | 0 | 2 | 0 | 0 | 16 |
| map01 | 72 | 68 | 0 | 0 | 0 | 4 | 0 | 24 |
| map02 | 43 | 41 | 0 | 0 | 0 | 2 | 0 | 15 |
| test_range | 32 | 32 | 0 | 0 | 0 | 0 | 0 | 0 |

## Every interactable

### Map 0 Crossroads Inn

| # | Node | Script | Pos (x, y, z) | Yaw | Front faces | Verdict | Open F / B / +90 / -90 | Reach | Suggested yaw | Back gap (m) | Clips |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Door_Upstairs | door.gd | 6.00, 0.00, 15.10 | 90 | (door) | OK | 0.53 / 0.60 / 0.33 / 0.20 | yes | - | - | - |
| 2 | Door_Stable | door.gd | 20.00, 0.00, 16.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.07 / 0.07 | yes | - | - | - |
| 3 | Door_Yard | door.gd | 8.00, 0.00, 34.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 4 | Door_Front | door.gd | 20.00, 0.00, 0.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 5 | Door_Gate | door.gd | 18.00, 0.00, 48.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.33 / 0.60 | yes | - | - | - |
| 6 | Door_Cellar | door.gd | 24.00, 0.00, 11.50 | 90 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 7 | Perk_ironhide_stout | perk_machine.gd | 25.90, -3.20, 23.00 | -90 | +X | OK | 1.00 / 0.00 / 1.00 / 0.47 | yes | - | 1.15 | no |
| 8 | Perk_second_wind | perk_machine.gd | 25.90, -3.20, 25.80 | -90 | +X | OK | 1.00 / 0.33 / 0.53 / 0.67 | yes | - | 1.45 | no |
| 9 | Perk_trigger_tonic | perk_machine.gd | 25.90, -3.20, 28.60 | -90 | +X | OK | 0.60 / 0.33 / 0.67 / 0.33 | yes | - | 1.45 | no |
| 10 | Perk_twin_barrel | perk_machine.gd | 34.10, -3.20, 21.60 | 90 | -X | OK | 0.87 / 0.13 / 0.67 / 0.00 | yes | - | 1.45 | no |
| 11 | Perk_marathon_malt | perk_machine.gd | 34.10, -3.20, 24.60 | 90 | -X | OK | 1.00 / 0.00 / 0.67 / 0.67 | yes | - | 1.30 | no |
| 12 | Perk_hawkeye_brandy | perk_machine.gd | 34.10, -3.20, 27.60 | 90 | -X | OK | 1.00 / 0.33 / 0.27 / 0.67 | yes | - | 1.45 | no |
| 13 | Perk_ledger_lager | perk_machine.gd | 34.10, -3.20, 30.20 | 90 | -X | UNSURE | 0.27 / 0.00 / 0.00 / 0.00 | yes | - | 1.40 | no |
| 14 | Perk_packmule_porter | perk_machine.gd | 28.60, -3.20, 29.40 | 0 | -Z | OK | 0.87 / 0.00 / 0.40 / 0.00 | yes | - | 1.05 | no |
| 15 | Perk_blastproof_bock | perk_machine.gd | 31.40, -3.20, 29.40 | 0 | -Z | OK | 0.87 / 0.00 / 0.00 / 0.53 | yes | - | 1.00 | no |
| 16 | Perk_overclock_cordial | perk_machine.gd | 30.15, -3.20, 29.40 | 0 | -Z | UNSURE | 0.33 / 0.00 / 0.00 / 0.00 | yes | - | 1.15 | no |
| 17 | Perk_skyhook_sekt | perk_machine.gd | 40.30, -3.20, 24.40 | 90 | -X | OK | 1.00 / 0.33 / 0.93 / 0.00 | yes | - | 1.40 | no |
| 18 | Perk_magpie_mead | perk_machine.gd | 40.30, -3.20, 27.60 | 90 | -X | OK | 1.00 / 0.33 / 0.00 / 0.93 | yes | - | 1.45 | no |
| 19 | Crucible | crucible.gd | 29.50, -3.20, 19.95 | 180 | +Z | OK | 0.67 / 0.00 / 0.13 / 0.80 | yes | - | 0.05 | no |
| 20 | Kellerschalter | power_switch.gd | 32.50, -2.90, 19.35 | 180 | +Z | OK | 0.73 / 0.00 / 0.00 / 0.00 | yes | - | 0.15 | no |
| 21 | Door_OldCellar | door.gd | 0.00, 0.00, 9.05 | 90 | (door) | OK | 0.60 / 0.60 / 0.00 / 0.00 | yes | - | - | - |
| 22 | WallBuy_gewehr43 | wall_buy.gd | 11.09, -1.70, 6.60 | -90 | +X | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 23 | WallBuy_kar98k | wall_buy.gd | 0.19, 1.50, 3.10 | -90 | +X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 24 | WallBuy_m1_garand | wall_buy.gd | 23.81, 1.50, 4.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 25 | WallBuy_mp40 | wall_buy.gd | 0.19, 5.30, 3.40 | -90 | +X | OK | 0.67 / 0.00 / 0.00 / 0.13 | yes | - | 0.00 | no |
| 26 | WallBuy_trench_gun | wall_buy.gd | 4.66, 1.50, 29.50 | -90 | +X | OK | 1.00 / 0.00 / 0.13 / 0.07 | yes | - | 0.00 | no |
| 27 | WallBuy_thompson | wall_buy.gd | 22.00, 1.50, 34.19 | 180 | +Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 28 | Crate_Hearth | mystery_crate.gd | 22.90, 0.00, 14.00 | 90 | -X | OK | 1.00 / 0.00 / 0.00 / 0.80 | yes | - | 0.55 | no |
| 29 | Crate_GuestBed | mystery_crate.gd | 22.00, 3.80, 0.80 | 180 | +Z | OK | 0.67 / 0.00 / 0.00 / 0.53 | yes | - | 0.25 | yes |
| 30 | Crate_TackRoom | mystery_crate.gd | 22.90, 0.00, 31.50 | 90 | -X | OK | 1.00 / 0.00 / 0.60 / 0.40 | yes | - | 0.05 | yes |
| 31 | Crate_Well | mystery_crate.gd | 13.50, 0.00, 42.00 | 90 | -X | OK | 0.67 / 1.00 / 0.93 / 0.93 | yes | - | none | yes |
| 32 | AmmoBox_Taproom | ammo_box.gd | 5.34, 0.00, 7.30 | -90 | +X | OK | 0.60 / 0.00 / 0.20 / 0.00 | yes | - | 0.05 | no |
| 33 | AmmoBox_Stable | ammo_box.gd | 4.98, 0.00, 32.00 | -90 | +X | OK | 1.00 / 0.00 / 0.27 / 0.00 | yes | - | 0.05 | yes |
| 34 | AmmoBox_Cellar | ammo_box.gd | 14.60, -3.20, 15.50 | 0 | -Z | OK | 1.00 / 0.00 / 0.40 / 0.00 | yes | - | 0.05 | yes |
| 35 | AmmoBox_Grounds | ammo_box.gd | 38.40, 0.00, 26.00 | 20 | -Z | OK | 1.00 / 0.87 / 0.80 / 0.53 | yes | - | none | yes |
| 36 | TrappedPilot | trapped_pilot.gd | 43.02, 0.25, 1.07 | 28 | (omni) | OK | 0.00 / 0.13 / 0.33 / 0.00 | yes | - | - | - |
| 37 | ArmorersBench | armorers_bench.gd | 4.66, 0.00, 26.50 | -90 | +X | OK | 1.00 / 1.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 38 | FieldRadio | field_radio.gd | 4.80, 2.00, 4.90 | -90 | (omni) | OK | 1.00 / 1.00 / 0.13 / 0.00 | yes | - | - | - |
| 39 | NoteA | quest_note.gd | 12.50, 1.51, 0.55 | 0 | (omni) | OK | 0.67 / 1.00 / 0.00 / 0.27 | yes | - | - | - |
| 40 | NoteB | quest_note.gd | 11.00, 4.31, 0.85 | 0 | (omni) | OK | 0.00 / 1.00 / 0.47 / 0.27 | yes | - | - | - |
| 41 | NoteC | quest_note.gd | 8.00, 3.51, 29.00 | 0 | (omni) | OK | 1.00 / 0.20 / 1.00 / 1.00 | yes | - | - | - |
| 42 | BankCounter | bank.json branch | -4.50, 0.00, 58.80 | 180 | -Z | OK | 0.73 / 0.00 / 0.67 / 0.67 | yes | - | none | no |
| 43 | ExfilPoint | exfil (map00.json) | 18.00, 0.00, 32.00 | 0 | -Z | OK | 1.00 / 0.33 / 1.00 / 1.00 | yes | - | none | no |

Windows (barricades; layout, not checked): W_TAP_N1 (yaw 0), W_TAP_N2 (yaw 0), W_TAP_W (yaw 90), W_TAP_E (yaw -90), W_UP_R1 (yaw 0), W_UP_R3 (yaw 0), W_STB_N1 (yaw 0), W_STB_N2 (yaw 0), W_STB_S (yaw 180), W_STB_LOFT (yaw 180), W_YARD_W (yaw 90), W_YARD_E (yaw -90), W_YARD_S1 (yaw 180), W_YARD_S2 (yaw 180), W_CEL_COAL (yaw 0), W_CEL_VAULT (yaw -90).

### Map 1 Kaltenbrunn

| # | Node | Script | Pos (x, y, z) | Yaw | Front faces | Verdict | Open F / B / +90 / -90 | Reach | Suggested yaw | Back gap (m) | Clips |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Door_RailYard | door.gd | 40.00, 0.00, 25.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 2 | Door_Admin | door.gd | 0.00, 0.00, 25.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 3 | Door_Barracks_C | door.gd | -8.00, 0.00, 32.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.07 | yes | - | - | - |
| 4 | Door_Barracks_B | door.gd | 40.00, 0.00, 40.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 5 | Door_Lift | door.gd | 25.00, 0.00, 46.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 6 | Door_Stairs | door.gd | -10.00, 0.00, 46.00 | 0 | (door) | OK | 0.33 / 0.67 / 0.07 / 0.20 | yes | - | - | - |
| 7 | Door_Generator | door.gd | 40.00, -12.00, 72.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.40 / 0.40 | yes | - | - | - |
| 8 | Door_Lab | door.gd | 60.00, -12.00, 82.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 9 | WallBuy_kar98k | wall_buy.gd | 8.00, 1.50, 10.02 | 180 | +Z | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 10 | WallBuy_m1_carbine | wall_buy.gd | 33.00, 1.50, 10.02 | 180 | +Z | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 11 | WallBuy_gewehr43 | wall_buy.gd | -12.00, 1.50, 8.17 | 180 | +Z | OK | 1.00 / 0.00 / 0.20 / 0.13 | yes | - | 0.00 | no |
| 12 | WallBuy_mp40 | wall_buy.gd | 59.83, 1.50, 36.00 | 90 | -X | OK | 1.00 / 0.00 / 0.07 / 0.00 | yes | - | 0.00 | no |
| 13 | WallBuy_frag | wall_buy.gd | 59.83, 1.50, 42.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 14 | WallBuy_trench_gun | wall_buy.gd | -4.00, 1.50, 32.17 | 180 | +Z | OK | 1.00 / 0.00 / 0.07 / 0.20 | yes | - | 0.00 | no |
| 15 | WallBuy_bar | wall_buy.gd | -15.83, -10.50, 78.00 | -90 | +X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 16 | WallBuy_stg44 | wall_buy.gd | 56.00, -10.50, 81.83 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 17 | WallBuy_etool | wall_buy.gd | 51.00, -10.50, 81.83 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 18 | Perk_second_wind | perk_machine.gd | -15.20, 0.00, 14.00 | -90 | +X | OK | 1.00 / 0.00 / 0.20 / 0.60 | yes | - | 0.40 | no |
| 19 | Perk_ironhide_stout | perk_machine.gd | 24.00, 0.00, 32.80 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.10 | no |
| 20 | Perk_marathon_malt | perk_machine.gd | 2.00, -12.00, 60.80 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.20 | no |
| 21 | Perk_twin_barrel | perk_machine.gd | 34.00, -12.00, 60.80 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.35 | no |
| 22 | Perk_trigger_tonic | perk_machine.gd | 68.00, -12.00, 81.20 | 0 | -Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.35 | no |
| 23 | Perk_hawkeye_brandy | perk_machine.gd | 55.00, -12.00, 88.80 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.35 | no |
| 24 | Perk_packmule_porter | perk_machine.gd | 96.00, -12.00, 88.80 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.73 | yes | - | 0.25 | no |
| 25 | Perk_blastproof_bock | perk_machine.gd | 64.00, -12.00, 97.20 | 0 | -Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.20 | no |
| 26 | Perk_overclock_cordial | perk_machine.gd | 60.25, -12.00, 60.45 | 180 | +Z | OK | 1.00 / 0.00 / 0.40 / 0.40 | yes | - | 0.00 | no |
| 27 | Perk_ledger_lager | perk_machine.gd | -15.20, 0.00, 11.00 | -90 | +X | UNREACHABLE | 0.00 / 0.00 / 0.00 / 0.00 | NO | - | 0.00 | yes |
| 28 | Crate_Boxcar | mystery_crate.gd | 54.60, 0.00, 24.00 | 90 | -X | OK | 1.00 / 0.00 / 0.27 / 0.80 | yes | - | 0.55 | no |
| 29 | Crate_Mess | mystery_crate.gd | 34.00, 0.00, 41.00 | 0 | -Z | OK | 0.93 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 30 | Crate_SideAltar | mystery_crate.gd | 38.20, -12.00, 82.00 | 90 | -X | OK | 1.00 / 0.00 / 1.00 / 1.00 | yes | - | 1.25 | no |
| 31 | Crate_GenCatwalk | mystery_crate.gd | 82.60, -12.00, 78.00 | 90 | -X | OK | 1.00 / 0.00 / 1.00 / 1.00 | yes | - | 0.85 | no |
| 32 | Crate_Fasbender | mystery_crate.gd | 76.00, -12.00, 83.40 | 180 | +Z | OK | 1.00 / 0.00 / 1.00 / 0.33 | yes | - | 0.85 | no |
| 33 | Hauptschalter | power_switch.gd | 46.50, -11.70, 61.20 | 180 | +Z | OK | 1.00 / 0.00 / 0.80 / 0.80 | yes | - | 1.00 | no |
| 34 | Pylon_A | pylon.gd | 20.00, 0.00, 21.50 | 180 | (omni) | OK | 1.00 / 0.33 / 1.00 / 1.00 | yes | - | - | - |
| 35 | Pylon_F | pylon.gd | -2.00, -12.00, 84.00 | 90 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 36 | Pylon_H | pylon.gd | 60.00, -12.00, 95.00 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 37 | Lever_OreCart | trap_lever.gd | 41.00, 0.00, 46.60 | 0 | -Z | OK | 0.60 / 0.00 / 0.00 / 0.60 | yes | - | 1.20 | no |
| 38 | Lever_LiveWire | trap_lever.gd | 73.50, -12.00, 76.50 | 0 | -Z | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 39 | Lever_Chandelier | trap_lever.gd | 14.50, -12.00, 61.80 | 180 | +Z | OK | 0.67 / 0.33 / 1.00 / 0.33 | yes | - | none | no |
| 40 | Crucible | crucible.gd | 46.20, -18.00, 124.00 | 90 | -X | OK | 1.00 / 0.33 / 0.20 / 1.00 | yes | - | none | no |
| 41 | AmmoBox_Yard | ammo_box.gd | 20.00, 0.00, 31.52 | 0 | -Z | OK | 1.00 / 0.00 / 0.07 / 0.13 | yes | - | 0.05 | no |
| 42 | AmmoBox_RailYard | ammo_box.gd | 40.48, 0.00, 32.50 | -90 | +X | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.05 | no |
| 43 | AmmoBox_Barracks | ammo_box.gd | -1.60, 0.00, 32.48 | 180 | +Z | OK | 1.00 / 0.00 / 0.40 / 0.33 | yes | - | 0.05 | no |
| 44 | AmmoBox_SaltChapel | ammo_box.gd | 39.43, -12.00, 78.50 | 90 | -X | OK | 1.00 / 0.00 / 0.33 / 0.27 | yes | - | 0.15 | no |
| 45 | AmmoBox_LabWing | ammo_box.gd | 83.50, -12.00, 95.00 | 90 | -X | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.05 | no |
| 46 | ArmorersBench | armorers_bench.gd | 12.01, 0.00, 8.80 | -90 | +X | OK | 1.00 / 0.00 / 0.00 / 0.40 | yes | - | 0.00 | no |
| 47 | Part_tg_part_bell_boxcar | buildable_part.gd | 55.00, 0.00, 21.00 | 0 | (omni) | OK | 0.60 / 0.60 / 1.00 / 0.67 | yes | - | - | - |
| 48 | Part_tg_part_bell_signal_box | buildable_part.gd | 56.80, 0.00, 46.00 | 0 | (omni) | OK | 0.73 / 0.20 / 1.00 / 0.00 | yes | - | - | - |
| 49 | Part_tg_part_bell_locomotive_cab | buildable_part.gd | 52.50, 0.00, 41.20 | 0 | (omni) | OK | 0.33 / 1.00 / 0.93 / 0.80 | yes | - | - | - |
| 50 | Part_tg_part_frame_top_bunk | buildable_part.gd | -10.50, 1.80, 42.00 | 0 | (omni) | OK | 0.20 / 0.20 / 0.00 / 0.00 | yes | - | - | - |
| 51 | Part_tg_part_frame_quartermaster_cage | buildable_part.gd | -14.60, 0.00, 33.60 | 0 | (omni) | OK | 0.00 / 1.00 / 0.00 / 1.00 | yes | - | - | - |
| 52 | Part_tg_part_frame_mess_stage | buildable_part.gd | 38.60, 0.00, 33.60 | 0 | (omni) | OK | 0.00 / 1.00 / 1.00 / 0.00 | yes | - | - | - |
| 53 | Part_tg_part_crank_bell_tower_base | buildable_part.gd | 4.50, -12.00, 88.60 | 0 | (omni) | OK | 1.00 / 0.00 / 1.00 / 0.60 | yes | - | - | - |
| 54 | Part_tg_part_crank_sacristy | buildable_part.gd | 36.50, -12.00, 88.60 | 0 | (omni) | OK | 1.00 / 0.00 / 1.00 / 1.00 | yes | - | - | - |
| 55 | Part_tg_part_crank_confessional | buildable_part.gd | -14.00, -12.00, 82.70 | 0 | (omni) | OK | 0.60 / 0.60 / 0.00 / 1.00 | yes | - | - | - |
| 56 | Workbench | workbench.gd | 41.65, -12.00, 62.00 | 180 | +Z | OK | 1.00 / 0.00 / 0.20 / 0.00 | yes | - | none | yes |
| 57 | Radio_radio_admin_switch | quest_radio.gd | -1.60, 2.20, 30.20 | 0 | (omni) | OK | 0.67 / 0.00 / 0.40 / 0.00 | yes | - | - | - |
| 58 | Radio_radio_admin_fasbender | quest_radio.gd | -14.20, 4.60, 10.50 | -90 | (omni) | UNREACHABLE | 0.00 / 0.00 / 0.00 / 0.00 | NO | - | - | - |
| 59 | Radio_radio_rail_signalbox | quest_radio.gd | 58.60, 1.00, 46.00 | 90 | (omni) | OK | 0.00 / 0.00 / 0.33 / 0.00 | yes | - | - | - |
| 60 | Radio_radio_mess_kitchen | quest_radio.gd | 37.00, 1.00, 45.10 | 0 | (omni) | OK | 1.00 / 0.00 / 0.00 / 0.27 | yes | - | - | - |
| 61 | Radio_radio_chapel_confessional | quest_radio.gd | -14.30, -12.00, 85.20 | -90 | (omni) | OK | 1.00 / 0.00 / 0.40 / 1.00 | yes | - | - | - |
| 62 | Radio_radio_gen_foreman_desk | quest_radio.gd | 82.00, -11.10, 61.20 | 180 | (omni) | OK | 0.00 / 0.00 / 0.20 / 0.00 | yes | - | - | - |
| 63 | Radio_radio_lab_intake | quest_radio.gd | 71.20, -11.10, 93.70 | 0 | (omni) | UNREACHABLE | 0.00 / 0.00 / 0.00 / 0.00 | NO | - | - | - |
| 64 | Switchboard | switchboard.gd | -3.50, 0.00, 29.50 | 0 | -Z | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | yes |
| 65 | Altar | altar_reliquary.gd | 12.00, -12.00, 81.80 | 0 | (omni) | OK | 1.00 / 0.00 / 0.00 / 0.40 | yes | - | - | - |
| 66 | Cylinder1 | quest_pickup.gd | 12.25, 1.00, 7.00 | 0 | (omni) | OK | 0.07 / 0.00 / 1.00 / 1.00 | yes | - | - | - |
| 67 | Cylinder2 | quest_pickup.gd | -15.30, -9.50, 82.70 | 0 | (omni) | OK | 0.00 / 0.00 / 0.00 / 0.67 | yes | - | - | - |
| 68 | Cylinder3 | quest_pickup.gd | 100.20, -11.00, 86.80 | 0 | (omni) | UNREACHABLE | 0.00 / 0.00 / 0.00 / 0.00 | NO | - | - | - |
| 69 | Phonograph | phonograph.gd | -14.00, 3.80, 30.00 | -90 | (omni) | OK | 1.00 / 0.33 / 0.33 / 0.33 | yes | - | - | - |
| 70 | Tag_KB4471 | quest_pickup.gd | 80.00, -10.60, 97.40 | 0 | (omni) | OK | 1.00 / 0.00 / 0.40 / 0.40 | yes | - | - | - |
| 71 | BankCounter | bank.json branch | -13.45, 0.00, 18.25 | 90 | +X | OK | 1.00 / 0.67 / 1.00 / 1.00 | yes | - | 0.50 | no |
| 72 | ExfilPoint | exfil (map01.json) | 20.00, 0.00, 2.20 | 180 | +Z | OK | 1.00 / 0.33 / 1.00 / 1.00 | yes | - | none | no |

Windows (barricades; layout, not checked): W_A_N1 (yaw 0), W_A_N2 (yaw 0), W_A_W (yaw 90), W_A_E (yaw -90), W_B_N1 (yaw 0), W_B_N2 (yaw 0), W_B_S (yaw 180), W_C_N (yaw 0), W_C_UN (yaw 0), W_C_BAL (yaw -90), W_D_W (yaw 90), W_D_S1 (yaw 180), W_D_S2 (yaw 180), W_E (yaw -90), W_F_W (yaw 90), W_F_S1 (yaw 180), W_F_S2 (yaw 180), W_F_N (yaw 0), W_G_N1 (yaw 0), W_G_N2 (yaw 0), W_H_N (yaw 0), W_H_E1 (yaw -90), W_H_E2 (yaw -90), W_H_S (yaw 180).

### Map 2 Totenhafen

| # | Node | Script | Pos (x, y, z) | Yaw | Front faces | Verdict | Open F / B / +90 / -90 | Reach | Suggested yaw | Back gap (m) | Clips |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Door_Cannery | door.gd | 0.00, 0.00, 15.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 2 | Door_Workshop | door.gd | 32.00, 0.00, 15.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 3 | Door_PenHall_W | door.gd | -10.00, 0.00, 31.50 | 0 | (door) | UNREACHABLE | 0.00 / 0.00 / 0.00 / 0.00 | NO | - | - | - |
| 4 | Door_PenHall_E | door.gd | 44.00, 0.00, 31.50 | 0 | (door) | UNREACHABLE | 0.00 / 0.00 / 0.00 / 0.00 | NO | - | - | - |
| 5 | Door_Gangway | door.gd | 14.00, 0.00, 58.00 | 90 | (door) | OK | 0.40 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 6 | Door_Pumps | door.gd | 49.00, 0.00, 42.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.40 / 0.40 | yes | - | - | - |
| 7 | Door_Signal | door.gd | 42.00, 7.00, 34.00 | 90 | (door) | OK | 0.33 / 0.60 / 0.00 / 0.00 | yes | - | - | - |
| 8 | WallBuy_kar98k | wall_buy.gd | 9.83, 1.50, 13.50 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 9 | WallBuy_m1_carbine | wall_buy.gd | 20.83, 1.50, 5.00 | 90 | -X | OK | 1.00 / 0.00 / 0.40 / 0.40 | yes | - | 0.15 | no |
| 10 | WallBuy_trench_gun | wall_buy.gd | -0.17, 1.50, 22.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 11 | WallBuy_frag | wall_buy.gd | -0.17, 1.50, 26.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 12 | WallBuy_mp40 | wall_buy.gd | 32.17, 1.50, 20.00 | -90 | +X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 13 | WallBuy_stg44 | wall_buy.gd | 32.17, 1.50, 24.00 | -90 | +X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 14 | WallBuy_etool | wall_buy.gd | 61.83, 1.50, 20.00 | 90 | -X | OK | 1.00 / 0.00 / 0.13 / 0.20 | yes | - | 0.00 | no |
| 15 | WallBuy_bar | wall_buy.gd | -4.73, 1.50, 70.00 | -90 | +X | OK | 1.00 / 0.00 / 0.53 / 0.40 | yes | - | 0.15 | no |
| 16 | WallBuy_thompson | wall_buy.gd | 18.83, 1.50, 50.00 | 90 | -X | OK | 0.40 / 0.00 / 0.40 / 0.53 | yes | - | 0.15 | no |
| 17 | Perk_second_wind | perk_machine.gd | -26.00, 0.00, 0.90 | 180 | +Z | OK | 1.00 / 0.00 / 0.27 / 0.00 | yes | - | 0.45 | no |
| 18 | Perk_marathon_malt | perk_machine.gd | -5.00, 0.00, 29.30 | 0 | -Z | OK | 0.53 / 0.00 / 0.27 / 0.27 | yes | - | 0.30 | no |
| 19 | Perk_ironhide_stout | perk_machine.gd | 32.80, 0.00, 8.00 | -90 | +X | OK | 1.00 / 0.00 / 0.47 / 0.40 | yes | - | 0.10 | no |
| 20 | Perk_trigger_tonic | perk_machine.gd | 40.00, 0.00, 0.80 | 180 | +Z | OK | 0.67 / 0.00 / 0.27 / 0.40 | yes | - | 0.35 | no |
| 21 | Perk_overclock_cordial | perk_machine.gd | 42.90, 7.00, 36.70 | -90 | +X | OK | 0.53 / 0.00 / 0.47 / 0.00 | yes | - | 0.45 | no |
| 22 | Perk_hawkeye_brandy | perk_machine.gd | 51.40, 7.00, 36.30 | 90 | -X | OK | 0.67 / 0.00 / 0.00 / 0.00 | yes | - | 0.15 | no |
| 23 | Perk_ledger_lager | perk_machine.gd | 43.60, 0.00, 56.10 | 90 | -X | OK | 1.00 / 0.00 / 0.00 / 0.40 | yes | - | 0.05 | no |
| 24 | Crate_Hut | mystery_crate.gd | 16.60, 0.00, 11.40 | 180 | +Z | OK | 1.00 / 0.00 / 0.00 / 1.00 | yes | - | 0.85 | no |
| 25 | Crate_Warheads | mystery_crate.gd | 58.60, 0.00, 19.00 | 180 | +Z | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 26 | Crate_Pier0 | mystery_crate.gd | -18.50, 0.00, 81.00 | 0 | -Z | OK | 0.93 / 0.93 / 0.00 / 0.67 | yes | - | none | no |
| 27 | Crate_Pumps | mystery_crate.gd | 42.00, -3.00, 79.00 | 0 | -Z | OK | 0.67 / 0.67 / 0.67 / 0.67 | yes | - | none | no |
| 28 | Crate_Teletype | mystery_crate.gd | 49.40, 7.00, 34.60 | 90 | -X | OK | 1.00 / 0.00 / 1.00 / 0.00 | yes | - | none | no |
| 29 | Pumpenschalter | power_switch.gd | 50.90, -2.70, 70.00 | 90 | -X | OK | 1.00 / 0.00 / 0.80 / 0.80 | yes | - | 0.90 | no |
| 30 | Coffin_0 | ballast_coffin.gd | 36.50, 0.00, 40.00 | 0 | (omni) | OK | 1.00 / 0.00 / 0.67 / 0.00 | yes | - | - | - |
| 31 | Coffin_1 | ballast_coffin.gd | 50.00, 0.00, 70.00 | 0 | (omni) | OK | 1.00 / 0.67 / 0.00 / 0.00 | yes | - | - | - |
| 32 | Coffin_2 | ballast_coffin.gd | 56.00, 0.00, 22.50 | 0 | (omni) | OK | 0.67 / 0.67 / 0.33 / 0.33 | yes | - | - | - |
| 33 | BallastHook | ballast_hook.gd | 40.00, 0.00, 60.00 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 34 | Crucible | crucible.gd | 7.00, -2.00, 40.00 | 180 | +Z | OK | 1.00 / 0.00 / 0.00 / 0.33 | yes | - | 1.20 | no |
| 35 | AmmoBox_Cannery | ammo_box.gd | -29.52, 0.00, 18.00 | -90 | +X | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.05 | no |
| 36 | AmmoBox_Workshop | ammo_box.gd | 61.50, 0.00, 13.00 | 90 | -X | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.05 | no |
| 37 | AmmoBox_PenHallWest | ammo_box.gd | 0.00, 0.00, 33.33 | 180 | +Z | OK | 1.00 / 0.00 / 0.07 / 0.13 | yes | - | 0.05 | no |
| 38 | AmmoBox_PenHallEast | ammo_box.gd | 51.52, 0.00, 77.00 | 90 | -X | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.05 | no |
| 39 | ArmorersBench | armorers_bench.gd | 16.30, 0.00, 17.16 | 180 | +Z | OK | 1.00 / 1.00 / 0.33 / 0.20 | yes | - | 0.00 | no |
| 40 | Lever_Trolley | trap_lever.gd | 48.00, 0.00, 29.60 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.35 | no |
| 41 | Lever_Grille | trap_lever.gd | 44.00, -3.00, 50.70 | 180 | +Z | OK | 1.00 / 0.00 / 0.40 / 0.40 | yes | - | 0.35 | no |
| 42 | BankCounter | bank.json branch | 44.90, 0.00, 58.30 | 0 | +Z | OK | 1.00 / 0.00 / 0.27 / 0.33 | yes | - | 0.00 | yes |
| 43 | ExfilPoint | exfil (map02.json) | 7.00, 0.00, 35.00 | 180 | +Z | OK | 0.67 / 0.33 / 1.00 / 1.00 | yes | - | none | no |

Windows (barricades; layout, not checked): W_A_N1 (yaw 0), W_A_N2 (yaw 0), W_A_S1 (yaw 180), W_A_S2 (yaw 180), W_B_N (yaw 0), W_B_W1 (yaw 90), W_B_W2 (yaw 90), W_C_N (yaw 0), W_C_E1 (yaw -90), W_C_E2 (yaw -90), W_D_N1 (yaw 0), W_D_N2 (yaw 0), W_D_N3 (yaw 0), W_G_N1 (yaw 0), W_G_N2 (yaw 0).

### Test range

| # | Node | Script | Pos (x, y, z) | Yaw | Front faces | Verdict | Open F / B / +90 / -90 | Reach | Suggested yaw | Back gap (m) | Clips |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Perk_ironhide_stout | perk_machine.gd | 4.00, 0.00, 0.90 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.30 | no |
| 2 | Perk_second_wind | perk_machine.gd | 9.00, 0.00, 0.90 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.60 | no |
| 3 | Perk_trigger_tonic | perk_machine.gd | 14.00, 0.00, 0.90 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.60 | no |
| 4 | Perk_twin_barrel | perk_machine.gd | 19.00, 0.00, 0.90 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.60 | no |
| 5 | Perk_marathon_malt | perk_machine.gd | 24.00, 0.00, 0.90 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.45 | no |
| 6 | Perk_hawkeye_brandy | perk_machine.gd | 29.00, 0.00, 0.90 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.60 | no |
| 7 | Perk_packmule_porter | perk_machine.gd | 34.00, 0.00, 0.90 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.50 | no |
| 8 | Perk_blastproof_bock | perk_machine.gd | 39.00, 0.00, 0.90 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.45 | no |
| 9 | WallBuy_m1911 | wall_buy.gd | 0.02, 1.50, 4.00 | -90 | +X | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 10 | WallBuy_kar98k | wall_buy.gd | 0.02, 1.50, 8.00 | -90 | +X | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 11 | WallBuy_m1_garand | wall_buy.gd | 0.02, 1.50, 12.00 | -90 | +X | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 12 | WallBuy_gewehr43 | wall_buy.gd | 0.02, 1.50, 16.00 | -90 | +X | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 13 | WallBuy_m1_carbine | wall_buy.gd | 0.02, 1.50, 20.00 | -90 | +X | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 14 | WallBuy_mp40 | wall_buy.gd | 0.02, 1.50, 24.00 | -90 | +X | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 15 | WallBuy_thompson | wall_buy.gd | 43.98, 1.50, 4.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 16 | WallBuy_stg44 | wall_buy.gd | 43.98, 1.50, 8.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 17 | WallBuy_trench_gun | wall_buy.gd | 43.98, 1.50, 12.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 18 | WallBuy_bar | wall_buy.gd | 43.98, 1.50, 16.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 19 | WallBuy_ppsh41 | wall_buy.gd | 43.98, 1.50, 20.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 20 | WallBuy_mg42 | wall_buy.gd | 43.98, 1.50, 24.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 21 | WallBuy_m1919 | wall_buy.gd | 4.00, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 22 | WallBuy_sawed_off | wall_buy.gd | 8.50, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 23 | WallBuy_type100 | wall_buy.gd | 13.00, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 24 | WallBuy_ptrs41 | wall_buy.gd | 17.50, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 25 | WallBuy_springfield | wall_buy.gd | 22.00, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 26 | WallBuy_panzerschreck | wall_buy.gd | 26.50, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 27 | WallBuy_flamethrower | wall_buy.gd | 31.00, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 28 | WallBuy_ashlight | wall_buy.gd | 35.50, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 29 | WallBuy_frag | wall_buy.gd | 38.00, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 30 | WallBuy_etool | wall_buy.gd | 41.50, 1.50, 29.98 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 31 | Crucible | crucible.gd | 40.00, 0.00, 16.00 | 90 | -X | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 32 | Crate_Range | mystery_crate.gd | 22.00, 0.00, 7.00 | 180 | +Z | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |

