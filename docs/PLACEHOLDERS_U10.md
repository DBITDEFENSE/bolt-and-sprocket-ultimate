# Placeholders after UPDATE 10 (T-162, UPDATE 10 section 6 item 8)

Swept: `data/`, `gravelight/` and `docs/gravelight/VO_SCRIPT.md` for "placeholder", "TODO", "TBD", "lorem", `%PAUL`, `%DEVIN`;
the VO manifest's `missing`; the textures and models of the new content. **Replaced in this pass** and **still open**.

## Replaced in this pass

| What | Was | Now |
|---|---|---|
| VO manifest `missing` list | 341 lines "bake on the PC" (stale: 318 of them had been baked by T-166 and nothing took them off the list) | `gen_vo.py` now drops a baked line from `missing`; the list is **5** (see below) |
| Bolt, Sprocket and Vendelin VO (M4C, M4D and the `TERMS_READ` cabinet lines) | 18 lines with no voice profile, silent | OneCore placeholder profiles `BLT`, `SPR`, `VEN` (`gen_vo.py` PROFILES, radio chain), **18 lines baked** on the PC |
| Obergefreiter Pohl's body (Act IV, `people_extra.json`) | the `kubiak` kit as a stand-in (T-158) | his own person `ogpohl` (`data/gravelight/art/people.json`, `kit_ogpohl` in `tools_src/blender/characters/make_kits.py`: field tunic, side cap, radio headset), built with `tools/build_people.sh --only=ogpohl` into `assets/ours/characters/people/char_person_ogpohl.glb` (19.4k tris) |
| "Lanterns Down Below" banner (`quests/map01_song.json`) | printed "(placeholder audio)" on screen | just the title (the credits screen still says the songs are placeholder audio: true) |

## Still open

### Voice (the owner)
- **All 2,428 baked lines are synthetic** (Kokoro neural for the cast speakers, Windows OneCore for the rest): placeholders for
  recorded takes. 0 lines are recorded. The pickup scripts: `tools/voice.sh scripts` (`voice_scripts/`, `voice_inbox/`).
- **5 lines with no audio, on purpose** (timed silence, the subtitle shows): `LSL_REC_DRUMMER_01` (a giggle under the drum),
  `PAU_LAND_01` (a roar), `REI_HEART_END` (a scream that becomes the bell toll), `WRN_M4B_LONDON_01`, `WRN_M4C_RESIGN_01`
  (stage directions only). They need a sound-design take, not a voice.
- The Map 4 speakers WIT, PA, WIV, DEE, HAL, BWT, RRK, BLT, SPR, VEN, PAU and SLN are OneCore placeholders (T-150, T-159,
  T-160, this pass) until the owner casts them (`data/voice/cast.json`).

### Text
- `data/gravelight/bosses/likeness.json`: the Likeness Sheet's owner-fill tokens `PAUL_SIGNATURE`, `PAUL_LASTNAME`, `PAUL_UNIT`,
  `PAUL_LETTER_DETAILS`, `DEVIN_SIGNATURE`, `DEVIN_LASTNAME`, `COUSIN_1_NAME`, `COUSIN_2_NAME`. Defaults are used until
  filled (`HomageBoss.is_placeholder`); no token ever reaches the screen (test_paul, test_slender, test_homage_cousins).
- `data/gravelight/bosses/map03.json` (Morgenrot, `"placeholder": true`): the hook for a map that is not built.
- `data/hub.json`: "Placeholder look until the M9 hub" (the old Bolt & Sprocket hub, not the Gravelight front end).
- `data/voice/cast.json`: the `[ACTOR]` / `[COUSIN_1]` slots for the recorded cast.
- `ui/menu_credits.gd` says, correctly, that all SFX, stingers, ambience, songs and jingles are original synthesized
  audio, and the voice lines "placeholder (subtitles only) until recorded" (the latter is now out of date: lines are
  synthetic voice; reword when the first takes are in).

### Audio (generated stand-ins)
- `gravelight/audio/sfx/placeholder/`: 52 procedural WAVs (`gen_audio_kit.py`, `gen_sfx.gd`) that `AudioDirector` plays for a
  key with no bank entry; `gravelight/audio/music/placeholder/`: 4 files (`ambient_wind`, `game_over`, `round_end`,
  `round_start`). Real banks (`audio.json`) cover the mix in play; these are the fallbacks.
- "Lanterns Down Below", "Come Along, Little Soldier" and the perk jingles: lyrics as subtitles, no composed recording
  (`phonograph.gd`, JINGLES.md). A composer's job.

### Models and textures
- **Co-op clients see a generic zombie puppet for PAUL and THE SLENDER** (`homage_boss.gd`: "a client sees the generic puppet
  body, no boss presentation yet"). The host sees the real bosses. Needs the boss rigs replicated (an online follow-up).
- **Totenhafen's Kielholer, Kielholer diver, searchlight and boat** (T-153, not on this branch): when they land, check
  whether they are primitives; the searchlight hint (`hints.json`) and the Letzte Fahrt citation are already guarded by
  the node / quest file existing.
- `ogpohl` is 19.4k triangles (the people budget was 12-15k): a lighter soldier kit is a follow-up.
- The 4,000+ procedural landscape cards and the greybox-generated architecture follow the ART_BIBLE's rules; they are
  stylised, not placeholders.

## Size of the list
Replaced 4; open 17 items (1 voice, 3 voice detail, 4 text, 3 audio, 2 model, plus 4 owner-only tokens counted inside
the text rows).
