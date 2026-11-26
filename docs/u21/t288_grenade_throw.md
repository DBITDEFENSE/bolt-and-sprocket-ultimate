# T-288: an animated grenade throw (2026-11-26)

The owner: "MAKE A THROWING ANIMATION FOR GRENADES". Branch `claude/grenade-throw`, cut from master after T-284.
Not merged, not pushed.

**Unchanged:** when the grenade leaves (the release of the lethal button, the same tick), where (0.6 m ahead of the
eye, 0.1 m down), how fast and how high, the cook fuse, damage, the throw's 0.25 s viewmodel window (which never
blocked firing and still does not), prompts, the bots' throw rules. Tested with the animation on and off for a tap,
a short hold and a long cook. `WeaponHolder.throw_anim` (`CZ_T288_OFF=1`) brings back the old two-pose snap.

## What changed

| Part | Where | What it does |
|---|---|---|
| **First person: the press** | `WeaponHolder._throw_hand`, `throw_pose` | The left hand brings the grenade up to the gun hand's knuckles (0.2 s); the thumb hooks the ring and it drops away (the pin flies off as a small piece, as the brass does); the arm draws back and holds the grenade up by the head (0.22 s). |
| **First person: the cook** | the same | While held, the cook pose stays, with a tremor that grows over the fuse's last 1.5 s. The gun is lowered as before. |
| **First person: the release** | `WeaponHolder._throw_released` | On the existing release tick the hand is put ON the spawn point's spot in the viewmodel (`vm_target`: the same ray from the eye, undoing the viewmodel's FOV scale), the grenade leaves it there, the spoon flies off, the arm swings through forward and down and comes back to the gun inside the existing 0.25 s. A tap (no time to draw back) jumps straight to the release point. |
| **The tactical (Siren Gramophone)** | `_throw_tactical` | The same follow-through (it leaves on the press, as before). |
| **The frag model** | `WeaponModels._w_frag` | The ring and the spoon are parts of their own (`Pin`, `Spoon`), so they can be pulled and thrown off. |
| **Third person: the release** | `RemoteBody.throw_hand`, `fire(4, ...)` | A bot's or a remote player's left hand starts its swing at the release point and goes forward and down, back to the gun in the existing 0.4 s. The local player now sends the spawn point as the throw's origin (it sent its eye; only the remote body reads it); a bot already sent its spawn point. A point out of the arm's reach (an older peer's eye origin) is pulled in along the same line. |
| **Third person: the cook** | `NetMatch.PF_COOK`, `RemoteBody` | A remote player cooking holds the arm drawn back with a grenade in the fist: one new bit in the pose flags byte (its last spare bit, 128). An older peer ignores it; a Soldier's own 128 (its revive) is never read as a cook. Bots throw on the spot, so their throw is the follow-through alone. |

Jakub never throws a grenade (no throw in his code), so he has no throw to animate.

Per-frame cost only while a grenade is cooked or thrown (the pose is a few lerps; the pin and spoon pieces use the
existing debris pool of the brass and magazines).

## Pictures

`docs/captures/t288/` (WSL Xvfb, Compatibility on software GL, a lit studio; `shots_grenade_throw.tscn`), with a
contact sheet per sequence:

- `fp_00..29.png`, `sheet_fp.png`: first person, a frame every 0.05 s from the press: the grenade comes up to the gun
  hand (00-03), the ring flies off (03), the arm draws back to the top left with the forearm in view (06-09), the
  cook pose held (09-17), the release (18: the real grenade in flight at the centre, the hand low in its swing), the
  gun coming back (20-29).
- `cook_00..10.png`, `sheet_cook.png`: the last 1.2 s of a full cook: the hand trembles a few millimetres.
- `tp_00..19.png`, `sheet_tp.png`: third person (from behind and to the side): on the gun (00-02), PF_COOK raises the
  left arm by the head (03-09), the release swings it forward and down (10-14) and back to the gun (15-19).

Looked at: the pin pull and the cook pose read clearly; the release is a one-frame snap from the drawn-back pose to the
release point (the grenade must leave on the button's release: see the proposal), so in the stills the hand is
already low in its follow-through when the grenade is seen in flight; the third-person arm is readable but small at
this distance.

## Checks run

All headless on Windows in `.wt/locker` on `claude/grenade-throw` (rebased on master `a8be1615`, Godot Physics);
logs `.smoke_logs/t288/` (git-ignored).

- Script check: 1048 scripts, 0 failed.
- Full GUT: 2709 tests, 2707 passing, 1 risky (the known one), 1 failing: `test_hud_stamp_perks ::
  test_round_stamp_fits_high_rounds` ("Lambda capture at index 0 was freed", an order effect from an earlier test
  file); it passes 2 of 2 alone.
- `test_t288_grenade_throw` (new, 6): the release tick, the spawn point, the speed and the fuse equal with the
  animation on and off (a tap, a 20-tick hold, a 90-tick cook); the hand on the spawn point's spot at the release;
  the phases in order, ending on the gun, without a jump; interrupted (downed, bled out, a carry-over) puts the arm
  back and leaves no grenade in the hand; a ladder grab mid-cook still throws on the release; the pin and the spoon
  are parts; the third person swings from the release point (pulled into reach when far), holds the cook on
  PF_COOK and empties the fist on the release.
- Smokes PASS, 0 script errors: `smoke_coop`, `smoke_squads` (the bots throw), `smoke_feel`, `smoke_interact`,
  `smoke_weapon_locker`, `smoke_u19_box`, `smoke_map_companions`, and on the rebased branch `smoke_move_feel` and
  `smoke_ammo_box` (both failed before the rebase: the first was Jolt's stair step-up, now off on master; the second
  Map 0's fifth ammo box, fixed on master).

## Not verified

- Seen only in WSL's software renderer, in a studio (not on the owner's GPU, not in a map at night).
- A co-op client watching a host cook (PF_COOK is sent by the same pose packet; tested on the body, not over the
  wire). An older peer receiving the new origin: it ignores the origin of a throw, so nothing changes for it.
- How it feels in the hand: the release can only start on the button's release, so the draw back happens at the
  press and the swing after the release (see the proposal).

## Proposals for the owner (not built: they change the throw's timing)

1. **A true wind-up.** A real throw swings before the grenade leaves. Today the grenade must leave on the button's
   release, so the animation draws back at the press and follows through after the release. A 0.1-0.15 s delay
   between the release and the grenade leaving would let the arm swing forward first and look and feel weightier,
   at the price of a slightly later grenade (and a cooked one gaining that time on the fuse).
2. **Bots cook.** Bots throw instantly; letting them hold a cooked grenade for a moment (their fuse already tuned to
   the flight) would show the cook pose on them too. It changes when their grenades go off.
