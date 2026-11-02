# Audio mix per map and act (UPDATE 10 s6 item 5, DECISIONS T-162)

Tool: `python gravelight/tools_src/amb_loudness.py [all|map00 map02 ...] [--limit=-8] [--vo-margin=6] [--apply]`
(needs numpy, scipy, ffmpeg). It measures every map-wide bed (audio.json `music.ambient` at the top of
`music.ambient_db`, plus the per-map `music.ambient_trim_db`) and every ZoneAmbience zone bed (with the map bed under
it) against the player's footsteps (the loudest 400 ms of the `footstep_*` keys, BS.1770 momentary) and the VO (the
mean integrated loudness of the baked lines, -17.3 LUFS, + `rules.json audio.squad_volume_db`).

Rule: every bed, alone and with the map bed under it, sits at least 8 dB under a footstep; the VO sits at least 6 dB
over every bed. `--apply` writes one uniform offset per map (the zone balance is kept) into `music.ambient_trim_db`
(read by `AudioDirector._ambient_db`) and the zones' `db` in `data/gravelight/ambience/<map>.json`.
Footsteps measure -33.0 LUFS, the VO -17.3 LUFS. Test: `test_audio_mix` (the data); the tool's exit code is the
loudness gate. One-shots (creaks, gusts, radio) are events, not beds, and are untouched.

## Before (44 of 54 beds over; Totenhafen was already trimmed in T-154)
```
footsteps (5 keys, loudest 400 ms):  -33.0 LUFS   VO (mean of the baked lines + trim):  -17.3 LUFS
rule: every bed (alone and with the map bed under it) <= footsteps -8.0 dB, and VO >= bed +6.0 dB
== map00
  (map bed)      ambient_map00               -27.0 LUFS ( +6.0 vs steps)  with map bed  -27.0  VO over it  +9.8  OVER
== map01
  (map bed)      ambient_map01               -24.6 LUFS ( +8.4 vs steps)  with map bed  -24.6  VO over it  +7.3  OVER
  A_MINEHEAD     ambient_map01_minehead      -32.5 LUFS ( +0.5 vs steps)  with map bed  -23.9  VO over it  +6.7  OVER
  B_RAILYARD     ambient_map01_railyard      -32.0 LUFS ( +1.0 vs steps)  with map bed  -23.9  VO over it  +6.6  OVER
  C_ADMIN        ambient_map01_admin         -28.3 LUFS ( +4.7 vs steps)  with map bed  -23.0  VO over it  +5.8  OVER
  D_BARRACKS     ambient_map01_barracks      -35.5 LUFS ( -2.5 vs steps)  with map bed  -24.2  VO over it  +7.0  OVER
  E_LIFT         ambient_map01_lift          -31.3 LUFS ( +1.7 vs steps)  with map bed  -23.7  VO over it  +6.5  OVER
  M_STAIRS       ambient_map01_stairs        -39.5 LUFS ( -6.5 vs steps)  with map bed  -24.4  VO over it  +7.2  OVER
  F_CHAPEL       ambient_map01_chapel        -32.3 LUFS ( +0.7 vs steps)  with map bed  -23.9  VO over it  +6.6  OVER
  G_GENERATOR    ambient_map01_generator     -25.5 LUFS ( +7.5 vs steps)  with map bed  -22.0  VO over it  +4.7  OVER
  H_LAB          ambient_map01_lab           -28.5 LUFS ( +4.5 vs steps)  with map bed  -23.1  VO over it  +5.8  OVER
  I_CORE         ambient_map01_core          -27.0 LUFS ( +6.0 vs steps)  with map bed  -22.6  VO over it  +5.4  OVER
== map02
  (map bed)      ambient_map02_storm         -44.3 LUFS (-11.3 vs steps)  with map bed  -44.3  VO over it +27.0  ok
  A_QUAY         ambient_map02_quay          -45.9 LUFS (-12.9 vs steps)  with map bed  -42.0  VO over it +24.8  ok
  B_CANNERY      ambient_map02_cannery       -46.1 LUFS (-13.1 vs steps)  with map bed  -42.1  VO over it +24.8  ok
  C_WORKSHOP     ambient_map02_workshop      -46.4 LUFS (-13.4 vs steps)  with map bed  -42.2  VO over it +25.0  ok
  D_PENHALL      ambient_map02_penhall       -46.6 LUFS (-13.5 vs steps)  with map bed  -42.3  VO over it +25.0  ok
  E_UBOAT        ambient_map02_uboat         -46.2 LUFS (-13.2 vs steps)  with map bed  -42.1  VO over it +24.9  ok
  F_LOWERPENS    ambient_map02_pens          -45.8 LUFS (-12.8 vs steps)  with map bed  -42.0  VO over it +24.7  ok
  G_SIGNAL       ambient_map02_tower         -46.4 LUFS (-13.4 vs steps)  with map bed  -42.2  VO over it +24.9  ok
== map04a
  (map bed)      wind_howl                   -28.9 LUFS ( +4.1 vs steps)  with map bed  -28.9  VO over it +11.7  OVER
  A_SIEDLUNG     ambient_map04a_siedlung     -30.6 LUFS ( +2.4 vs steps)  with map bed  -26.7  VO over it  +9.4  OVER
  B_BAHNHOF      ambient_map04a_bahnhof      -25.6 LUFS ( +7.4 vs steps)  with map bed  -23.9  VO over it  +6.7  OVER
  C_KANTINE      ambient_map04a_kantine      -29.8 LUFS ( +3.2 vs steps)  with map bed  -26.3  VO over it  +9.1  OVER
  D_KIRCHPLATZ   ambient_map04a_church       -31.6 LUFS ( +1.4 vs steps)  with map bed  -27.1  VO over it  +9.8  OVER
  E_MONTAGE      ambient_map04a_montage      -37.1 LUFS ( -4.1 vs steps)  with map bed  -28.3  VO over it +11.1  OVER
  F_WINDKANAL    ambient_map04a_tunnel       -32.3 LUFS ( +0.8 vs steps)  with map bed  -27.3  VO over it +10.0  OVER
  G_PRUEFSTAND   ambient_map04a_pits         -27.8 LUFS ( +5.2 vs steps)  with map bed  -25.3  VO over it  +8.1  OVER
  H_HALLE        ambient_map04a_hangar       -29.6 LUFS ( +3.5 vs steps)  with map bed  -26.2  VO over it  +9.0  OVER
== map04b
  (map bed)      ambient_map04b              -25.4 LUFS ( +7.6 vs steps)  with map bed  -25.4  VO over it  +8.2  OVER
  A_BOMBENSCHACHT ambient_map04b_bay          -30.7 LUFS ( +2.3 vs steps)  with map bed  -24.3  VO over it  +7.0  OVER
  B_MITTELRUMPF  ambient_map04b_body         -38.9 LUFS ( -5.9 vs steps)  with map bed  -25.2  VO over it  +8.0  OVER
  C_FLUEGEL_L    ambient_map04b_wing         -29.0 LUFS ( +4.0 vs steps)  with map bed  -23.9  VO over it  +6.6  OVER
  C_FLUEGEL_R    ambient_map04b_wing         -29.0 LUFS ( +4.0 vs steps)  with map bed  -23.9  VO over it  +6.6  OVER
  D_TRIEBWERK    ambient_map04b_engine       -30.7 LUFS ( +2.3 vs steps)  with map bed  -24.3  VO over it  +7.0  OVER
  E_KANZEL       ambient_map04b_blister      -30.4 LUFS ( +2.6 vs steps)  with map bed  -24.2  VO over it  +7.0  OVER
  F_COCKPIT      ambient_map04b_cockpit      -36.5 LUFS ( -3.4 vs steps)  with map bed  -25.1  VO over it  +7.8  OVER
== map04c
  (map bed)      ambient_map04c              -27.5 LUFS ( +5.5 vs steps)  with map bed  -27.5  VO over it +10.3  OVER
  A_WRECK        ambient_map04c_wreck        -32.3 LUFS ( +0.7 vs steps)  with map bed  -26.3  VO over it  +9.0  OVER
  B_LAKEBED      ambient_map04c_lakebed      -31.8 LUFS ( +1.2 vs steps)  with map bed  -26.2  VO over it  +8.9  OVER
  C_HANGAR       ambient_map04c_hangar       -37.9 LUFS ( -4.9 vs steps)  with map bed  -27.2  VO over it  +9.9  OVER
  D_MOTORPOOL    ambient_map04c_motorpool    -32.4 LUFS ( +0.6 vs steps)  with map bed  -26.3  VO over it  +9.1  OVER
  E_RADAR        ambient_map04c_radar        -29.8 LUFS ( +3.2 vs steps)  with map bed  -25.5  VO over it  +8.3  OVER
  F_LAB          ambient_map04c_lab          -27.1 LUFS ( +6.0 vs steps)  with map bed  -24.3  VO over it  +7.0  OVER
  G_SILO         ambient_map04c_silo         -31.9 LUFS ( +1.1 vs steps)  with map bed  -26.2  VO over it  +8.9  OVER
== map04d
  (map bed)      ambient_map04d_concourse    -20.8 LUFS (+12.2 vs steps)  with map bed  -20.8  VO over it  +3.5  OVER
  A_RECEPTION    ambient_map04d_reception    -30.6 LUFS ( +2.5 vs steps)  with map bed  -20.4  VO over it  +3.1  OVER
  B_CONCOURSE    ambient_map04d_concourse    -26.8 LUFS ( +6.2 vs steps)  with map bed  -19.8  VO over it  +2.6  OVER
  C_YARD         ambient_map04d_yard         -34.6 LUFS ( -1.5 vs steps)  with map bed  -20.6  VO over it  +3.4  OVER
  D_FULFILLMENT  ambient_map04d_store        -32.4 LUFS ( +0.6 vs steps)  with map bed  -20.5  VO over it  +3.3  OVER
  E_HALL         ambient_map04d_hall         -26.3 LUFS ( +6.7 vs steps)  with map bed  -19.7  VO over it  +2.5  OVER
  F_CORE         ambient_map04d_account      -27.9 LUFS ( +5.1 vs steps)  with map bed  -20.0  VO over it  +2.8  OVER
RESULT: FAIL (44 beds over)
```

## After (0 over)
```
footsteps (5 keys, loudest 400 ms):  -33.0 LUFS   VO (mean of the baked lines + trim):  -17.3 LUFS
rule: every bed (alone and with the map bed under it) <= footsteps -8.0 dB, and VO >= bed +6.0 dB
  trim map00: -15.0 dB (loudest +6.0 vs steps)
  trim map01: -20.0 dB (loudest +11.0 vs steps)
  trim map04a: -18.1 dB (loudest +9.1 vs steps)
  trim map04b: -18.1 dB (loudest +9.1 vs steps)
  trim map04c: -17.7 dB (loudest +8.7 vs steps)
  trim map04d: -22.3 dB (loudest +13.3 vs steps)
== map00
  (map bed)      ambient_map00               -42.0 LUFS ( -9.0 vs steps)  with map bed  -42.0  VO over it +24.8  ok
== map01
  (map bed)      ambient_map01               -44.6 LUFS (-11.6 vs steps)  with map bed  -44.6  VO over it +27.3  ok
  A_MINEHEAD     ambient_map01_minehead      -52.5 LUFS (-19.5 vs steps)  with map bed  -43.9  VO over it +26.7  ok
  B_RAILYARD     ambient_map01_railyard      -52.0 LUFS (-19.0 vs steps)  with map bed  -43.9  VO over it +26.6  ok
  C_ADMIN        ambient_map01_admin         -48.3 LUFS (-15.3 vs steps)  with map bed  -43.0  VO over it +25.8  ok
  D_BARRACKS     ambient_map01_barracks      -55.5 LUFS (-22.5 vs steps)  with map bed  -44.2  VO over it +27.0  ok
  E_LIFT         ambient_map01_lift          -51.3 LUFS (-18.3 vs steps)  with map bed  -43.7  VO over it +26.5  ok
  M_STAIRS       ambient_map01_stairs        -59.5 LUFS (-26.5 vs steps)  with map bed  -44.4  VO over it +27.2  ok
  F_CHAPEL       ambient_map01_chapel        -52.3 LUFS (-19.3 vs steps)  with map bed  -43.9  VO over it +26.6  ok
  G_GENERATOR    ambient_map01_generator     -45.5 LUFS (-12.5 vs steps)  with map bed  -42.0  VO over it +24.7  ok
  H_LAB          ambient_map01_lab           -48.5 LUFS (-15.5 vs steps)  with map bed  -43.1  VO over it +25.8  ok
  I_CORE         ambient_map01_core          -47.0 LUFS (-14.0 vs steps)  with map bed  -42.6  VO over it +25.4  ok
== map02
  (map bed)      ambient_map02_storm         -44.3 LUFS (-11.3 vs steps)  with map bed  -44.3  VO over it +27.0  ok
  A_QUAY         ambient_map02_quay          -45.9 LUFS (-12.9 vs steps)  with map bed  -42.0  VO over it +24.8  ok
  B_CANNERY      ambient_map02_cannery       -46.1 LUFS (-13.1 vs steps)  with map bed  -42.1  VO over it +24.8  ok
  C_WORKSHOP     ambient_map02_workshop      -46.4 LUFS (-13.4 vs steps)  with map bed  -42.2  VO over it +25.0  ok
  D_PENHALL      ambient_map02_penhall       -46.6 LUFS (-13.5 vs steps)  with map bed  -42.3  VO over it +25.0  ok
  E_UBOAT        ambient_map02_uboat         -46.2 LUFS (-13.2 vs steps)  with map bed  -42.1  VO over it +24.9  ok
  F_LOWERPENS    ambient_map02_pens          -45.8 LUFS (-12.8 vs steps)  with map bed  -42.0  VO over it +24.7  ok
  G_SIGNAL       ambient_map02_tower         -46.4 LUFS (-13.4 vs steps)  with map bed  -42.2  VO over it +24.9  ok
== map04a
  (map bed)      wind_howl                   -47.0 LUFS (-14.0 vs steps)  with map bed  -47.0  VO over it +29.8  ok
  A_SIEDLUNG     ambient_map04a_siedlung     -48.7 LUFS (-15.7 vs steps)  with map bed  -44.8  VO over it +27.5  ok
  B_BAHNHOF      ambient_map04a_bahnhof      -43.7 LUFS (-10.7 vs steps)  with map bed  -42.0  VO over it +24.8  ok
  C_KANTINE      ambient_map04a_kantine      -47.9 LUFS (-14.9 vs steps)  with map bed  -44.4  VO over it +27.2  ok
  D_KIRCHPLATZ   ambient_map04a_church       -49.7 LUFS (-16.7 vs steps)  with map bed  -45.2  VO over it +27.9  ok
  E_MONTAGE      ambient_map04a_montage      -55.2 LUFS (-22.2 vs steps)  with map bed  -46.4  VO over it +29.2  ok
  F_WINDKANAL    ambient_map04a_tunnel       -50.4 LUFS (-17.3 vs steps)  with map bed  -45.4  VO over it +28.1  ok
  G_PRUEFSTAND   ambient_map04a_pits         -45.9 LUFS (-12.9 vs steps)  with map bed  -43.4  VO over it +26.2  ok
  H_HALLE        ambient_map04a_hangar       -47.7 LUFS (-14.6 vs steps)  with map bed  -44.3  VO over it +27.1  ok
== map04b
  (map bed)      ambient_map04b              -43.5 LUFS (-10.5 vs steps)  with map bed  -43.5  VO over it +26.3  ok
  A_BOMBENSCHACHT ambient_map04b_bay          -48.8 LUFS (-15.8 vs steps)  with map bed  -42.4  VO over it +25.1  ok
  B_MITTELRUMPF  ambient_map04b_body         -57.0 LUFS (-24.0 vs steps)  with map bed  -43.3  VO over it +26.1  ok
  C_FLUEGEL_L    ambient_map04b_wing         -47.1 LUFS (-14.1 vs steps)  with map bed  -42.0  VO over it +24.7  ok
  C_FLUEGEL_R    ambient_map04b_wing         -47.1 LUFS (-14.1 vs steps)  with map bed  -42.0  VO over it +24.7  ok
  D_TRIEBWERK    ambient_map04b_engine       -48.8 LUFS (-15.8 vs steps)  with map bed  -42.4  VO over it +25.1  ok
  E_KANZEL       ambient_map04b_blister      -48.5 LUFS (-15.5 vs steps)  with map bed  -42.3  VO over it +25.1  ok
  F_COCKPIT      ambient_map04b_cockpit      -54.6 LUFS (-21.5 vs steps)  with map bed  -43.2  VO over it +25.9  ok
== map04c
  (map bed)      ambient_map04c              -45.2 LUFS (-12.2 vs steps)  with map bed  -45.2  VO over it +28.0  ok
  A_WRECK        ambient_map04c_wreck        -50.0 LUFS (-17.0 vs steps)  with map bed  -44.0  VO over it +26.7  ok
  B_LAKEBED      ambient_map04c_lakebed      -49.5 LUFS (-16.5 vs steps)  with map bed  -43.9  VO over it +26.6  ok
  C_HANGAR       ambient_map04c_hangar       -55.6 LUFS (-22.6 vs steps)  with map bed  -44.9  VO over it +27.6  ok
  D_MOTORPOOL    ambient_map04c_motorpool    -50.1 LUFS (-17.1 vs steps)  with map bed  -44.0  VO over it +26.8  ok
  E_RADAR        ambient_map04c_radar        -47.5 LUFS (-14.5 vs steps)  with map bed  -43.2  VO over it +26.0  ok
  F_LAB          ambient_map04c_lab          -44.8 LUFS (-11.7 vs steps)  with map bed  -42.0  VO over it +24.7  ok
  G_SILO         ambient_map04c_silo         -49.6 LUFS (-16.6 vs steps)  with map bed  -43.9  VO over it +26.6  ok
== map04d
  (map bed)      ambient_map04d_concourse    -43.1 LUFS (-10.1 vs steps)  with map bed  -43.1  VO over it +25.8  ok
  A_RECEPTION    ambient_map04d_reception    -52.9 LUFS (-19.8 vs steps)  with map bed  -42.7  VO over it +25.4  ok
  B_CONCOURSE    ambient_map04d_concourse    -49.1 LUFS (-16.1 vs steps)  with map bed  -42.1  VO over it +24.9  ok
  C_YARD         ambient_map04d_yard         -56.9 LUFS (-23.8 vs steps)  with map bed  -42.9  VO over it +25.7  ok
  D_FULFILLMENT  ambient_map04d_store        -54.7 LUFS (-21.7 vs steps)  with map bed  -42.8  VO over it +25.6  ok
  E_HALL         ambient_map04d_hall         -48.6 LUFS (-15.6 vs steps)  with map bed  -42.0  VO over it +24.8  ok
  F_CORE         ambient_map04d_account      -50.2 LUFS (-17.2 vs steps)  with map bed  -42.3  VO over it +25.1  ok
RESULT: PASS (0 beds over)
```
