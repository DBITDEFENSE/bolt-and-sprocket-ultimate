# CUTSCENE POLISH — the LAZARUS cutscenes, the director's pass (T-206)

The owner: "I like the cutscene for the most part, but a lot of the animations are just a little bit off." This is
that pass over the five LAZARUS cutscenes (docs/CUTSCENES_LAZARUS.md; data/gravelight/cutscenes_lazarus.json; the
stages in gravelight/world/cinema_sets/). Nothing here changes a story beat, a line, a card or a length: every
cutscene still runs its T-194 seconds. Gameplay is untouched.

How it was audited: no GPU. `gravelight/tools_src/probe_cinema_pose.tscn` plays a cutscene headless (the Archive's
way) and logs, three times per shot, where the lens is and what every person is doing (distance and off-axis angle
to the lens, in frame or not at the shot's lens, speed over the ground, head and hand heights, props in hands, any
body part within 0.4 m of the lens). The numbers below are from those logs, before and after. Run it with
`godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/probe_cinema_pose.tscn -- --cut=<id>`
(the stage beats are in real seconds, so read the walks at `--speed=1`).

## What was off everywhere (the puppet), and the fix in CinemaPerson

The people are PatronBody puppets on the ZombieRig (T-092 / T-194): a pose solver hands hips, chest, head, leg
angles and hand targets to the rig every frame. Four things in that solver read as "off" in every shot with a
person in it:

1. **Pose changes snapped.** The cutscene poses (hold, palm, pray, kneel, writing) switched in one frame: Serafim's
   hand jumped up for the palm and back for the keys, Volkov's lantern hand jumped, a kneel dropped the hips 37 cm
   in a frame. Now the hand targets glide (about 0.3 s), a kneel folds and a rise comes up (about 0.4 s), the head
   turns (about 0.3 s). A teleport (`reset_motion()`) snaps: a cut shows the new pose on its first frame.
2. **Feet skated.** The puppet's leg swing is a fixed small amplitude (0.5 rad at 3 m/s, 0.17 rad at a walk) over
   a fixed 0.7 m stride, so at a walk the feet covered about 0.3 m per step while the body covered 0.7 m: everyone
   slid. Walking now has its own gait: the stride follows the speed (0.45-0.85 m a step walking, 0.9-1.3 at a run)
   and the hip swing is set so the foot's arc equals the stride, so a planted foot stays put against the ground.
   The puppet's own bob and arm pump are kept in step with it.
3. **Nobody looked at anybody.** Heads were fixed on the body. `look_toward(point)` aims the head (within a neck's
   range, the chest following a fifth of the turn) and the stages use it: Serafim looks down at the young man on
   the step, Volkov up at him, the colonel at Volkov, the soldiers at the mound, Reinholt at her dials.
4. **Hands reached for nothing.** Hand targets were pose constants: Reinholt's hands hung 35 cm in front of the
   dial, Volkov's 25 cm short of the vessel, Selwyn's 34 cm short of the yoke. `hand_l` / `hand_r` are chest-local
   overrides a stage sets or tweens (the handset passed, a hand to a cap, a sign of the cross, the throttles);
   `hold_width` spreads the hold (arms round the case, two hands on a rope).

Also new: `walk_to(target, m/s)` turns the person to face the way first, then moves at a walking speed (the old
sine-eased position tweens peaked at 1.6x their mean speed and never turned anyone: people strafed sideways);
`turn_to(yaw)` turns the short way round (the old `rotation:y` tweens went the long way from 180 to 0);
`reset_motion()` also kills a walk still running, so a teleport on a cut is not dragged back along the old path.
Poses added: `raise` (a lantern up at eye level), `binoculars` (both hands at the eyes).

## LAZARUS SATURDAY (34 shots, 240 s)

| # | t | What was off | What changed | Left |
|---|---|---|---|---|
| 4 | 27 | The brigade spawned inside the truck (two men in the cab, one in a mudguard) and three of the eight walked through the bonnet to their spots; Volkov spawned in the front-right wheel; the four on the truck bed popped out at once. | They come down the truck's far side (x -1.75, z 39.6-41.2), walk a waypoint clear of the nose at 1.5 m/s, then to a loose group ahead of it; Volkov from the near cab door at 0.95 m/s, looking at the kneeling road at 1.5 s and quickly away to the men at 3.4 s (the shot list's beat); the head from the far door; the bed's four fade out a quarter second apart. | At 1 m/s the eighth man is still arriving when shot 5 cuts; the shot is 9 s and the walk is 7 m. Acceptable (they keep walking into shot 5). |
| 5 | 36 | The kneelers stood in one frame and slid sideways 2-9 m facing the church (a sine tween, 0.4-1.9 m/s), the long walks and the short ones all in 5.5 s. | Each rises (blended), turns to its side of the road and walks there at 0.9-1.1 m/s, a step every 0.6 s; the brigade walk forward at 1 m/s. | The people are out of focus in the foreground (blur 0.5), as the shot list says; a rise from a kneel is the puppet's blend, not a get-up animation. |
| 6 | 46 | Serafim's palm came up in one frame. | It rises over 0.3 s; his head looks over the lens to the road. | |
| 7 | 53 | Hand down in one frame; Serafim (on the porch, 1 m up) looked straight ahead over Volkov's cap, Volkov straight into his cassock. | Serafim looks down at Volkov's face (head 0.28 rad), Volkov reads his paper (head_down 0.32) then looks up at Serafim at 0.9 s. | |
| 8 | 60 | The brigade head stood facing 20 degrees away from the door while his line played; nobody reacted to it. | He faces the door (yaw -12); the shot has an fx hook (`reverse`): Serafim and the head look at their partners, Volkov glances at the head on his line (4.4 s) and back (7.0 s). | |
| 9 | 68 | Volkov "turns to him" turned 55 degrees to his left, where nobody stood (the head was 114 degrees round). | `turn_to` the head's actual bearing over 1 s; the head and Serafim look at Volkov. | |
| 10 | 78 | "The ring of keys in Serafim's hand": the hands were 34 degrees off the lens axis, outside a 35-degree lens (frame: his chest). | Lens at (0.5, 2.2, 3.4) looking at the hands (-0.1, 2.05, 2.72): the hands dead centre at 0.9 m (probe: 3 degrees off). The takers walk in at 0.8 m/s. | |
| 12 | 84 | Serafim "below, out of focus, praying" was 92 degrees off the lens: not in the shot. The rope ran from under the tower to 2.3 m beside the bell; the six "haulers" stood 6 m from its end with their backs to the tower. | The crane starts on Serafim praying (6 degrees off at 3.1 m) under his line and tilts up the rope to the men at the yoke; the rope runs from the bell to the first hauler's hands and along the line of three haulers facing the tower, hands on it (`hold_width` 0.06); the two who keep Serafim flank him facing him; the rest watch. | The belfry men "work a crowbar" with empty raised hands (no crowbar prop). |
| 13 | 92 | The rope hung in the air after the bell left it. | It goes with the bell (hidden at the drop); the haulers let go and step back 1.6 m. | |
| 15 | 103 | The brigade "running out" moved at 3.2 m/s in the standing pose (no run), Volkov stayed 10 m from a tower about to fall. | They run (`run` pose, 3 m/s) and turn to watch at the end; Volkov walks back fast (2.2 m/s) with his board; the rope is gone. | |
| 17 | 117 | "Volkov by the truck, writing... looks up at Serafim and looks ashamed": Volkov was 78 degrees off the lens, not in the shot at all. | A two-shot from (-3.0, 1.4, 25.5): Serafim kneeling (13 degrees off, 8.8 m) and Volkov in the road 6 m from him (26 degrees, 4 m), writing head-down, looking up at Serafim on his line (3.0 s) and back down to the board (6.4 s); Serafim turns his head to him on his own line; the head and the brigade in the background. The truck is behind the lens now. | "Coughing" is not animated. |
| 18 | 125 | Volkov slid down the stair standing still (0.17 m/s over 7 s: under the puppet's walk threshold); the two lantern bearers crept 10 cm/s (a slide). | He walks down at 0.4 m/s with a 0.3 m stride (a step a tread), watching his feet, his own lantern low in his hand (new: he carries one; the shot list has "Volkov's lantern" in 19); the bearers stand at the foot. | Feet interpolate along the stair's slope (no step-height IK): from behind they hover a little between treads. |
| 19 | 132 | "Volkov's lantern comes up to read them": he had no lantern, his hands were at chest height, and the back of his head was 0.45 m in front of the lens. | He stands to the lens's left (68 degrees off, out of frame) with the lantern raised to the stone (`raise`: the hand at eye level, the lantern hanging 0.4 m under the letters, lit); lens moved to (0.05, -0.75, -3.25). Serafim on the stair looks at the line too. | |
| 20-21 | 140 | Three men abreast in a 1.0 m doorway (shoulders through each other). | Serafim in the door by its left jamb, the guards inside the room either side (x -0.85 / 0.78), the bearers wider; everyone looks at the vessel, Serafim at Volkov on his lines. | |
| 22 | 158 | Hands 25 cm short of the vessel and 7 cm above it; the lens ended inside Volkov's right hip (0.37 m); an `in_sine` push (accelerating into the cut). | He kneels at z -7.92 (hands on the lid), his lantern set on the step beside it with its light; the right hand works at the wax (a small loop) then follows the lid as it comes off and sets it down left of the vessel; the lens over his right side (0.9 -> 0.75 m from his shoulder), easing `smooth`. | No knife prop; the wax lifts on its own. |
| 23 | 166 | Volkov's hands hovered at the mouth the lens is on (the left 0.35 m from the glass). | His hands are drawn back onto his knees, behind the vessel from this lens. | |
| 24 | 172 | "Standing up too fast": the cut showed him already standing. | The cut shows him kneeling and he rises over 0.4 s, the hands dropping; at 0.5 s he turns his face to the men; the men and Serafim look at him. | |
| 25 | 178 | The bearers walked through Serafim (x +-0.25 against his 0) and through the jamb. | Single file through the door on his right by a waypoint inside the room (1.1 m/s), the colonel's lantern-bearers first, Volkov last with the lantern; Serafim says it to nobody, head straight. | |
| 29 | 202 | The cordon "their backs to us" faced the lens (yaw 180). | Yaw 0: backs to us, facing the burning village. | |
| 31 | 218 | Fine (both arms round the case: hands on its lid). | `hold_width` not changed here; left as built. | |

## FOURTH DAY (12 shots, 106 s)

| # | t | What was off | What changed | Left |
|---|---|---|---|---|
| 1 | 6 | A linear dolly. | Kept linear: a continuous track in from black and out on a cut is right; an ease would make it stop. | |
| 2 | 14 | The OP's roof bottom was at 1.69 m: the officers' caps (head centres 1.64-1.66) were inside the logs and so was the lens (1.75). "With binoculars" meant hands at the chest. | The roof is 23 cm higher (a lintel log keeps the slit at 1.35-1.69); the officers hold binoculars (a prop) at their eyes; the slit's light is in the slit, so it lights the faces that look out. | |
| 3 | 26 | The lens was 0.29 m inside the colonel's raised hands; "he gives it to the colonel without a word" was nothing (the handset appeared in Volkov's hand); the colonel's line played at 0.4 s, before any handover. | Lens in the slit (0.55, 1.5, 248.0), the officers 0.85 m either side; the colonel lowers his binoculars (0.3 s), Volkov's right hand carries the handset across (0.5-1.4 s), the colonel's left takes it (1.55 s) and brings it to his ear; the line SVR_FTD_02 moved to 2.0 s (data). | |
| 4 | 32 | Volkov's hands 0.13 m behind the lens. | Lens 25 cm forward in the slit opening. | |
| 5 | 40 | The lens 5 cm inside a slit log; "the colonel lowers the binoculars and asks with his face" was nothing. | Lens clear of the log; fx `colonel_asks`: he lowers them at 0.4 s and turns his head to Volkov at 1.0 s; Volkov keeps his eyes on the trench and gives him one look on the last line (4.3-7.6 s). | |
| 7 | 56 | "Soldiers with their backs to it": they faced the graves (yaw 0) from the start, so the turn in 8 was a shrug. | Yaw 180 (facing the kitchen); the turn is real. | |
| 8 | 64 | The turn tweened `rotation:y` the long way round. | Head first (`look_toward`), then `turn_to` the short way, 0.35 s apart. | |
| 9 | 72 | "One takes off his cap. One crosses himself and looks round to see who saw": nothing moved. | fx `faces`: soldier 2's hand to his cap and down (1.0-3.2 s); soldier 5 crosses himself (forehead, chest, right, left, 2.0-3.9 s) and looks at his neighbour (4.1 s) and back. | The cap stays on his head (no cap-in-hand prop); "the sergeant's hand goes to his rifle sling" is not done (no rifles). |
| 10 | 79 | The lens was inside soldier 7's shoulder (0.55 m from his centre at head height). | From the cart's far side (9.3, 1.4, 10.6), the aerial against the cloud, the soldiers out of frame. | |
| 11 | 87 | A linear track. | Kept linear (a tracking shot in on a dip, out on a cut). The risen walk on RisenColumn's clips, speed-scaled, so they were already planted. | |

## STAUB (10 shots, 73 s)

| # | t | What was off | What changed | Left |
|---|---|---|---|---|
| 1 | 5 | The mill crew "at the hopper" faced away from it (yaw 180 +- 30). | Yaw 0 +- 20: they face the sifter and the hopper. | |
| 2 | 12 | Reinholt "at the gauges" faced away from them (yaw 150, the dials behind her); "she writes a number" was a static writing pose. | Yaw -12 (facing the bank; the lens is over her shoulder onto the dials); she watches the dials, bows to the board on REI_STB_02 (5.8 s) and looks back up (8.6 s). | |
| 3 | 23 | "A crew in winter whites" stood 8 m behind the dolly, never in frame. | Two at the rails clamping a canister (hold, hands up), one checking the low end: 11-27 degrees off, in frame. | |
| 4 | 32 | The vane was at the frame's top edge (27 degrees up at a 55-degree lens), the hut's window out of frame. | Lens at (-124.5, 28.6, 65) looking a little lower: vane 17 degrees up, the lit window at the bottom. | |
| 8 | 62 | Reinholt's hands hung 35 cm in front of the dial. | She stands at the console (z -0.95), her left hand on the dial (probe: hand at (-0.05, 1.17, -1.39), the dial at (-0.05, 1.17, -1.38)); not looking at the gauges (head up a little), bowing her head on "Liesl. Mama is here." (4.0 s). | The dial turns under a still hand (no finger motion). |

## GRAVELIGHT ONE (11 shots, 84 s)

| # | t | What was off | What changed | Left |
|---|---|---|---|---|
| 2 | 16 | "Over a passenger's shoulder" had no shoulder: everyone sat, the lens stood beside an empty seat (T-194 had un-hooked `lean_window` because a standing man blocked the glass). | The window passenger stands half a metre aft of the window, a hand on the frame, looking down through it; the lens beside him at (-0.35, 1.7, 0.75) sees past his shoulder (his head 32 degrees off, at the frame's edge) through the window (the ray passes 0.09 m from its centre). His own line plays here. | |
| 3 | 25 | "Closer on the window": the lens stood where the passenger now stands. | The next window aft (bay 5), lens at (-1.02, 1.3, 1.55), the ray 0.07 m from the glass's centre; the passenger 0.77 m away, out of frame. | |
| 4 | 33 | Over both shoulders, but yawed right: Selwyn 41 degrees off, the co-pilot 26. | The look starts at x 0.1 (36 / 30 degrees) and pans to the violet light as before. | |
| 5 | 41 | "One checks a watch": nothing. | fx `watch`: the second passenger's left wrist comes up and he looks down at it (1.0-3.2 s). | |
| 6 | 48 | Selwyn's hands hovered 34 cm short of the yoke; "his hands do everything right" was a still pose; the co-pilot's cap intruded at the frame edge. | The yokes 12 cm nearer (a seated reach), both pilots' hands on them; a pedestal with throttles and an overhead panel; Selwyn's right hand to the throttles and back (1.0-3.1 s), left up to the overhead switches and back (3.2-5.2 s), a glance up; lens a touch left. | |
| 7 | 56 | The aircraft's centre was 45 degrees off a 40-degree lens: half the plane out of the frame; the look point 24 degrees down. | Look (24, -22, -54) from the plane: the plane 16 degrees right of centre and the inn's lights 2 degrees right, both in. The drift stays linear (1 m over 7 s, relative to the plane). | |
| 8 | 63 | "Hands on the seat frames, heads down": the passengers sat upright; the loose crates flew through the lens (crate 0's path crossed the camera position). | fx `brace` (sit_brace, heads down 0.55 rad) before the crash; the crates go forward down the starboard side, 0.65 m from the lens. | |

## The epilogue (1953)

Nothing moves but the fingers; left as built.

## What stays off, and needs assets

- The bodies are the relief squads' dressed kit bodies with primitive costume pieces; a close face has no mouth shapes
  except Selwyn's and the squad's (people.json). Lip flap on the Russian lines would need the LAZARUS cast built as
  people.json GLBs (tools/build_people.sh).
- There is no get-up or kneel animation: a kneel is the solver's blend (0.4 s). A real sit-to-stand, a cough, a
  cross made with a cap in hand, a crowbar at a yoke, a knife under wax are clips or props this pass could not make.
- Feet on stairs follow the slope (no per-step foot IK); feet never slide on the flat now, but a stair is a ramp.
- The hands are IK to a point: there is no finger pose, so a hand "on" a dial or a yoke is a closed fist at it.
- The truck's brigade walk 7 m in a 5.4 s window at 1.5 m/s: the last man arrives in the next shot.
- The stage beats (walks, looks, the handover) are in real seconds; CinemaReel's `speed` (the smokes run at 10-12x)
  does not scale them, so at a fast-forward the walks fall behind the clock. At the game's speed 1 they are right.

## The clip tool

`clip_cutscene.gd --cut=<id> --stills=<dir> --every=1` still films any of the five; it needs a GPU window
(off-screen, `--position -4000,-4000 --audio-driver Dummy`). This pass was done on the probe's numbers only.
