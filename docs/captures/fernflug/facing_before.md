# Fernflug interactables: facing BEFORE the fix (UPDATE 13 Part 0 / Part 3, T-218)

Every interactable on the four Fernflug acts as the scenes stood on master `e96a0188`, with its current facing and
the facing check's verdict. Made with:

```
godot --headless --audio-driver Dummy --path . --script res://tools/tests/test_interactable_facing.gd -- --md=<tables>
```

How to read it (the checker is `gravelight/tools_src/interactable_facing.gd`, from the scene file alone):

- **Front faces**: the world axis the object's front points along (+X east, +Z north on Fernflug). Most scripts face
  local -Z (perk machines, wall buys, ammo boxes, the crate, the Crucible, the bench, power switches, trap levers,
  the heater and vent levers, the workbench, the exfil post); the bank counter, the Account console and the
  Kranich's breach plates face local +Z. "(omni)" objects (quest props, parts, rails, hatches) and "(door)" are
  usable from any side and only checked for reach.
- **Open F / B / +90 / -90**: the share of 15 sample points (0.8-1.8 m past the body's front face, 1.2 m wide) on the
  baked navmesh at the object's floor with a clear chest-high line to the object, if its front faced that way
  (F = as placed, B = turned 180, +90 / -90 = turned by that yaw).
- **Verdict**: OK (front open), BACKWARDS / SIDEWAYS (front shut, the turned side open: the suggested yaw), UNSURE
  (no side clearly right; reported, not failed), UNREACHABLE (no navmesh spot reaches the use box).
- **Back gap**: metres from the body's back face to the wall behind it (now -> after the suggested turn).
  **Clips**: the body overlaps a collider (a wall buy whose front is in the wall "clips" by its 12 cm depth).
- The Crucible is locked (the owner: it is right); windows are layout and only listed.

The pattern: Act I (Werk Thalbach) is right except the Armorer's Bench (its bench ran into the wall). Acts II-IV
(Kranich, Groom Lake, Mondlicht) were authored with the yaw sign flipped: almost every perk machine, wall buy and
ammo box faces the wall it stands on (the T-175 note on the Kranich's Crucible was the same mistake).

## Summary

| Map | Interactables (windows aside) | OK | BACKWARDS | SIDEWAYS | UNSURE | UNREACHABLE | Windows |
|---|---|---|---|---|---|---|---|
| map04a | 53 | 51 | 1 | 0 | 0 | 1 | 17 |
| map04b | 67 | 49 | 17 | 1 | 0 | 0 | 7 |
| map04c | 55 | 32 | 20 | 0 | 1 | 2 | 11 |
| map04d | 35 | 18 | 17 | 0 | 0 | 0 | 8 |

## Every interactable

### Fernflug Act I, Werk Thalbach (map04a)

| # | Node | Script | Pos (x, y, z) | Yaw | Front faces | Verdict | Open F / B / +90 / -90 | Reach | Suggested yaw | Back gap (m) | Clips |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Door_Bahnhof | door.gd | 20.00, 0.00, 30.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 2 | Door_Kantine | door.gd | 0.00, 0.00, 45.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.07 / 0.20 | yes | - | - | - |
| 3 | Door_Kirchplatz | door.gd | 20.00, 0.00, 60.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 4 | Door_Montage | door.gd | -22.00, 0.00, 60.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.20 / 0.20 | yes | - | - | - |
| 5 | Door_Windkanal | door.gd | 8.00, 0.00, 100.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.13 | yes | - | - | - |
| 6 | Door_Pruefstand | door.gd | -30.00, 0.00, 110.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 7 | Door_ServiceGate | door.gd | 0.00, 0.00, 122.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 8 | Door_Halle | door.gd | -30.00, 0.00, 150.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.20 / 0.20 | yes | - | - | - |
| 9 | WallBuy_kar98k | wall_buy.gd | 12.17, 1.50, 6.00 | -90 | +X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 10 | WallBuy_m1_carbine | wall_buy.gd | 36.00, 1.50, 29.83 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 11 | WallBuy_mp40 | wall_buy.gd | 39.83, 1.50, 50.00 | 90 | -X | OK | 1.00 / 0.00 / 0.07 / 0.20 | yes | - | 0.00 | no |
| 12 | WallBuy_thompson | wall_buy.gd | -10.00, 1.50, 59.83 | 0 | -Z | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 13 | WallBuy_m1_garand | wall_buy.gd | 26.17, 1.50, 90.00 | -90 | +X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.15 | no |
| 14 | WallBuy_stg44 | wall_buy.gd | -0.17, 1.50, 80.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 15 | WallBuy_bar | wall_buy.gd | -0.17, 1.50, 114.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.00 | no |
| 16 | Perk_second_wind | perk_machine.gd | 1.00, 0.00, 22.00 | -90 | +X | OK | 0.67 / 0.00 / 0.60 / 0.40 | yes | - | 0.55 | no |
| 17 | Perk_ironhide_stout | perk_machine.gd | 36.00, 0.00, 31.00 | 180 | +Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.30 | no |
| 18 | Perk_trigger_tonic | perk_machine.gd | -1.00, 0.00, 56.00 | 90 | -X | OK | 0.67 / 0.00 / 0.47 / 0.60 | yes | - | 0.55 | no |
| 19 | Perk_twin_barrel | perk_machine.gd | 6.00, 0.00, 99.00 | 0 | -Z | OK | 1.00 / 0.00 / 0.47 / 0.53 | yes | - | 0.55 | no |
| 20 | Perk_marathon_malt | perk_machine.gd | -10.00, 0.00, 109.00 | 0 | -Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.40 | no |
| 21 | Perk_hawkeye_brandy | perk_machine.gd | 1.00, 0.00, 126.00 | -90 | +X | OK | 0.67 / 0.00 / 0.60 / 0.47 | yes | - | 0.55 | no |
| 22 | Perk_packmule_porter | perk_machine.gd | -20.00, 0.00, 149.00 | 0 | -Z | OK | 1.00 / 0.00 / 0.40 / 0.60 | yes | - | 0.45 | no |
| 23 | Perk_blastproof_bock | perk_machine.gd | -40.00, 0.00, 149.00 | 0 | -Z | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.40 | no |
| 24 | Perk_ledger_lager | perk_machine.gd | 3.60, 0.00, 57.45 | 0 | -Z | OK | 0.67 / 0.00 / 0.00 / 0.00 | yes | - | 0.05 | no |
| 25 | Crate_Cellar | mystery_crate.gd | 7.00, 0.00, 3.20 | 180 | +Z | OK | 1.00 / 0.00 / 0.80 / 0.80 | yes | - | 0.70 | no |
| 26 | Crate_Shed | mystery_crate.gd | 34.00, 0.00, 58.60 | 0 | -Z | OK | 1.00 / 0.00 / 1.00 / 1.00 | yes | - | 0.85 | no |
| 27 | Crate_Parish | mystery_crate.gd | 36.00, 0.00, 98.60 | 0 | -Z | OK | 1.00 / 0.00 / 1.00 / 1.00 | yes | - | 0.85 | no |
| 28 | Crate_Bunker | mystery_crate.gd | -50.00, 0.00, 148.60 | 0 | -Z | OK | 1.00 / 0.00 / 1.00 / 0.33 | yes | - | 0.85 | no |
| 29 | Hauptschalter | power_switch.gd | -59.00, 0.00, 66.00 | -90 | +X | OK | 1.00 / 0.00 / 0.60 / 0.60 | yes | - | 0.80 | no |
| 30 | Crucible | crucible.gd | -58.50, 0.00, 146.00 | -90 | +X | OK | 0.73 / 0.00 / 1.00 / 0.67 | yes | - | 0.55 | yes |
| 31 | AmmoBox_Siedlung | ammo_box.gd | 6.00, 0.00, 29.48 | 0 | -Z | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.10 | no |
| 32 | AmmoBox_Bahnhof | ammo_box.gd | 0.52, 0.00, 34.00 | -90 | +X | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.10 | no |
| 33 | AmmoBox_Kantine | ammo_box.gd | -43.48, 0.00, 34.00 | -90 | +X | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.10 | no |
| 34 | AmmoBox_Montage | ammo_box.gd | -30.00, 0.00, 60.52 | 180 | +Z | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.10 | no |
| 35 | AmmoBox_Pruefstand | ammo_box.gd | -59.48, 0.00, 134.00 | -90 | +X | OK | 1.00 / 0.00 / 0.27 / 0.27 | yes | - | 0.10 | no |
| 36 | AmmoBox_Halle | ammo_box.gd | -69.48, 0.00, 153.00 | -90 | +X | UNREACHABLE | 0.00 / 0.00 / 0.13 / 0.00 | NO | - | 0.10 | yes |
| 37 | ArmorersBench | armorers_bench.gd | 30.00, 0.00, 0.66 | 0 | -Z | BACKWARDS | 0.00 / 1.00 / 0.40 / 0.40 | NO | 180 | none -> 0.50 | yes -> no |
| 38 | Lever_CoalHopper | trap_lever.gd | 39.60, 0.00, 47.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.20 | no |
| 39 | Lever_JigCrane | trap_lever.gd | -0.40, 0.00, 90.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.20 | no |
| 40 | Lever_RivetLine | trap_lever.gd | -47.75, 0.00, 72.00 | -90 | +X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.05 | no |
| 41 | File1 | quest_note.gd | -14.40, 0.82, 105.60 | 0 | (omni) | OK | 1.00 / 0.93 / 1.00 / 0.67 | yes | - | - | - |
| 42 | File2 | quest_note.gd | 41.00, 0.82, 121.00 | 0 | (omni) | OK | 1.00 / 1.00 / 0.73 / 0.80 | yes | - | - | - |
| 43 | File3 | quest_note.gd | -57.60, 0.82, 147.00 | 0 | (omni) | OK | 0.20 / 1.00 / 0.00 / 0.67 | yes | - | - | - |
| 44 | PASwitchboard | switchboard.gd | -39.00, 0.00, 53.20 | 0 | -Z | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 45 | WindTunnel | wind_tunnel.gd | 4.60, 0.00, 121.00 | 90 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 46 | RampSwitch | quest_interact.gd | -20.00, 0.00, 160.50 | 180 | (omni) | OK | 0.00 / 1.00 / 0.40 / 0.40 | yes | - | - | - |
| 47 | Glider1 | quest_note.gd | -36.00, 0.30, 54.30 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 48 | Glider2 | quest_note.gd | -42.00, 0.10, 96.00 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 0.33 | yes | - | - | - |
| 49 | Glider3 | quest_note.gd | 33.00, 0.10, 119.60 | 0 | (omni) | OK | 0.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 50 | JetteHatch | quest_interact.gd | 43.20, 0.00, 124.00 | -90 | (omni) | OK | 0.00 / 1.00 / 0.60 / 0.60 | yes | - | - | - |
| 51 | Breach_E_apron | breach_door.gd | -55.00, 0.00, 110.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 52 | BankCounter | bank.json branch | 3.00, 0.00, 52.00 | 0 | +Z | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | no |
| 53 | ExfilPoint | exfil (map04a.json) | -20.00, 0.00, 157.00 | 0 | -Z | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |

Windows (barricades; layout, not checked): W_A_S1 (yaw 0), W_A_S2 (yaw 0), W_A_W (yaw 90), W_A_E (yaw -90), W_B_W (yaw 90), W_B_N (yaw 180), W_B_E (yaw -90), W_C_W (yaw 90), W_C_S (yaw 0), W_D_E1 (yaw -90), W_D_E2 (yaw -90), W_E_N (yaw 180), W_E_W (yaw 90), W_F_E (yaw -90), W_F_N (yaw 180), W_G_W (yaw 90), W_G_E (yaw -90).

### Fernflug Act II, der Kranich (map04b)

| # | Node | Script | Pos (x, y, z) | Yaw | Front faces | Verdict | Open F / B / +90 / -90 | Reach | Suggested yaw | Back gap (m) | Clips |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Door_Mittelrumpf | door.gd | 0.00, 0.00, 24.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 2 | Door_FluegelL | door.gd | -9.00, 0.00, 36.00 | 90 | (door) | OK | 1.00 / 0.87 / 0.00 / 0.00 | yes | - | - | - |
| 3 | Door_FluegelR | door.gd | 9.00, 0.00, 36.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.20 / 0.00 | yes | - | - | - |
| 4 | Door_Triebwerk | door.gd | -52.00, 0.00, 36.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 5 | Door_Kanzel | door.gd | 52.00, 0.00, 36.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.20 / 0.20 | yes | - | - | - |
| 6 | Door_CockpitL | door.gd | -22.00, 0.00, 56.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.20 / 0.13 | yes | - | - | - |
| 7 | Door_CockpitR | door.gd | 22.00, 0.00, 56.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.20 / 0.20 | yes | - | - | - |
| 8 | WallBuy_kar98k | wall_buy.gd | -8.83, 1.50, 6.00 | 90 | -X | BACKWARDS | 0.00 / 0.33 / 0.20 / 0.20 | NO | -90 | none -> 0.00 | yes -> no |
| 9 | WallBuy_mp40 | wall_buy.gd | 8.83, 1.50, 30.00 | -90 | +X | BACKWARDS | 0.00 / 0.20 / 0.07 / 0.00 | NO | 90 | none -> 0.00 | yes -> no |
| 10 | WallBuy_thompson | wall_buy.gd | -30.00, 1.50, 45.83 | 180 | +Z | BACKWARDS | 0.00 / 0.60 / 0.00 / 0.20 | NO | 0 | none -> 0.00 | yes -> no |
| 11 | WallBuy_stg44 | wall_buy.gd | 30.00, 1.50, 45.83 | 180 | +Z | BACKWARDS | 0.00 / 0.60 / 0.20 / 0.00 | NO | 0 | none -> 0.00 | yes -> no |
| 12 | WallBuy_bar | wall_buy.gd | 66.00, 1.50, 57.83 | 180 | +Z | BACKWARDS | 0.00 / 1.00 / 0.20 / 0.20 | NO | 0 | none -> 0.00 | yes -> no |
| 13 | Perk_second_wind | perk_machine.gd | 6.00, 0.00, 22.80 | 180 | +Z | BACKWARDS | 0.00 / 1.00 / 0.60 / 0.53 | NO | 0 | none -> 0.80 | no -> no |
| 14 | Perk_skyhook_sekt | perk_machine.gd | -7.80, 0.00, 30.00 | 90 | -X | BACKWARDS | 0.00 / 0.67 / 0.67 / 0.80 | NO | -90 | none -> 0.70 | no -> no |
| 15 | Perk_trigger_tonic | perk_machine.gd | 7.80, 0.00, 33.60 | -90 | +X | BACKWARDS | 0.00 / 0.67 / 0.00 / 0.87 | NO | 90 | none -> 0.75 | no -> no |
| 16 | Perk_ironhide_stout | perk_machine.gd | -24.00, 0.00, 44.60 | 180 | +Z | BACKWARDS | 0.00 / 0.80 / 0.67 / 0.00 | NO | 0 | none -> 0.65 | no -> no |
| 17 | Perk_marathon_malt | perk_machine.gd | 24.00, 0.00, 44.60 | 180 | +Z | BACKWARDS | 0.00 / 0.73 / 0.00 / 1.00 | NO | 0 | none -> 0.80 | no -> no |
| 18 | Perk_blastproof_bock | perk_machine.gd | -60.00, 0.00, 25.40 | 0 | -Z | BACKWARDS | 0.00 / 1.00 / 0.20 / 0.60 | NO | 180 | none -> 0.80 | no -> no |
| 19 | Perk_hawkeye_brandy | perk_machine.gd | 56.00, 0.00, 56.60 | 180 | +Z | BACKWARDS | 0.00 / 1.00 / 0.80 / 0.80 | NO | 0 | none -> 0.95 | no -> no |
| 20 | Perk_packmule_porter | perk_machine.gd | 6.00, 0.00, 72.60 | 180 | +Z | BACKWARDS | 0.00 / 1.00 / 0.93 / 0.73 | NO | 0 | none -> 0.85 | no -> no |
| 21 | Perk_ledger_lager | perk_machine.gd | -5.00, 0.00, 53.45 | 0 | -Z | OK | 0.67 / 0.00 / 0.33 / 0.33 | yes | - | 0.05 | no |
| 22 | Crate_Galley | mystery_crate.gd | -6.00, 0.00, 50.00 | 90 | -X | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 23 | Crate_Kanzel | mystery_crate.gd | 76.90, 0.00, 33.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.80 / 0.80 | NO | 90 | none -> 0.55 | no -> no |
| 24 | AuxBus | aux_bus.gd | 8.70, 0.00, 42.00 | 90 | -X | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | 0.15 | no |
| 25 | Crucible | crucible.gd | -6.00, 0.00, 34.00 | -90 | +X | OK | 1.00 / 0.67 / 1.00 / 0.67 | yes | - | none | no |
| 26 | AmmoBox_Bay | ammo_box.gd | -8.48, 0.00, 20.00 | 90 | -X | BACKWARDS | 0.00 / 0.80 / 0.27 / 0.27 | NO | -90 | none -> 0.10 | no -> no |
| 27 | AmmoBox_Galley | ammo_box.gd | 8.48, 0.00, 50.00 | -90 | +X | SIDEWAYS | 0.00 / 0.00 / 0.00 / 0.27 | NO | 180 | none -> none | yes -> yes |
| 28 | AmmoBox_Triebwerk | ammo_box.gd | -77.48, 0.00, 44.00 | 90 | -X | BACKWARDS | 0.00 / 1.00 / 0.27 / 0.00 | NO | -90 | none -> 0.10 | no -> no |
| 29 | AmmoBox_Kanzel | ammo_box.gd | 77.48, 0.00, 44.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.27 / 0.27 | NO | 90 | none -> 0.10 | no -> no |
| 30 | Tag1 | quest_note.gd | 7.00, 0.72, 27.00 | 0 | (omni) | OK | 0.67 / 0.33 / 0.33 / 0.00 | yes | - | - | - |
| 31 | Tag2 | quest_note.gd | 7.00, 0.72, 31.20 | 0 | (omni) | OK | 0.47 / 0.13 / 0.33 / 0.00 | yes | - | - | - |
| 32 | Tag3 | quest_note.gd | 62.00, 0.10, 25.60 | 0 | (omni) | OK | 0.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 33 | BreachL1 | breach_panel.gd | -20.00, 0.00, 46.00 | 180 | -Z | OK | 0.60 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | yes |
| 34 | BreachL2 | breach_panel.gd | -40.00, 0.00, 46.00 | 180 | -Z | OK | 0.60 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | yes |
| 35 | BreachR1 | breach_panel.gd | 20.00, 0.00, 46.00 | 180 | -Z | OK | 0.60 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | yes |
| 36 | BreachR2 | breach_panel.gd | 40.00, 0.00, 46.00 | 180 | -Z | OK | 0.60 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | yes |
| 37 | Rack1 | bomb_rack.gd | -5.60, 0.00, 6.00 | 90 | (omni) | OK | 0.33 / 0.33 / 0.33 / 0.33 | yes | - | - | - |
| 38 | Rack2 | bomb_rack.gd | 5.60, 0.00, 6.00 | -90 | (omni) | OK | 0.00 / 0.33 / 0.33 / 0.33 | yes | - | - | - |
| 39 | Rack3 | bomb_rack.gd | -5.60, 0.00, 12.00 | 90 | (omni) | OK | 0.33 / 0.33 / 0.33 / 0.33 | yes | - | - | - |
| 40 | Rack4 | bomb_rack.gd | 5.60, 0.00, 12.00 | -90 | (omni) | OK | 0.00 / 0.33 / 0.33 / 0.33 | yes | - | - | - |
| 41 | Rack5 | bomb_rack.gd | -5.60, 0.00, 18.00 | 90 | (omni) | OK | 0.33 / 0.33 / 0.67 / 0.33 | yes | - | - | - |
| 42 | Rack6 | bomb_rack.gd | 5.60, 0.00, 18.00 | -90 | (omni) | OK | 0.00 / 0.33 / 0.33 / 0.33 | yes | - | - | - |
| 43 | WingHatchOut | wing_hatch.gd | -40.00, 0.00, 45.30 | 0 | (omni) | OK | 0.60 / 0.00 / 0.13 / 0.40 | yes | - | - | - |
| 44 | WingHatchIn | wing_hatch.gd | -40.00, 3.40, 45.10 | 0 | (omni) | OK | 0.60 / 0.00 / 0.00 / 0.00 | yes | - | - | - |
| 45 | ClipPoint1 | clip_point.gd | -39.40, 3.40, 41.00 | 0 | (omni) | OK | 0.40 / 0.40 / 0.33 / 0.00 | yes | - | - | - |
| 46 | ClipPoint2 | clip_point.gd | -45.00, 3.40, 36.60 | 0 | (omni) | OK | 0.33 / 0.00 / 0.40 / 0.40 | yes | - | - | - |
| 47 | ClipPoint3 | clip_point.gd | -49.80, 3.40, 29.00 | 0 | (omni) | OK | 0.60 / 0.60 / 0.00 / 0.00 | yes | - | - | - |
| 48 | ClipPoint4 | clip_point.gd | -58.00, 3.40, 21.60 | 0 | (omni) | OK | 0.33 / 0.00 / 0.40 / 0.40 | yes | - | - | - |
| 49 | ClipPoint5 | clip_point.gd | -70.00, 3.40, 21.60 | 0 | (omni) | OK | 0.33 / 0.00 / 0.40 / 0.40 | yes | - | - | - |
| 50 | ClipPoint6 | clip_point.gd | -82.00, 3.40, 21.60 | 0 | (omni) | OK | 0.33 / 0.00 / 0.40 / 0.40 | yes | - | - | - |
| 51 | ClipPoint7 | clip_point.gd | -94.00, 3.40, 21.60 | 0 | (omni) | OK | 0.33 / 0.00 / 0.40 / 0.40 | yes | - | - | - |
| 52 | ClipPoint8 | clip_point.gd | -104.00, 3.40, 21.60 | 0 | (omni) | OK | 0.33 / 0.00 / 0.40 / 0.40 | yes | - | - | - |
| 53 | ClipPoint9 | clip_point.gd | -111.00, 3.40, 23.50 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 54 | WingChest | wing_chest.gd | -112.00, 3.40, 29.60 | 0 | (omni) | OK | 1.00 / 0.00 / 1.00 / 1.00 | yes | - | - | - |
| 55 | CrewRoster | quest_interact.gd | 8.70, 0.00, 44.60 | 90 | (omni) | OK | 1.00 / 1.00 / 0.00 / 0.20 | yes | - | - | - |
| 56 | BordfunkReel | quest_interact.gd | 5.30, 0.00, 48.00 | -90 | (omni) | OK | 0.00 / 1.00 / 0.40 / 0.40 | yes | - | - | - |
| 57 | Lever_BayDoors | trap_lever.gd | 5.00, 0.00, 23.75 | 0 | -Z | OK | 0.53 / 0.00 / 0.20 / 0.00 | yes | - | 0.05 | no |
| 58 | GripBay1 | rail_grip.gd | -8.60, 0.00, 3.00 | -90 | (omni) | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | - | - |
| 59 | GripBay2 | rail_grip.gd | 8.60, 0.00, 3.00 | 90 | (omni) | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | - | - |
| 60 | GripBay3 | rail_grip.gd | -8.60, 0.00, 8.50 | -90 | (omni) | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | - | - |
| 61 | GripBay4 | rail_grip.gd | 8.60, 0.00, 8.50 | 90 | (omni) | OK | 1.00 / 0.00 / 0.20 / 0.20 | yes | - | - | - |
| 62 | GripStb1 | rail_grip.gd | 26.00, 0.00, 45.70 | 0 | (omni) | OK | 0.60 / 0.00 / 0.00 / 0.20 | yes | - | - | - |
| 63 | GripStb2 | rail_grip.gd | 34.00, 0.00, 45.70 | 0 | (omni) | OK | 0.60 / 0.00 / 0.07 / 0.20 | yes | - | - | - |
| 64 | GripStb3 | rail_grip.gd | 24.00, 0.00, 28.30 | 180 | (omni) | OK | 0.60 / 0.00 / 0.07 / 0.20 | yes | - | - | - |
| 65 | GripStb4 | rail_grip.gd | 36.00, 0.00, 28.30 | 180 | (omni) | OK | 0.60 / 0.00 / 0.07 / 0.20 | yes | - | - | - |
| 66 | BankCounter | bank.json branch | 0.00, 0.00, 52.50 | 180 | -Z | OK | 1.00 / 0.00 / 0.13 / 0.13 | yes | - | none | no |
| 67 | ExfilPoint | exfil (map04b.json) | 0.00, 0.00, 66.00 | 180 | +Z | OK | 1.00 / 0.67 / 0.67 / 0.67 | yes | - | none | no |

Windows (barricades; layout, not checked): W_A_L (yaw 90), W_A_R (yaw -90), W_B_L (yaw 90), W_B_R (yaw -90), W_CL_S (yaw 0), W_CR_S (yaw 0), W_D_W (yaw 90).

### Fernflug Act III, Groom Lake (map04c)

| # | Node | Script | Pos (x, y, z) | Yaw | Front faces | Verdict | Open F / B / +90 / -90 | Reach | Suggested yaw | Back gap (m) | Clips |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Door_Lakebed | door.gd | 0.00, 0.00, -4.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.20 / 0.33 | yes | - | - | - |
| 2 | Door_Hangar | door.gd | 45.00, 0.00, 60.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 3 | Door_Motorpool | door.gd | -45.00, 0.00, 60.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 4 | Door_Side | door.gd | 20.00, 0.00, 93.00 | 90 | (door) | OK | 1.00 / 0.67 / 0.20 / 0.13 | yes | - | - | - |
| 5 | Door_Radar | door.gd | 45.00, 0.00, 100.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 6 | Door_Lab | door.gd | -45.00, 0.00, 100.00 | 0 | (door) | OK | 0.67 / 0.33 / 0.07 / 0.00 | yes | - | - | - |
| 7 | Door_Trench | door.gd | 20.00, 0.00, 137.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.07 / 0.00 | yes | - | - | - |
| 8 | Door_Silo | door.gd | -40.00, -6.00, 150.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 9 | WallBuy_m1_carbine | wall_buy.gd | -13.83, 1.50, -30.00 | 90 | -X | BACKWARDS | 0.00 / 1.00 / 0.20 / 0.20 | NO | -90 | none -> 0.00 | yes -> no |
| 10 | WallBuy_m1_garand | wall_buy.gd | -59.83, 1.50, 20.00 | 90 | -X | BACKWARDS | 0.00 / 1.00 / 0.20 / 0.20 | NO | -90 | none -> 0.00 | yes -> no |
| 11 | WallBuy_thompson | wall_buy.gd | 69.83, 1.50, 72.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.20 / 0.20 | NO | 90 | none -> 0.00 | yes -> no |
| 12 | WallBuy_bar | wall_buy.gd | -69.83, 1.50, 70.00 | 90 | -X | BACKWARDS | 0.00 / 1.00 / 0.20 / 0.20 | NO | -90 | none -> 0.00 | yes -> no |
| 13 | WallBuy_springfield | wall_buy.gd | 69.83, 1.50, 110.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.20 / 0.20 | NO | 90 | none -> 0.00 | yes -> no |
| 14 | Perk_second_wind | perk_machine.gd | -8.00, 0.00, -35.20 | 0 | -Z | BACKWARDS | 0.00 / 0.73 / 0.40 / 0.40 | NO | 180 | none -> 0.35 | no -> no |
| 15 | Perk_ironhide_stout | perk_machine.gd | -59.20, 0.00, 44.00 | 90 | -X | BACKWARDS | 0.00 / 0.67 / 0.60 / 0.60 | NO | -90 | none -> 0.05 | no -> no |
| 16 | Perk_magpie_mead | perk_machine.gd | 20.80, 0.00, 86.00 | 90 | -X | BACKWARDS | 0.00 / 0.67 / 0.47 / 0.60 | NO | -90 | none -> 0.35 | no -> no |
| 17 | Perk_trigger_tonic | perk_machine.gd | -20.80, 0.00, 70.00 | -90 | +X | BACKWARDS | 0.00 / 0.73 / 0.60 / 0.40 | NO | 90 | none -> 0.35 | no -> no |
| 18 | Perk_hawkeye_brandy | perk_machine.gd | 20.80, 0.00, 120.00 | 90 | -X | BACKWARDS | 0.00 / 0.67 / 0.40 / 0.60 | NO | -90 | none -> 0.35 | no -> no |
| 19 | Perk_twin_barrel | perk_machine.gd | -57.20, -6.00, 112.80 | 0 | -Z | BACKWARDS | 0.00 / 0.47 / 0.00 / 0.40 | NO | 180 | none -> 0.35 | no -> no |
| 20 | Perk_blastproof_bock | perk_machine.gd | -20.80, -6.00, 125.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.60 / 0.60 | NO | 90 | none -> 0.20 | no -> no |
| 21 | Perk_packmule_porter | perk_machine.gd | -69.20, -6.00, 170.00 | 90 | -X | BACKWARDS | 0.00 / 0.67 / 0.53 / 0.60 | NO | -90 | none -> 0.25 | no -> no |
| 22 | Perk_skyhook_sekt | perk_machine.gd | -20.80, -6.00, 165.00 | -90 | +X | BACKWARDS | 0.00 / 0.67 / 0.60 / 0.47 | NO | 90 | none -> 0.30 | no -> no |
| 23 | Perk_ledger_lager | perk_machine.gd | 54.00, 0.00, 99.45 | 0 | -Z | OK | 0.67 / 0.00 / 0.27 / 0.33 | yes | - | 0.05 | no |
| 24 | Crate_Wreck | mystery_crate.gd | 6.00, 0.00, -12.00 | -90 | +X | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 25 | Crate_Hangar | mystery_crate.gd | 26.00, 0.00, 76.00 | 90 | -X | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 26 | Crate_Lab | mystery_crate.gd | -26.00, -6.00, 114.00 | 90 | -X | OK | 1.00 / 1.00 / 1.00 / 0.33 | yes | - | none | no |
| 27 | Generator | power_switch.gd | -64.00, 0.00, 99.30 | 180 | +Z | UNREACHABLE | 0.00 / 0.00 / 0.00 / 0.00 | NO | - | 0.90 | no |
| 28 | Crucible | crucible.gd | -66.00, -6.00, 160.00 | -90 | +X | OK | 1.00 / 0.00 / 0.73 / 0.53 | yes | - | none | no |
| 29 | AmmoBox_Wreck | ammo_box.gd | 13.48, 0.00, -30.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.27 / 0.33 | NO | 90 | none -> 0.10 | no -> no |
| 30 | AmmoBox_Hangar | ammo_box.gd | 69.48, 0.00, 88.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.27 / 0.27 | NO | 90 | none -> 0.10 | no -> no |
| 31 | AmmoBox_Motorpool | ammo_box.gd | -45.00, 0.00, 99.48 | 180 | +Z | BACKWARDS | 0.20 / 1.00 / 0.33 / 0.27 | yes | 0 | none -> none | no -> no |
| 32 | AmmoBox_Silo | ammo_box.gd | -69.48, -6.00, 185.00 | 90 | -X | BACKWARDS | 0.00 / 1.00 / 0.27 / 0.27 | NO | -90 | none -> 0.10 | no -> no |
| 33 | Lever_FuelDump | trap_lever.gd | -36.00, 0.00, 97.00 | 180 | +Z | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 34 | Lever_HangarDoor | trap_lever.gd | 49.40, 0.00, 60.45 | 0 | -Z | BACKWARDS | 0.00 / 1.00 / 0.40 / 0.40 | NO | 180 | none -> 0.25 | no -> no |
| 35 | TowerLadder_Foot | tower_ladder.gd | 45.00, 1.00, 116.70 | 180 | (omni) | OK | 0.67 / 0.00 / 0.00 / 0.00 | yes | - | - | - |
| 36 | TowerLadder_Top | tower_ladder.gd | 45.00, 16.00, 117.60 | 180 | (omni) | OK | 0.00 / 0.00 / 0.40 / 0.40 | yes | - | - | - |
| 37 | Jukebox | jukebox.gd | 20.55, 0.00, 76.00 | -90 | +X | OK | 1.00 / 0.00 / 0.40 / 0.40 | yes | - | 0.10 | no |
| 38 | Part_ls_part_coil_relay_object | buildable_part.gd | 60.00, 0.00, 62.80 | 0 | (omni) | OK | 0.67 / 0.33 / 1.00 / 1.00 | yes | - | - | - |
| 39 | Part_ls_part_coil_bomber_bay | buildable_part.gd | 45.00, 0.00, 70.80 | 0 | (omni) | OK | 1.00 / 0.33 / 1.00 / 1.00 | yes | - | - | - |
| 40 | Part_ls_part_cradle_dish_gimbal | buildable_part.gd | 45.00, 1.00, 120.00 | 0 | (omni) | UNREACHABLE | 0.67 / 0.33 / 0.67 / 0.40 | NO | - | - | - |
| 41 | Part_ls_part_cradle_shack | buildable_part.gd | 62.00, 0.00, 127.20 | 0 | (omni) | OK | 1.00 / 0.67 / 0.80 / 0.80 | yes | - | - | - |
| 42 | Part_ls_part_lens_stone_port | buildable_part.gd | -60.20, -6.00, 131.00 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 43 | Part_ls_part_lens_specimen_3 | buildable_part.gd | -64.00, -6.00, 146.00 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 44 | Workbench | workbench.gd | -60.00, -6.00, 114.20 | 0 | -Z | BACKWARDS | 0.00 / 1.00 / 0.40 / 0.13 | NO | 180 | none -> none | no -> no |
| 45 | DeeRadio | story_radio.gd | 61.60, 0.00, 96.00 | -90 | (omni) | OK | 0.67 / 1.00 / 0.40 / 0.40 | yes | - | - | - |
| 46 | RadarRadio | story_radio.gd | 62.00, 0.00, 127.60 | 180 | (omni) | OK | 0.67 / 1.00 / 0.40 / 0.40 | yes | - | - | - |
| 47 | ImpellerCore | carry_object.gd | 20.00, 0.40, 16.50 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 48 | HangarCradle | carry_cradle.gd | 36.40, 0.00, 96.00 | -90 | (omni) | OK | 1.00 / 1.00 / 0.20 / 0.20 | yes | - | - | - |
| 49 | RocketCradle | carry_cradle.gd | -36.60, -6.00, 173.00 | 90 | (omni) | OK | 1.00 / 0.00 / 0.40 / 1.00 | yes | - | - | - |
| 50 | SiloConsole | silo_console.gd | -58.00, -6.00, 177.60 | 180 | (omni) | OK | 0.00 / 1.00 / 0.40 / 0.40 | yes | - | - | - |
| 51 | CageItem_casing | cage_item.gd | -7.50, 0.00, -16.00 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 52 | CageItem_bomber_coil | cage_item.gd | 51.60, 0.00, 92.40 | 0 | (omni) | OK | 0.40 / 1.00 / 0.40 / 1.00 | yes | - | - | - |
| 53 | CageItem_honey | cage_item.gd | 23.20, 0.90, 69.00 | 0 | (omni) | OK | 0.20 / 0.20 / 0.33 / 1.00 | yes | - | - | - |
| 54 | BankCounter | bank.json branch | 64.00, 0.00, 90.90 | 180 | -Z | OK | 1.00 / 0.00 / 0.00 / 0.00 | yes | - | 0.00 | yes |
| 55 | ExfilPoint | exfil (map04c.json) | -38.00, -6.00, 176.00 | -90 | +X | UNSURE | 0.33 / 1.00 / 1.00 / 1.00 | yes | - | none | no |

Windows (barricades; layout, not checked): W_A_L (yaw 90), W_A_R (yaw -90), W_C_W (yaw 90), W_C_E (yaw -90), W_C_N (yaw 180), W_D_W (yaw 90), W_D_N (yaw 180), W_E_E (yaw -90), W_F_1 (yaw 90), W_F_3 (yaw 90), W_G_N (yaw 180).

### Fernflug Act IV, Mondlicht (map04d)

| # | Node | Script | Pos (x, y, z) | Yaw | Front faces | Verdict | Open F / B / +90 / -90 | Reach | Suggested yaw | Back gap (m) | Clips |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Door_Concourse | door.gd | 0.00, 0.00, 24.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 2 | Door_Yard | door.gd | 0.00, 0.00, 60.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 3 | Door_FulfillmentB | door.gd | 12.00, 0.00, 42.00 | 90 | (door) | OK | 1.00 / 1.00 / 0.40 / 0.33 | yes | - | - | - |
| 4 | Door_FulfillmentY | door.gd | 28.00, 0.00, 60.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 5 | Door_Hall | door.gd | 28.00, 0.00, 24.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.20 / 0.20 | yes | - | - | - |
| 6 | Door_Account | door.gd | 28.00, 0.00, -16.00 | 0 | (door) | OK | 1.00 / 1.00 / 0.00 / 0.00 | yes | - | - | - |
| 7 | WallBuy_kar98k | wall_buy.gd | -11.83, 1.50, 16.00 | 90 | -X | BACKWARDS | 0.00 / 1.00 / 0.20 / 0.20 | NO | -90 | none -> 0.00 | yes -> no |
| 8 | WallBuy_thompson | wall_buy.gd | 11.83, 1.50, 32.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.00 / 0.20 | NO | 90 | none -> 0.00 | yes -> no |
| 9 | WallBuy_springfield | wall_buy.gd | -39.60, 1.50, 80.00 | 90 | -X | BACKWARDS | 0.00 / 0.67 / 0.20 / 0.20 | NO | -90 | none -> 0.35 | no -> no |
| 10 | WallBuy_bar | wall_buy.gd | 43.83, 1.50, 42.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.20 / 0.20 | NO | 90 | none -> 0.00 | yes -> no |
| 11 | Perk_second_wind | perk_machine.gd | 8.00, 0.00, 22.60 | 180 | +Z | BACKWARDS | 0.00 / 1.00 / 0.73 / 0.73 | NO | 0 | none -> 0.95 | no -> no |
| 12 | Perk_skyhook_sekt | perk_machine.gd | -11.30, 0.00, 30.00 | 90 | -X | BACKWARDS | 0.00 / 0.67 / 0.33 / 0.40 | NO | -90 | none -> 0.20 | no -> no |
| 13 | Perk_magpie_mead | perk_machine.gd | 11.30, 0.00, 30.00 | -90 | +X | BACKWARDS | 0.00 / 0.67 / 0.40 / 0.27 | NO | 90 | none -> 0.25 | no -> no |
| 14 | Perk_ironhide_stout | perk_machine.gd | 12.70, 0.00, 50.00 | 90 | -X | BACKWARDS | 0.00 / 1.00 / 0.40 / 0.47 | NO | -90 | none -> 0.00 | no -> no |
| 15 | Perk_trigger_tonic | perk_machine.gd | 43.30, 0.00, 28.00 | -90 | +X | BACKWARDS | 0.00 / 0.67 / 0.40 / 0.27 | NO | 90 | none -> 0.25 | no -> no |
| 16 | Perk_hawkeye_brandy | perk_machine.gd | 12.70, 0.00, 16.00 | 90 | -X | BACKWARDS | 0.00 / 0.67 / 0.27 / 0.40 | NO | -90 | none -> 0.25 | no -> no |
| 17 | Perk_blastproof_bock | perk_machine.gd | 43.30, 0.00, -8.00 | -90 | +X | BACKWARDS | 0.00 / 0.67 / 0.40 / 0.40 | NO | 90 | none -> 0.10 | no -> no |
| 18 | Perk_packmule_porter | perk_machine.gd | 14.70, 0.00, -24.00 | 90 | -X | BACKWARDS | 0.00 / 0.67 / 0.40 / 0.40 | NO | -90 | none -> 0.15 | no -> no |
| 19 | Perk_ledger_lager | perk_machine.gd | 11.45, 0.00, 36.60 | -90 | +X | BACKWARDS | 0.00 / 0.67 / 0.40 / 0.40 | NO | 90 | none -> 0.05 | no -> no |
| 20 | Crate_Reception | mystery_crate.gd | -7.00, 0.00, 18.00 | 90 | -X | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 21 | Crate_Concourse | mystery_crate.gd | 7.00, 0.00, 56.00 | -90 | +X | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | none | no |
| 22 | Crucible | crucible.gd | -8.00, 0.00, 46.00 | -90 | +X | OK | 1.00 / 0.00 / 0.80 / 0.60 | yes | - | none | no |
| 23 | AmmoBox_Reception | ammo_box.gd | 11.48, 0.00, 4.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.27 / 0.27 | NO | 90 | none -> 0.10 | no -> no |
| 24 | AmmoBox_Concourse | ammo_box.gd | -11.48, 0.00, 56.00 | 90 | -X | BACKWARDS | 0.00 / 1.00 / 0.27 / 0.27 | NO | -90 | none -> 0.10 | no -> no |
| 25 | AmmoBox_Store | ammo_box.gd | 43.48, 0.00, 56.00 | -90 | +X | BACKWARDS | 0.00 / 1.00 / 0.27 / 0.27 | NO | 90 | none -> 0.10 | no -> no |
| 26 | AmmoBox_Hall | ammo_box.gd | 12.52, 0.00, -12.00 | 90 | -X | BACKWARDS | 0.00 / 1.00 / 0.27 / 0.27 | NO | -90 | none -> 0.10 | no -> no |
| 27 | SmileMarker | quest_interact.gd | 0.00, 0.00, 104.00 | 180 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 28 | Column_1 | retention_column.gd | 18.00, 0.30, 4.00 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 29 | Column_2 | retention_column.gd | 28.00, 0.30, 4.00 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 30 | Column_3 | retention_column.gd | 38.00, 0.30, 4.00 | 0 | (omni) | OK | 1.00 / 1.00 / 1.00 / 1.00 | yes | - | - | - |
| 31 | AccountConsole | account_console.gd | 28.00, 0.00, -30.00 | 0 | +Z | OK | 1.00 / 1.00 / 0.67 / 0.67 | yes | - | none | no |
| 32 | HeaterSwitch | heater_switch.gd | -7.50, 0.00, 59.55 | 0 | -Z | OK | 1.00 / 0.00 / 0.40 / 0.40 | yes | - | 0.10 | no |
| 33 | ShaftGrateLever | shaft_grate_lever.gd | 15.05, 0.00, -20.00 | -90 | +X | OK | 1.00 / 0.00 / 0.80 / 0.80 | yes | - | 0.75 | no |
| 34 | TagSlot | tag_slot.gd | 26.20, 0.00, -29.20 | 90 | (omni) | OK | 1.00 / 0.20 / 1.00 / 0.87 | yes | - | - | - |
| 35 | BankCounter | bank.json branch | -11.10, 0.00, 35.20 | 90 | +X | OK | 1.00 / 0.00 / 0.07 / 0.00 | yes | - | none | yes |

Windows (barricades; layout, not checked): W_A_L (yaw 90), W_A_R (yaw -90), W_B_L (yaw 90), W_B_R (yaw -90), W_D_E1 (yaw -90), W_D_E2 (yaw -90), W_E_E1 (yaw -90), W_E_E2 (yaw -90).

