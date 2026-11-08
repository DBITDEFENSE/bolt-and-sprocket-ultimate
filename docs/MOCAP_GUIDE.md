# MOCAP_GUIDE: filming the squad's cutscenes with a phone (UPDATE 12 section 4, T-210)

The squad's cutscenes run in the engine: the GRAVELIGHT ONE crash, the trips between maps, the Kaltenbrunn Requiem
ending and Fernflug's acts. Right now the people in them are moved by code: they stand, turn, walk and sit, and that's
about it. This guide is for filming yourselves (no acting experience needed, one phone) so they move like people.

Every shot below says who plays it, where to stand, where the phone goes, what to do, how long it lasts, what to hold,
and the line that plays (the recorded ElevenLabs voice plays in the game; say or mouth the line with it so your head
and hands move with the words: the shot lists give each take's length in seconds).

You don't have to film everything. The game uses a take as soon as it's there and keeps the current animation for
everything else, so a half-finished set already looks better and nothing breaks.

## How to film it (one page)

1. **Landscape.** Turn the phone sideways.
2. **Your whole body in the frame**, head to feet, with a little room above your head and below your shoes,
   for the whole take. If you walk, the whole walk has to stay in frame. Stand 3 to 4 m from the phone.
3. **A steady phone.** Use a tripod, a shelf or a stack of books, at the height the shot says (usually 1 to 1.5 m).
   Don't hand-hold it and don't zoom. The game moves the camera itself.
4. **Plain, fitted clothes** that aren't the same colour as the wall: jeans and a plain jumper are perfect. No long
   coats, skirts or loose hoods, because the app has to see your knees and elbows. Hats are fine. Shoes on.
5. **Good, even light.** Daylight or a bright room with the light behind the phone, not behind you. No dark corners.
6. **One take per shot, one person per take.** Each video is one shot for one character. If two characters interact
   (Deacon reaching for a hand), both of you act together but film twice, once with each person as the one being
   filmed, or use two phones at once. One person can play every character, one take after another.
7. **Start every take the same way:** stand (or sit) in the start pose on your mark, **clap once** in front of your
   chest, put your hands back in the start pose, count "one" in your head, then act. The game starts the shot 1 second
   after the clap. Stop recording 2 seconds after the action ends.
8. **Tape marks** on the floor: an **X** where you start, an arrow for the way you face, and a line where a walk ends.
   Distances in this guide are in metres, so measure them; a walk that's too long or too short shows.
9. **Face the way the shot says.** Your facing at the start becomes the character's facing in the game. Most shots
   start facing the phone, because the apps track a body best from the front.
10. **Stand-in props:** a broom handle for a rifle, chairs for seats, a plate for an aircraft yoke. Hold them the
    way the shot says. (The game hides the character's gun while a take plays, because a mimed gun can't line up with
    a real one, so mime it naturally.)
11. **Takes are quick to redo.** Do two or three and keep the best one.

### Then run it through an app, and drop the file in

1. Upload the video to one of the apps below and download the result as **FBX** (or BVH).
2. Name it `<shot>_<role>.fbx` and put it in `assets/user_supplied/mocap/<scene>/`, for example
   `assets/user_supplied/mocap/gravelight_one/shot_04_seat1.fbx` or `assets/user_supplied/mocap/cancel_ending/last_wren.fbx`.
   The scene, shot and role names are the ones in the tables below. `<shot>_any.fbx` stands in for every role in that
   shot that has no take of its own.
3. Run `sh tools/mocap.sh report` to see what's there and what's still missing, then `sh tools/mocap.sh build`.
   It fits the take to our skeleton, plants the feet so they don't slide, smooths out the shake, cuts the take to the
   shot (from 1 s after your clap) and writes the game's animation file. That folder is git-ignored, because your
   videos and captures stay private. The built animations go to `assets/ours/mocap/` and are committed.
4. If a take starts in the wrong place, put a file next to it with the same name and `.json`, for example
   `shot_04_seat1.json` with `{"start": 2.4}` (seconds into the take where the shot begins). `"cutoff": 4` smooths
   it more (the default is 6), and `"lock": false` turns the foot planting off.

## The apps (checked on the web on 2026-11-08)

All three turn a phone video into skeleton animation in the browser. Free tiers change often, so check the pricing
page before you sign up. What I found on 2026-11-08:

| App | Free tier | Export on the free tier | Commercial use on the free tier |
|---|---|---|---|
| **Rokoko Vision** (rokoko.com, through Rokoko Studio) | "Starter", free forever: **30 s of Vision AI video processing per month**; single camera (dual camera is a paid feature) | **FBX** (BVH is on the paid plans) | The pricing page says exports can be used in any of your projects, commercial ones included |
| **DeepMotion Animate 3D** (deepmotion.com) | "Freemium": **60 s of animation per month** (1 credit = 1 s), no card, never expires; hand and face tracking cost an extra 0.5 credit per second | **FBX, BVH, MP4** (GLB only with a custom character) | **No.** Freemium is "personal, non-commercial use"; a commercial licence needs a paid plan |
| **QuickMagic** (quickmagic.ai) | **50 V-coins**, **30 s max per video**, lowest queue priority, 15-day storage | **FBX only** | **No.** The pricing table lists the Commercial License as "Not included" on Free |

What that means here: the whole list below is **775 s (about 13 minutes) of motion** (the total at the end; the high-priority takes alone are about 9 minutes). No free tier
covers it in one month, and two of the three don't allow a game you sell. My pick:

- **For a test, today:** Rokoko Vision's free 30 s is enough for one or two shots (for example GRAVELIGHT ONE
  `shot_04_seat1` and `shot_06`), with commercial use allowed.
- **For the real set:** one paid month of whichever app you liked best in the test (Rokoko's paid plan also adds
  BVH and dual camera; DeepMotion's paid plans add commercial use and more seconds). Batch all the videos into that
  month. The owner decides this (it's in `morning/NEEDS_DEVIN.md`).
- Free and offline: **FreeMoCap** (open source, AGPL) runs on your own PC and exports BVH, but it needs two or more
  cameras that see you at once (two phones). I didn't test it here.

The pipeline doesn't care which app made a file: it reads Mixamo, Rokoko, DeepMotion (`*_JNT`), QuickMagic and plain
BVH bone names (`tools/mocap/mocaplib.py map_bones`). If a file comes back with "cannot map bones", the report names
the bones it couldn't find. Send the file with the error and the name list gets one more alias.

## What the game does with a take (for the curious)

- `tools/mocap/blender_extract.py` (Blender headless) opens an FBX. BVH is read directly in Python.
- `tools/mocap/mocaplib.py` does the fitting:
  - **retarget:** each of our bones takes the matching source bone's turn away from its own rest pose, after
    lining the rest poses up (the apps' T-pose against our arms-down pose);
  - **resample:** to 30 fps;
  - **trim:** 1 s after the clap, for the shot's length;
  - **smooth:** a gentle zero-phase Butterworth filter, 6 Hz on the rotations;
  - **ground:** the feet go on the floor;
  - **foot lock:** a foot that is low and nearly still is pinned where it landed and the leg is bent to reach it,
    easing in and out over 4 frames.
- `tools/mocap/mocap_import.gd` (Godot headless) saves one `AnimationLibrary` per cutscene, with one animation per take.
- In a cutscene, `MocapStage` (called by the cinema director on every shot) looks for each stand-in's take, in this
  order: its character, then its seat or slot, then `any`. If it finds one, a `MocapModifier` plays it on the
  stand-in's skeleton on the cutscene's clock. If not, the stand-in keeps the current animation.
- **Lip sync:** `sh tools/mocap.sh lipsync` runs Rhubarb Lip Sync on every cutscene line's ElevenLabs take, writing
  `data/gravelight/vo/lipsync/<LINE>.json`. The faces' mouths follow those shapes; a line without them keeps the old
  flap.

<!-- mocap:begin -->
<!-- generated by tools/mocap.sh guide from data/gravelight/mocap/shots.json; edit that file, not this block -->

### GRAVELIGHT ONE: the crash (Map 0, before the inn opening)

Scene id `gravelight_one` (cutscenes_lazarus.json). **Set-up:** Four chairs 45 cm high in a row, 1.05 m apart, all facing the phone (the C-47's port-wall bucket seats; seat 1 is the window seat, on your left as you sit). For the cockpit: two chairs side by side 0.9 m apart, a broom handle held upright between your knees as the control column, a dinner plate held flat as the yoke.

#### `shot_02` · 10.0 s · seat1, seat2, seat3, seat4

- **Phone:** 3.5 m in front of the chair, phone at seated chest height (0.9 m).
- **Marks:** The chair on the X. Feet flat, a bag between your boots.
- **C-47 passenger, window seat (whoever plays first)** (`shot_02_seat1.fbx`): Sit strapped in, hands on your knees, look across the cabin (at the phone). Shift once as the plane rattles at 2.5 s.
- **C-47 passenger, second seat** (`shot_02_seat2.fbx`): Sit, arms folded, look at the floor, then up at the roof as the pilot talks (1 s).
- **C-47 passenger, third seat** (`shot_02_seat3.fbx`): Sit, hands clasped between your knees; tap one boot slowly.
- **C-47 passenger, fourth seat (the sleeper)** (`shot_02_seat4.fbx`): Asleep, or pretending: head down on your chest, arms folded. Don't move except breathing.
- **Props:** A bag or backpack between your feet.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 1.0 s, selwyn (intercom, off screen), `SEL_GL1_01` (8.5 s): "[intercom] Pilot to passengers. We've crossed the Silesian border, twenty-three ten. Forty minutes to the drop. Stay strapped in, there's weather."

#### `shot_03` · 9.0 s · seat1

- **Phone:** 2.5 m behind your right shoulder, 1.2 m high (the camera looks past you at the window).
- **Marks:** The chair on the X. The window is to your left and a little behind you: a sheet of paper taped to the wall 1.3 m up.
- **C-47 passenger, window seat (whoever plays first)** (`shot_03_seat1.fbx`): At 0.5 s turn in the seat to your left, lean toward the window, and look down through it at the ground far below. Stay turned and leaning; at 1.5 s and 5 s something flashes below: lean a little closer.
- **Props:** Paper on the wall as the window.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.5 s, selwyn (intercom, off screen), `SEL_GL1_02` (7.7 s): "[intercom] Navigator says that's the front below us. Those are their flares, not ours. Have a look if you like. Then don't."

#### `shot_04` · 8.0 s · seat1

- **Phone:** 1.5 m from the window paper, 1.4 m high, looking back at your face past the window.
- **Marks:** As shot 3: turned to the window, leaning.
- **C-47 passenger, window seat (whoever plays first)** (`shot_04_seat1.fbx`): Still at the window. At 0.6 s say your GL1_01 line, shouting over the engines, pointing down through the window once. At 0.8 s a flare lights the cabin white: squint. Stay leaning in.
- **Props:** Paper on the wall as the window.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.6 s, seat1 (the window seat: DUT, PEG, DEA or WRN), `DUT_GL1_01` (5.7 s): "[shouting over engines] That ain't a parade down there. Those are people. Hundreds of them. Where the hell are they going?"
  - at 0.6 s, seat1 (the window seat: DUT, PEG, DEA or WRN), `PEG_GL1_01` (8.6 s): "[shouting over engines] Soviet greatcoats. Walking west, no formation, no weapons. Pilot, those men are walking through their own artillery."
  - at 0.6 s, seat1 (the window seat: DUT, PEG, DEA or WRN), `DEA_GL1_01` (6.1 s): "[whispers] Yea, though I walk through the valley... Lord, they are walking. Look at them walk."
  - at 0.6 s, seat1 (the window seat: DUT, PEG, DEA or WRN), `WRN_GL1_01` (7.2 s): "[shouting over engines] Russians. Hundreds. Walking into German guns and the guns are not firing. ...Nothing about this is right."
  - at 4.0 s, selwyn (intercom), `SEL_GL1_03` (8.2 s): "[intercom] Someone with glasses tell me what those columns are. On the snow. Walking west. Nobody down there is shooting at them."

#### `shot_05` · 8.0 s · selwyn, copilot

- **Phone:** 2 m behind the two cockpit chairs, 1.6 m high, looking over your shoulders.
- **Marks:** Selwyn the left chair, the co-pilot the right, 0.9 m apart.
- **Flt Lt Harry Selwyn (the pilot)** (`shot_05_selwyn.fbx`): Fly: both hands on the yoke (the plate), small corrections. At 4.0 s lift your right hand to your throat (the intercom) and say the line, looking ahead and a little right.
- **the co-pilot (never close)** (`shot_05_copilot.fbx`): Hands on your yoke; at 4 s turn your head to look where Selwyn looks (ahead right), then back.
- **Props:** A broom handle and a plate each.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 4.0 s, selwyn, `SEL_GL1_04` (5.0 s): "[intercom] Light ahead, bearing oh-four-oh. Violet. That's no flare."

#### `shot_06` · 7.0 s · seat1, seat2, seat3, seat4

- **Phone:** 2.5 m in front of the chairs, 1.3 m high.
- **Marks:** Chairs on their X's as shot 2.
- **C-47 passenger, window seat (whoever plays first)** (`shot_06_seat1.fbx`): A violet light comes in across the cabin: turn your face toward it (the phone). At 2 s check your wristwatch, tap it, hold it to your ear.
- **C-47 passenger, second seat** (`shot_06_seat2.fbx`): At 0.8 s say your GL1_02 line to the person on your right (seat 3), turning to them; on 'hand' or 'count' reach toward them.
- **C-47 passenger, third seat** (`shot_06_seat3.fbx`): Look at the violet light; at 1.5 s take seat 2's hand or grip the chair frame with both hands.
- **C-47 passenger, fourth seat (the sleeper)** (`shot_06_seat4.fbx`): Wake up: lift your head at 0.5 s, look at the light, grip the chair.
- **Props:** A wristwatch (seat 1).
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.8 s, seat2 (DUT, PEG, DEA or WRN), `DUT_GL1_02` (2.8 s): "Hang on. Hang on, hang on—"
  - at 0.8 s, seat2 (DUT, PEG, DEA or WRN), `PEG_GL1_02` (3.4 s): "Nobody breathe. Heads down, hands on the frame."
  - at 0.8 s, seat2 (DUT, PEG, DEA or WRN), `DEA_GL1_02` (3.0 s): "Hold my hand, if you want to. I don't mind."
  - at 0.8 s, seat2 (DUT, PEG, DEA or WRN), `WRN_GL1_02` (5.7 s): "Count with me. Jeden, dwa, trzy... it helps. Cztery..."

#### `shot_07` · 8.0 s · selwyn, copilot

- **Phone:** 1.5 m to Selwyn's left, 1.3 m high, close on the hands and the panel.
- **Marks:** Cockpit chairs as shot 5.
- **Flt Lt Harry Selwyn (the pilot)** (`shot_07_selwyn.fbx`): The engines die. Say the line from 0.4 s while your hands work: pull both throttles back (left hand to a box at knee height), flick three switches over your head, then both hands back on the yoke, holding it against a pull. A jolt at 1.5 s.
- **the co-pilot (never close)** (`shot_07_copilot.fbx`): Grab the yoke too at 1.5 s (the jolt), brace, look at Selwyn.
- **Props:** Broom handle, plate, a shoebox at knee height as the throttles.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.4 s, selwyn, `SEL_GL1_05` (7.0 s): "[intercom] Both engines— ...Both engines gone. Instruments dead. Hold on to something, chaps. I'm going to put her down."

#### `shot_09` · 5.2 s · seat1, seat2, seat3, seat4

- **Phone:** On the floor 2 m in front of the chairs, looking up.
- **Marks:** Chairs on their X's.
- **C-47 passenger, window seat (whoever plays first)** (`shot_09_seat1.fbx`): Brace: head down to your knees, hands gripping the chair edge. At 3.8 s and 4.4 s you are thrown forward and back (two big jolts), at 5.0 s a smaller one.
- **C-47 passenger, second seat** (`shot_09_seat2.fbx`): Brace, arms over your head. Same jolts at 3.8, 4.4, 5.0 s.
- **C-47 passenger, third seat** (`shot_09_seat3.fbx`): Brace, one hand on the chair frame, one over your head. Same jolts.
- **C-47 passenger, fourth seat (the sleeper)** (`shot_09_seat4.fbx`): Brace, hands on the back of your neck. Same jolts.
- **Props:** None. Don't actually fall; the jolts are a rock in the seat.
- **Lines:** none.

### Leaving the Crossroads Inn for Kaltenbrunn (Map 0's exit)

Scene id `exfil_m0_m1` (campaign.json). **Set-up:** Open floor or a yard. One person per take (the game puts each character in their place in the group).

#### `shot_01` · 6.2 s · dutch, peg, deacon, wren

- **Phone:** 3 m behind you, 1.4 m high (the camera looks over your shoulders at the barn doors).
- **Marks:** Stand on the X facing away from the phone (the great doors are ahead of you).
- **Dutch (squad)** (`shot_01_dutch.fbx`): Stand ready, weapon low (a broom as the rifle). At about 2 s the barred doors in front of you fall outward: flinch, step half a pace back, then lift your head and look out at the snow.
- **Peg (squad)** (`shot_01_peg.fbx`): Stand ready, weapon low (a broom as the rifle). At about 2 s the barred doors in front of you fall outward: flinch, step half a pace back, then lift your head and look out at the snow.
- **Deacon (squad)** (`shot_01_deacon.fbx`): Stand ready, weapon low (a broom as the rifle). At about 2 s the barred doors in front of you fall outward: flinch, step half a pace back, then lift your head and look out at the snow.
- **Wren (squad)** (`shot_01_wren.fbx`): Stand ready, weapon low (a broom as the rifle). At about 2 s the barred doors in front of you fall outward: flinch, step half a pace back, then lift your head and look out at the snow.
  (One take `shot_01_any.fbx` can stand in for every role without its own.)
- **Props:** A broom or stick as the gun.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.8 s, the Operator (radio), `OPR_EXFIL_GO_M0_01` (7.9 s): "[the crackle clearing, a voice finding itself] ...there you are. Dawn on the Kreuzweg. Follow the signpost. Kaltenbrunn is... expecting you."

#### `shot_02` · 5.0 s · dutch, peg, deacon, wren

- **Phone:** Low (0.5 m) in front of you, 6.5 m away from the start X; walk toward it.
- **Marks:** Start X; a second tape 4.2 m straight ahead (toward the phone). Face the phone.
- **Dutch (squad)** (`shot_02_dutch.fbx`): Walk out over the fallen doors toward the phone, slowly (4.2 m in 4 s: a careful step, looking down at the planks for the first two steps, then up and ahead). Stop at the second tape.
- **Peg (squad)** (`shot_02_peg.fbx`): Walk out over the fallen doors toward the phone, slowly (4.2 m in 4 s: a careful step, looking down at the planks for the first two steps, then up and ahead). Stop at the second tape.
- **Deacon (squad)** (`shot_02_deacon.fbx`): Walk out over the fallen doors toward the phone, slowly (4.2 m in 4 s: a careful step, looking down at the planks for the first two steps, then up and ahead). Stop at the second tape.
- **Wren (squad)** (`shot_02_wren.fbx`): Walk out over the fallen doors toward the phone, slowly (4.2 m in 4 s: a careful step, looking down at the planks for the first two steps, then up and ahead). Stop at the second tape.
  (One take `shot_02_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun, a few planks or a rug on the floor for the first two steps.
- **Lines:** none.

#### `shot_03` · 8.8 s · dutch, peg, deacon, wren *(optional: small in frame)*

- **Phone:** 5 m to the side of your path, 1.2 m high; you walk across in front of it.
- **Marks:** A start X and an end tape 7 m along a line across the phone's view. Face the end tape.
- **Walking:** the game moves the character along its own path; just walk naturally at the pace given.
- **Dutch (squad)** (`shot_03_dutch.fbx`): Walk the line at an easy pace (7 m in about 6.5 s), looking around at the crossroads as the sun comes up.
- **Peg (squad)** (`shot_03_peg.fbx`): Walk the line at an easy pace (7 m in about 6.5 s), looking around at the crossroads as the sun comes up.
- **Deacon (squad)** (`shot_03_deacon.fbx`): Walk the line at an easy pace (7 m in about 6.5 s), looking around at the crossroads as the sun comes up.
- **Wren (squad)** (`shot_03_wren.fbx`): Walk the line at an easy pace (7 m in about 6.5 s), looking around at the crossroads as the sun comes up.
  (One take `shot_03_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.2 s, Fasbender (radio), `FAS_EXFIL_M0_01` (10.3 s): "[radio, hurried] Fasbender. If you are leaving the inn: the salt road, east, nine kilometres. Whatever you hear at Kaltenbrunn... do not let the bell ring."

#### `shot_04` · 10.0 s · dutch, peg, deacon, wren *(optional: small in frame)*

- **Phone:** 5 m to the side of your path, 1.2 m high.
- **Marks:** As shot 3: walk across the phone's view.
- **Walking:** the game moves the character along its own path; just walk naturally at the pace given.
- **Dutch (squad)** (`shot_04_dutch.fbx`): Walk a little faster (1.3 m/s, a steady march), head down against the cold.
- **Peg (squad)** (`shot_04_peg.fbx`): Walk a little faster (1.3 m/s, a steady march), head down against the cold.
- **Deacon (squad)** (`shot_04_deacon.fbx`): Walk a little faster (1.3 m/s, a steady march), head down against the cold.
- **Wren (squad)** (`shot_04_wren.fbx`): Walk a little faster (1.3 m/s, a steady march), head down against the cold.
  (One take `shot_04_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 1.3 s, the Operator (radio), `OPR_EXFIL_ROAD_M0_01` (8.5 s): "Bring everything you carry. Every gun, every coin. The books come with you. The books always come with you."

### Leaving Kaltenbrunn for Totenhafen (the campaign's Kaltenbrunn ending)

Scene id `exfil_m1_m2` (campaign.json). **Set-up:** Open floor or a yard. One person per take.

#### `shot_01` · 6.0 s · dutch, peg, deacon, wren

- **Phone:** 3 m in front of you, 1.5 m high (a lantern hangs between you and the phone).
- **Marks:** Stand on the X facing the phone (the north wall and its beacon are where the phone is).
- **Dutch (squad)** (`shot_01_dutch.fbx`): Tired, standing at the beacon. Look up at the gate as its winch grinds (a slow lift of the head), shoulder the gun at 3 s, glance at the person next to you.
- **Peg (squad)** (`shot_01_peg.fbx`): Tired, standing at the beacon. Look up at the gate as its winch grinds (a slow lift of the head), shoulder the gun at 3 s, glance at the person next to you.
- **Deacon (squad)** (`shot_01_deacon.fbx`): Tired, standing at the beacon. Look up at the gate as its winch grinds (a slow lift of the head), shoulder the gun at 3 s, glance at the person next to you.
- **Wren (squad)** (`shot_01_wren.fbx`): Tired, standing at the beacon. Look up at the gate as its winch grinds (a slow lift of the head), shoulder the gun at 3 s, glance at the person next to you.
  (One take `shot_01_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.6 s, the Operator (radio), `OPR_EXFIL_GO_01` (9.2 s): "Your Friend at the Ledger, signing off from Sender Kaltenbrunn... [a beat] ...no. Not signing off. Transferring. North, to the sea."

#### `shot_02` · 5.5 s · dutch, peg, deacon, wren

- **Phone:** Low (0.5 m), 8 m from the start X; you walk toward it.
- **Marks:** Start X; a second tape 6 m ahead toward the phone. Face the phone.
- **Dutch (squad)** (`shot_02_dutch.fbx`): Walk out through the gate toward the phone at 1.2 m/s (6 m in 5 s), tired, looking past the phone at the dawn. Stop at the tape.
- **Peg (squad)** (`shot_02_peg.fbx`): Walk out through the gate toward the phone at 1.2 m/s (6 m in 5 s), tired, looking past the phone at the dawn. Stop at the tape.
- **Deacon (squad)** (`shot_02_deacon.fbx`): Walk out through the gate toward the phone at 1.2 m/s (6 m in 5 s), tired, looking past the phone at the dawn. Stop at the tape.
- **Wren (squad)** (`shot_02_wren.fbx`): Walk out through the gate toward the phone at 1.2 m/s (6 m in 5 s), tired, looking past the phone at the dawn. Stop at the tape.
  (One take `shot_02_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun.
- **Lines:** none.

#### `shot_03` · 7.5 s · dutch, peg, deacon, wren *(optional: small in frame)*

- **Phone:** 4 m to the side of your path, 1.3 m high.
- **Marks:** Walk across the phone's view along a 9 m line.
- **Walking:** the game moves the character along its own path; just walk naturally at the pace given.
- **Dutch (squad)** (`shot_03_dutch.fbx`): Walk on at 1.2 m/s. Halfway, look back over your shoulder at the mine for a second.
- **Peg (squad)** (`shot_03_peg.fbx`): Walk on at 1.2 m/s. Halfway, look back over your shoulder at the mine for a second.
- **Deacon (squad)** (`shot_03_deacon.fbx`): Walk on at 1.2 m/s. Halfway, look back over your shoulder at the mine for a second.
- **Wren (squad)** (`shot_03_wren.fbx`): Walk on at 1.2 m/s. Halfway, look back over your shoulder at the mine for a second.
  (One take `shot_03_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun.
- **Lines:** none.

#### `shot_04` · 11.0 s · dutch, peg, deacon, wren *(optional: small in frame)*

- **Phone:** 6 m to the side, 2 m high (on a chair).
- **Marks:** Walk across the phone's view.
- **Walking:** the game moves the character along its own path; just walk naturally at the pace given.
- **Dutch (squad)** (`shot_04_dutch.fbx`): Keep walking, 1.2 m/s, eyes on the road.
- **Peg (squad)** (`shot_04_peg.fbx`): Keep walking, 1.2 m/s, eyes on the road.
- **Deacon (squad)** (`shot_04_deacon.fbx`): Keep walking, 1.2 m/s, eyes on the road.
- **Wren (squad)** (`shot_04_wren.fbx`): Keep walking, 1.2 m/s, eyes on the road.
  (One take `shot_04_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.4 s, the Operator (radio), `OPR_EXFIL_ROAD_01` (11.8 s): "Totenhafen. A harbour of sealed cargo and patient tides. Keep your accounts in order. I'll be there before you are. I'm always there before you are."

### Requiem for Kaltenbrunn: the egg's ending (Kaltenbrunn, the Heart's pit)

Scene id `requiem_ending` (gravelight/world/requiem_ending.gd). **Set-up:** Open floor. The Heart hangs above and in front of you, about 7 m up: put a chair or a lamp 3 m in front of you as the eyeline and look up past it.

#### `heart` · 6.0 s · dutch, peg, deacon, wren *(optional: small in frame)*

- **Phone:** 4 m in front of you, low (0.4 m), looking up.
- **Marks:** Stand on the X facing the phone (the Heart is above the phone).
- **Dutch (squad)** (`heart_dutch.fbx`): Look up at the Heart, slow, almost reverent; lower your gun. A rumble at the start: steady yourself.
- **Peg (squad)** (`heart_peg.fbx`): Look up at the Heart, slow, almost reverent; lower your gun. A rumble at the start: steady yourself.
- **Deacon (squad)** (`heart_deacon.fbx`): Look up at the Heart, slow, almost reverent; lower your gun. A rumble at the start: steady yourself.
- **Wren (squad)** (`heart_wren.fbx`): Look up at the Heart, slow, almost reverent; lower your gun. A rumble at the start: steady yourself.
  (One take `heart_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.0 s, Liesl (a whisper), `LSL_REC_HIDE_01` (3.2 s): "[whisper] ...ninety-eight... ninety-nine..."

#### `faces` · 3.5 s · dutch, peg, deacon, wren

- **Phone:** 1.5 m in front of your face, 1.5 m high (a close-up).
- **Marks:** Stand on the X facing the phone.
- **Dutch (squad)** (`faces_dutch.fbx`): The Heart has just collapsed: the lights go out one by one around you. Flinch at the flash, then turn your head slowly, following the lights going out from your right to your left.
- **Peg (squad)** (`faces_peg.fbx`): The Heart has just collapsed: the lights go out one by one around you. Flinch at the flash, then turn your head slowly, following the lights going out from your right to your left.
- **Deacon (squad)** (`faces_deacon.fbx`): The Heart has just collapsed: the lights go out one by one around you. Flinch at the flash, then turn your head slowly, following the lights going out from your right to your left.
- **Wren (squad)** (`faces_wren.fbx`): The Heart has just collapsed: the lights go out one by one around you. Flinch at the flash, then turn your head slowly, following the lights going out from your right to your left.
  (One take `faces_any.fbx` can stand in for every role without its own.)
- **Props:** None.
- **Lines:** none.

#### `montage` · 8.0 s · dutch, peg, deacon, wren

- **Phone:** 3.5 m from you, chest high; the camera circles, but you film it with the phone still.
- **Marks:** Stand on the X facing the phone.
- **Dutch (squad)** (`montage_dutch.fbx`): Around you the dead fall where they stand. Lower your gun. Look at the bodies on the floor around you, one, then another. Breathe out. One of you (Deacon) takes off his cap at 5 s; the others just stand.
- **Peg (squad)** (`montage_peg.fbx`): Around you the dead fall where they stand. Lower your gun. Look at the bodies on the floor around you, one, then another. Breathe out. One of you (Deacon) takes off his cap at 5 s; the others just stand.
- **Deacon (squad)** (`montage_deacon.fbx`): Around you the dead fall where they stand. Lower your gun. Look at the bodies on the floor around you, one, then another. Breathe out. One of you (Deacon) takes off his cap at 5 s; the others just stand.
- **Wren (squad)** (`montage_wren.fbx`): Around you the dead fall where they stand. Lower your gun. Look at the bodies on the floor around you, one, then another. Breathe out. One of you (Deacon) takes off his cap at 5 s; the others just stand.
  (One take `montage_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun; a cap (Deacon).
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.0 s, the Operator (a dragging tape), `OPR_QUEST_S9_END_01` (4.1 s): "[voice slowing, tape dragging] Thank... you... for... listening..."

#### `peg` · 6.0 s · dutch, peg, deacon, wren

- **Phone:** 3 m in front of you, then the camera rises (film it still, 1.5 m high).
- **Marks:** Stand on the X facing the phone.
- **Dutch (squad)** (`peg_dutch.fbx`): Still standing at the pit. Reinholt's voice on the radio: Peg touches her ear (the radio), the others turn their heads toward her and listen. On Fasbender's line (from 5.5 s) everyone looks up and away to the north.
- **Peg (squad)** (`peg_peg.fbx`): Still standing at the pit. Reinholt's voice on the radio: Peg touches her ear (the radio), the others turn their heads toward her and listen. On Fasbender's line (from 5.5 s) everyone looks up and away to the north.
- **Deacon (squad)** (`peg_deacon.fbx`): Still standing at the pit. Reinholt's voice on the radio: Peg touches her ear (the radio), the others turn their heads toward her and listen. On Fasbender's line (from 5.5 s) everyone looks up and away to the north.
- **Wren (squad)** (`peg_wren.fbx`): Still standing at the pit. Reinholt's voice on the radio: Peg touches her ear (the radio), the others turn their heads toward her and listen. On Fasbender's line (from 5.5 s) everyone looks up and away to the north.
  (One take `peg_any.fbx` can stand in for every role without its own.)
- **Props:** The broom as the gun.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.0 s, Reinholt (radio), `REI_END_02` (5.5 s): "Emil. You'll follow me. You always do. North, to the sea."
  - at 0.0 s, Fasbender (radio, after Reinholt), `FAS_M1_ENDING_01` (15.2 s): "...Gravelight? It's done. I... I am at the rail siding. She took the train. She has a fragment. Of course she does. Of course she— [deep breath] ...I'll meet you at the siding. Bring the samples. [pause] I mean, bring yourselves."

### Leaving Totenhafen for Fernflug (Werk Thalbach)

Scene id `exfil_m2_m4` (campaign.json). **Set-up:** Open floor. A board or a door at chest height 0.6 m in front of you (the transfer board).

#### `shot_01` · 7.0 s · dutch, peg, deacon, wren

- **Phone:** 2 m behind the board, 1.4 m high, looking at you over it.
- **Marks:** Stand on the X facing the phone, the board between you.
- **Dutch (squad)** (`shot_01_dutch.fbx`): Read the transfer board under a lamp: lean in, follow a line with your finger, then straighten and look at the others (left, right).
- **Peg (squad)** (`shot_01_peg.fbx`): Read the transfer board under a lamp: lean in, follow a line with your finger, then straighten and look at the others (left, right).
- **Deacon (squad)** (`shot_01_deacon.fbx`): Read the transfer board under a lamp: lean in, follow a line with your finger, then straighten and look at the others (left, right).
- **Wren (squad)** (`shot_01_wren.fbx`): Read the transfer board under a lamp: lean in, follow a line with your finger, then straighten and look at the others (left, right).
  (One take `shot_01_any.fbx` can stand in for every role without its own.)
- **Props:** A board or a sheet of paper on a box at chest height.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.8 s, the Operator (radio), `OPR_EXFIL_GO_M2_01` (5.6 s): "Werk Thalbach. An aircraft works. We think you'll find it familiar."

### Fernflug Act I to II: boarding der Kranich

Scene id `exfil_m4a_m4b` (campaign.json). **Set-up:** Open floor. The wing's belly and the ramp are ahead of you.

#### `shot_01` · 7.0 s · dutch, peg, deacon, wren, jakub

- **Phone:** 3 m behind you, low (0.5 m), looking up past you.
- **Marks:** Stand on the X facing away from the phone (the ramp is ahead).
- **Dutch (squad)** (`shot_01_dutch.fbx`): At the foot of the ramp: look up at the huge wing over you (a slow tilt of the head), hitch your pack higher on your shoulders, then take the first step toward the ramp at 5 s.
- **Peg (squad)** (`shot_01_peg.fbx`): At the foot of the ramp: look up at the huge wing over you (a slow tilt of the head), hitch your pack higher on your shoulders, then take the first step toward the ramp at 5 s.
- **Deacon (squad)** (`shot_01_deacon.fbx`): At the foot of the ramp: look up at the huge wing over you (a slow tilt of the head), hitch your pack higher on your shoulders, then take the first step toward the ramp at 5 s.
- **Wren (squad)** (`shot_01_wren.fbx`): At the foot of the ramp: look up at the huge wing over you (a slow tilt of the head), hitch your pack higher on your shoulders, then take the first step toward the ramp at 5 s.
- **Jakub (Fernflug companion)** (`shot_01_jakub.fbx`): At the foot of the ramp: look up at the huge wing over you (a slow tilt of the head), hitch your pack higher on your shoulders, then take the first step toward the ramp at 5 s.
  (One take `shot_01_any.fbx` can stand in for every role without its own.)
- **Props:** A backpack, the broom as the gun.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 1.0 s, the Operator (tannoy), `OPR_EXFIL_GO_M4A_01` (4.0 s): "Boarding is now complete. Please take any seat."

### Fernflug Act II to III: der Kranich comes down at Groom Lake

Scene id `exfil_m4b_m4c` (campaign.json). **Set-up:** Open floor. Everyone stands; the floor is shaking (you sway it).

#### `shot_01` · 7.0 s · dutch, peg, deacon, wren, jakub

- **Phone:** 3 m in front of you, 1.4 m high.
- **Marks:** Stand on the X facing the phone, feet apart.
- **Dutch (squad)** (`shot_01_dutch.fbx`): Braced, one hand up on an overhead strap (a broom held high), swaying with the airframe; look ahead at Deacon.
- **Peg (squad)** (`shot_01_peg.fbx`): Braced, one hand up on an overhead strap (a broom held high), swaying with the airframe; look ahead at Deacon.
- **Deacon (squad)** (`shot_01_deacon.fbx`): At the controls: both hands forward at chest height on an imaginary yoke, pulling gently; say the line at 0.7 s, softly, to the aircraft.
- **Wren (squad)** (`shot_01_wren.fbx`): Braced, one hand up on an overhead strap (a broom held high), swaying with the airframe; look ahead at Deacon.
- **Jakub (Fernflug companion)** (`shot_01_jakub.fbx`): Braced, one hand up on an overhead strap (a broom held high), swaying with the airframe; look ahead at Deacon.
  (One take `shot_01_any.fbx` can stand in for every role without its own.)
- **Props:** A broom held overhead as the strap.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.7 s, deacon, `DEA_M4B_AUTOPILOT_02` (3.9 s): "Easy. Easy, girl. You don't have to go where they pointed you."

#### `shot_03` · 5.2 s · peg, dutch, wren, jakub

- **Phone:** 2.5 m in front of you, 1.4 m high.
- **Marks:** Stand on the X facing the phone.
- **Peg (squad)** (`shot_03_peg.fbx`): Braced against the cabin wall (to your left), one hand flat on it, the other on the strap; at 0.9 s say the line to the others, almost cheerful.
- **Dutch (squad)** (`shot_03_dutch.fbx`): Braced, both hands on the strap, knees bent, looking down (the ground is coming).
- **Wren (squad)** (`shot_03_wren.fbx`): Braced, both hands on the strap, knees bent, looking down (the ground is coming).
- **Jakub (Fernflug companion)** (`shot_03_jakub.fbx`): Braced, both hands on the strap, knees bent, looking down (the ground is coming).
  (One take `shot_03_any.fbx` can stand in for every role without its own.)
- **Props:** A broom held overhead.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.9 s, peg, `PEG_M4B_CRASH_01` (1.9 s): "Hold on to something British."

### KUENDIGUNG: the canon ending (Fernflug Act IV)

Scene id `cancel_ending` (gravelight/world/endings/cancel_ending.gd). **Set-up:** A table at waist height with a key in a lock (a box with a door key in it) 0.5 m in front of you for the key shot; open floor for the yard shots.

#### `key` · 10.0 s · dutch, peg, deacon, wren, jakub

- **Phone:** 1.8 m across the table from you, 1.5 m high.
- **Marks:** Stand on the X facing the table and the phone. Jakub stands on your left, half a step back.
- **Dutch (squad)** (`key_dutch.fbx`): You are the one who turns the key: put your hand on it, hold a breath, say your cancel line, and turn it at 2.2 s (a hard quarter turn). Then stand with your hand still on it, looking up at the others.
- **Peg (squad)** (`key_peg.fbx`): You are the one who turns the key: put your hand on it, hold a breath, say your cancel line, and turn it at 2.2 s (a hard quarter turn). Then stand with your hand still on it, looking up at the others.
- **Deacon (squad)** (`key_deacon.fbx`): You are the one who turns the key: put your hand on it, hold a breath, say your cancel line, and turn it at 2.2 s (a hard quarter turn). Then stand with your hand still on it, looking up at the others.
- **Wren (squad)** (`key_wren.fbx`): You are the one who turns the key: put your hand on it, hold a breath, say your cancel line, and turn it at 2.2 s (a hard quarter turn). Then stand with your hand still on it, looking up at the others.
- **Jakub (Fernflug companion)** (`key_jakub.fbx`): Stand at their side; at 2 s put your hand on the table beside theirs. At 4.0 s say 'Do it.' quietly, looking at them.
  (One take `key_any.fbx` can stand in for every role without its own.)
- **Props:** A box with a key.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.0 s, the key-turner (DUT, PEG, DEA, WRN), `DUT_M4D_CANCEL_01` (3.8 s): "Yeah. We're cancelling. ...That's it. That's the whole thing."
  - at 0.0 s, the key-turner (DUT, PEG, DEA, WRN), `PEG_M4D_CANCEL_01` (4.8 s): "On behalf of His Majesty's Government, and everyone else: we decline."
  - at 0.0 s, the key-turner (DUT, PEG, DEA, WRN), `DEA_M4D_CANCEL_01` (8.4 s): "Go on and rest now, all of you. [a breath] 'The last enemy that shall be destroyed is death.' ...We're done here."
  - at 0.0 s, the key-turner (DUT, PEG, DEA, WRN), `WRN_M4D_CANCEL_01` (5.0 s): "For Tomasz. For Agnieszka. For two hundred names. ...No."
  - at 4.0 s, jakub, `JAK_M4D_KEY_01` (0.8 s): "Do it."

#### `earth` · 10.0 s · dutch, peg, deacon, wren, jakub *(optional: small in frame)*

- **Phone:** 3 m behind you, low (0.6 m), looking up past you.
- **Marks:** Stand on the X facing away from the phone.
- **Dutch (squad)** (`earth_dutch.fbx`): Look up at the Earth in the sky, high in front of you. Don't move much: one of you puts a hand on the next one's shoulder.
- **Peg (squad)** (`earth_peg.fbx`): Look up at the Earth in the sky, high in front of you. Don't move much: one of you puts a hand on the next one's shoulder.
- **Deacon (squad)** (`earth_deacon.fbx`): Look up at the Earth in the sky, high in front of you. Don't move much: one of you puts a hand on the next one's shoulder.
- **Wren (squad)** (`earth_wren.fbx`): Look up at the Earth in the sky, high in front of you. Don't move much: one of you puts a hand on the next one's shoulder.
- **Jakub (Fernflug companion)** (`earth_jakub.fbx`): Look up at the Earth in the sky, high in front of you. Don't move much: one of you puts a hand on the next one's shoulder.
  (One take `earth_any.fbx` can stand in for every role without its own.)
- **Props:** None.
- **Lines:** none.

#### `last` · 12.0 s · dutch, peg, deacon, wren, jakub

- **Phone:** 4 m in front of you, low (0.6 m).
- **Marks:** Stand on the X facing the phone (the Earth is behind the phone, up).
- **Dutch (squad)** (`last_dutch.fbx`): At 5.0 s say the line to the others, turn your head to them, and nod toward home (over your right shoulder).
- **Peg (squad)** (`last_peg.fbx`): Stand together, look up at the Earth. On Dutch's line (5 s) turn your head to him.
- **Deacon (squad)** (`last_deacon.fbx`): Stand together, look up at the Earth. On Dutch's line (5 s) turn your head to him.
- **Wren (squad)** (`last_wren.fbx`): Count under your breath, then at 0 s say the line, looking up at the Earth; on 'and one' lower your eyes.
- **Jakub (Fernflug companion)** (`last_jakub.fbx`): Stand together, look up at the Earth. On Dutch's line (5 s) turn your head to him.
  (One take `last_any.fbx` can stand in for every role without its own.)
- **Props:** None.
- **Lines** (say them, or mouth them in time: the game plays the recorded voice):
  - at 0.0 s, wren, `WRN_M4D_END_01` (2.1 s): "Sixty-three. ...and one."
  - at 5.0 s, dutch, `DUT_M4D_LASTWORD_01` (2.4 s): "Come on. It's a long way home."

#### `credits` · 24.0 s · any *(optional: small in frame)*

- **Phone:** 5 m behind you, 1 m high.
- **Marks:** Stand on the X facing away from the phone.
- **any** (`credits_any.fbx`): Stand and look up at the Earth for the whole take. Breathe. Shift your weight once or twice.
- **Props:** None.
- **Lines:** none.

### Not filmed

- exfil_m0_m1, exfil_m1_m2 (the late wide shots): optional rows above: the squad is small in frame; the stand-in walk stays if you skip them.
- m2_letzte_fahrt_dive: camera on the U-boat and the sea; the squad is never directed into frame.
- exfil_m4c_m4d: the rocket launch: Dee and Jakub are seen in passing, not directed.
- london_window, renewal_ending: camera-only inserts (the window, the sky).
- lazarus_saturday, fourth_day, staub, epilogue_1953: the history scenes become archive reels (UPDATE 12 section 3).


## Total

**27 shots, 100 takes** (74 of them high priority), **775 s of captured motion** in all. Filming time: about **287 minutes** (4.8 hours) with the marks and phone set once per shot and about three tries per take, one performer at a time; two performers in parallel with two phones cut it nearly in half.
<!-- mocap:end -->
