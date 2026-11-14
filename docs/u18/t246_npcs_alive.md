# T-246: the NPCs feel more alive, and the two NPC body bugs

The owner, 2026-11-14, verbatim: "MAKE ALL THE NPCS FEEL MORE ALIVE, ALSO IVE ATTACHED SCREENSHOTS OF LITTLE BUGS."
Branch `claude/u18-npcs-alive`. Before / after renders: `docs/captures/u18_npcs/before` and `after` (WSL, invisible,
Compatibility renderer, a moonlit snow studio: `gravelight/tools_src/shots_npcs.tscn`).

**T-246, 2026-11-14: one shared life for every standing NPC, and Trudi's two screenshots fixed at the root.**

## The two screenshots (Map 0, the snow)

Both are **Trudi Hanke** as the map companion (RemoteBody drawn as her modelled person), not the extra people:
her pale blouse and white apron over a skirt to the ankle, standing in the snow at the stable (`companions.json`
spot) and, in the second, following the squad with a rifle.

1. **The woman with a black stick for a leg, floating, arms stiff** (`Screenshot 2026-11-14 133142.png`).
   - Her skirt (`cloth3`, sRGB 0.16) and her stockings (the shared `dark` key, 0.03) were near black. At night only
     the white apron read as "skirt", so it ended 30 cm above the snow; the dark skirt showing past the apron's edge
     read as one black leg and the dark hem and shoes as a black foot under a floating body.
   - She was in her idle fidget, `watch`, copied from Peg. Trudi wears no watch, and the fidget's wrist target
     (0.42 m up the puppet's chest, tuned for the old primitive bodies) lands at the face of a modelled person: her
     hand went to her eye. Her knife, held "low" for the one-handed fidget, hung flat in the middle of her chest
     (the dark rectangle).
2. **The pale long coat with a thin black bar across the chest** (`133153.png`): the same fidget with a rifle in her
   hands. The one-handed fidgets hold the gun "low", and a long gun held low stands as a dark bar across the apron.

**Fixes (the cause, for everyone, not just these two frames):**
- `people.json` Trudi: the skirt is a mid brown wool (0.44 / 0.35 / 0.28), the stockings a dark brown (`dark` 0.22 /
  0.18 / 0.17, also her buttons and soles), the bodice a little lighter, the apron a little less white. The GLB is
  unchanged (the colours are per part key at merge time).
- `RemoteBody`: the fidgets' hand targets have modelled-body heights (the watch wrist at chest height, the warming
  hands under the chin with the elbows down; 0.6 put Jakub's and Petersen's hands on top of their heads); a knife
  or pistol put away for a two-handed fidget goes to the right hip pointing down (it was slung across the back as if
  it were a rifle); Jakub's coal shovel hangs blade down with the handle over his shoulder (blade up it stood above
  his head like a placard). Trudi's fidget is now `warm`, and nobody but Peg checks a watch.
- Each fidget set is now a list (`RemoteBody.FIDGETS`): the companions, Jakub and the squad bots cycle through
  their own fidget plus `look` (a slow look round) and `hug` (arms folded / wrapped round in the cold), never the
  same twice running.

## "More alive": NpcLife

`gravelight/world/people/npc_life.gd` is one small node under a body; the body asks it each pose frame and blends
what it says over its own pose, only in the calm poses:

- **The head follows** the nearest human within 7.5 m, a zombie within 11 m (that wins: survivors cowering upstairs
  watch the dead), a gunshot within 12 m or an explosion for a moment, else a glance round now and then. A survivor
  who walks round behind an extra person makes the whole body turn (visual pivot only, at most ~110 degrees).
- **Idles** for the PatronBody people, one at a time with pauses: warming the hands (breathing into them), arms
  wrapped round, a hand to the hair or scarf, a look round. Outside in the cold the warm ones; indoors no hand
  warming. A **weight shift** from hip to hip every few seconds (the free knee eases), and **breathing**.
- **Reactions**: a shot or a blast near makes them start (a jolt back, the hands to the chest, a fearful face);
  a human aiming at them with the sights up makes a civilian put **hands up** (fear on the face); a human closer than
  1.2 m makes them take **half a step back** (visual, at most 28 cm).
- **Breath fog** in the cold (the map's `frost_edges` block, outside its warm zones; Kaltenbrunn's depths are not
  cold): a puff from the mouth every 2.6-4.2 s, more often when startled. Re-read when a body moves 3 m (the opening's
  patrons who flee into the snow start to breathe white).
- **Barks**: an extra person greets a survivor who walks up (within 3.5 m) with one of their own existing `talk`
  lines, once per approach and at most every 75 s. No new voice lines.

Who has it: the extra people on every map (`ExtraPerson`), the Map 0 patrons and the survivors upstairs, the bank
tellers (`PatronBody.enable_life`), and the companions and Jakub while they wait (`RemoteBody.set_life`, off once
they join: the brain has the body then).

## Rules kept

Presentation only: no collider, hitbox, prompt, interaction spot, timing or navmesh changed; the Talk / favour
interactables stay where they were (the visual step back and turn move only the body's pivot). Jakub's reactions are a
man's (he looks, he starts at a blast); no hands-up on the companions or Jakub. Zombie code untouched.

## Cost

The world is read four times a second per NPC (staggered), only while the camera is within 32 m, with no raycasts:
a distance check against the active zombies and the human players. The per-frame work is a handful of lerps folded
into the poses that already ran (and they keep the T-139 / T-237 animation LOD). Breath fog is one GPUParticles3D of
six particles per NPC, only in the cold, emitting under half a second every few seconds. About 5-10 NPCs carry it on
a map.

## Tests and tools

- `gravelight/tests/unit/test_npc_life.gd` (16): the look's angles and clamp, the aim cone, idles that never repeat,
  where breath shows, a shot turning the head and startling, a far shot doing nothing, a zombie winning the look,
  idles cycling with pauses, the warm hands under the chin, hands up and fear, Trudi without the watch fidget, the
  knife at the hip, the shovel blade down, the companions' warm hands under the chin, Trudi's skirt and stockings
  not near black, set_life on / off.
- `gravelight/tools_src/shots_npcs.tscn`: the studio contact sheets (`sh tools/wsl_godot.sh --res=1920x1080
  --path . res://gravelight/tools_src/shots_npcs.tscn -- --out=res://docs/captures/u18_npcs/after`).

## Left for the owner's look

The look in a real window at night on Map 0 (the WSL renders are a lit studio, darker than the owner's GPU and
without the map's grade). The skirt's own skinning (a long skirt blends its weights between the thighs, so in a long
stride the trailing leg pulls the hem back) was not rebuilt: it did not show in the renders and the GLBs were left as
they are.
