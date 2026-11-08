# CUTSCENES_LAZARUS — shot lists for UPDATE 11 "LAZARUS" (work order §5; DECISIONS T-191; built by T-194)

Four cutscenes and one epilogue card, all on the T-184 cinema library (`gravelight/ui/cinema/*`: CinemaDirector's
timeline of CinemaShot entries, CinemaCamera, CinemaOverlay's letterbox / grade / title card / captions / hold-to-skip,
CinemaCast for the squad). Every line they speak is an ID row in `docs/gravelight/VO_SCRIPT.md` §26 and so in
`data/gravelight/vo/lines.json` (German lines carry the spoken form in `speech`; the subtitle is `text`, always
English; since T-204 the Russian-speaking cast speaks English with a Russian accent, the Russian kept in
`data/gravelight/vo/lang/ru.json`; the cinema subtitles sit in the bottom bar as T-184 built them). The canon is the work order §1 until
`docs/LAZARUS.md` (T-190) lands; the names here are the work order's and must stay exactly as written.

**Rules for every cutscene (work order §5):** skippable (hold [interact], the overlay's bar, after `skip_after` 3 s;
no "first viewing only" exception); co-op and online **host-driven** (every peer plays its own copy on the host's
clock, the host's end ends it, a skip is the co-op vote through the exfil's `request_skip_local`, exactly as the exfil
hops work); subtitles on the overlay's bottom bar for every spoken line; **gore follows the Gore setting** (the
gore-gated element of each shot is marked `[gore]`: with Gore off that element is not drawn, the shot still plays);
**the 1930 cutscene shows no violence against clergy or villagers on screen**: the camera cuts away before every
blow, and sound and aftermath carry it. Faith is treated with respect: the lamp, the chant, the prayer and the
inscription are shot the way a church is shot, never as set dressing for a scare. Serafim is the most decent man in
the saga; Volkov is frightened, clever and ambitious, never a cartoon. No real political or Nazi symbol anywhere: red
banners are plain cloth, the Soviet uniforms are period-correct and insignia are never framed close enough to read,
the German plant has no eagles, no flags, no runes (ART_FACTIONS: the Wiederkehr mark only).

**Conventions in the tables.** `#` shot number, `dur` seconds, **set** the stage the shot is on (§6), **camera** in
the library's terms: the lens as `fov` (24 = a long lens, 50 = normal, 70 = wide), the move (`static`, `dolly`,
`crane`+`arc`, `orbit`+`sweep`), `lead`/`hold`, `handheld` 0..1, `roll`, `blur` (depth of field, Forward+ only),
the `cut` (cut / blend / dip). **Grade** is a preset of CinemaOverlay.PRESETS (`night`, `cold`, `storm`, `memory`,
`violet`, `warm`, `dawn`) or inline values; the two new looks this document asks for, `thaw` (1930: exposure 0.98,
contrast 1.04, saturation 0.55, tint [0.97, 1.0, 0.96], lift [0.02, 0.022, 0.018], vignette 0.38) and `ward`
(the fever ward: exposure 1.06, contrast 1.0, saturation 0.4, tint [1.02, 1.0, 0.95], lift [0.03, 0.03, 0.028],
vignette 0.46), may be added to PRESETS by T-194 or written inline. **Sound** names audio.json keys where one exists
(`bell_toll`, `amb_church_bell_far`, `war_flare_pop`, `war_artillery_boom`, `wind_howl`, `amb_wind_gust`,
`explosion_large`, `kranich_creak`, `kranich_rattle`, `a1_train_steam`, `a1_train_whistle`, `teletype_print`,
`ui_stamp`...) and marks a **new** sound with `*` (T-194 synthesizes or sources it, CC0 only; the horror pass T-192
owns the chant bed and the Russian whispers, so the cutscenes take those from its keys when they land). **Cards**
are the overlay's title card (place in the stamp face, the violet rule, place / date / time in the typewriter face
with the stamp and teletype sounds) and their text is **exactly** what is in the `card` rows. Cards and captions are
Latin letters only: the stamp face (Stardos Stencil) and the typewriter face (Special Elite) have no Cyrillic glyphs,
so Chetverodnevo is transliterated on every card; Cyrillic appears on screen only as painted text on a prop
(the typhus board, the brigade's paper) and never in a UI font. The subtitle body face (IBM Plex Sans) does have
Cyrillic, but the subtitle is always the English `text` (test_vo_speech).

Dates checked: Orthodox Pascha 1930 fell on 20 April (Gregorian; 7 April Julian), so Palm Sunday was 13 April and
**Lazarus Saturday was 12 April 1930**. The sickness counts the fourth day the way John 11 does, inclusively: the
three who died on Tuesday the 15th rise on Friday the 18th (LAZARUS §2.4), so the chart in shot 27 reads 18.IV. The OGPU
existed under that name until July 1934 (then the NKVD's GUGB; from April 1943 state security was the NKGB, so Volkov's
1944 boards are a state-security colonel's and no line names the agency). The Red Army entered East Prussia in the
Gumbinnen–Goldap operation, 16–30 October 1944. The brigade's truck is an **AMO-F-15** (Moscow, 1924–1931, 1.5 t): the GAZ-AA the work order
suggested only entered production in 1932, so it is wrong for April 1930.

---

## 1. "LAZARUS SATURDAY" — the prologue   ~224 s (the work order's "about 3 minutes", with its three cards)

Chetverodnevo, Lazarus Saturday, 12 April 1930. Plays before the main menu on **first launch** (ProfileSave flag
`prologue_seen`; "Prologue — Lazarus Saturday" in the Archive's cutscene gallery and a Play.bat button replay it),
skippable from 3 s. No squad: the director runs with `cast: false`; the people in it are built stand-ins (§7). Grade
opens `thaw`. Music: no score until shot 31; the bed is the thaw itself (`*amb_thaw`: dripping, rooks, a dog far
off, mud) with the church bell ringing for the feast under it until it is roped down.

Five movements: the road (1–6), the door (7–11), the bell and the tower (12–17), the crypt (18–25), the fourth day
(26–33). **Nobody is struck on camera.** The two moments the brigade lays hands on anyone (the villagers pulled off
the road at 6, Serafim pulled from the door at 11) are heard over a shot of something else and seen only in their
aftermath (a shawl in the mud, a dropped key ring, a cassock sleeve torn at the cuff).

| # | t | dur | set | camera | what is seen | sound | lines (subtitle) | grade / card |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.0 | 6 | black | — | Black. | far off, a single feast bell (`bell_toll`, -14 dB, slow); rooks | — | **card** (at 1.0, hold 5): **CHETVERODNEVO** / *a village a long day's cart from the district town* / *Lazarus Saturday  ·  12 April 1930* |
| 2 | 6.0 | 8 | A the road | fov 32, `dolly` low over the mud ruts toward the church, from 60 m out, ease `smooth`, handheld 0.18, blur 0.3 | Grey light, a thaw. A rutted road of brown water, snow in the ditches, the wooden church and its tent-roofed bell tower at the end of it, the onion dome dull. Smoke from one chimney. The bell swings. | `*amb_thaw`; the bell nearer | — | `thaw` |
| 3 | 14.0 | 7 | A the road | fov 50, `static`, blend 0.8 | **The villagers kneeling in the road**, forty of them, in a loose band across it, facing the way the camera came: old men with their caps off, women in shawls, children held by the shoulders. Nobody speaks. The bell. | the bell; a child coughs; wind | — | |
| 4 | 21.0 | 6 | A the road | fov 24, `static` from the church porch, long lens down the road | Far down the road through the birches: **the truck**, an AMO-F-15, canvas back, two red cloths on poles tied to its cab, people standing in the back. It comes slowly, slithering in the ruts. | `*truck_1930` (a four-cylinder engine, a loose body) | — | |
| 5 | 27.0 | 9 | A the road | fov 40, `dolly` alongside the truck as it stops short of the kneeling line, lead 1, handheld 0.3 | The truck stops. Men and two women climb down: town coats, caps, **red armbands of plain cloth**, crowbars, coiled rope, a tin speaking trumpet. A wooden box is handed down with care (the dynamite). Last out, from the cab, a young man in a khaki tunic and a cap with a maroon band: **Volkov**. He looks at the kneeling road and then, quickly, away from it. | the engine dies; boots in the mud; the bell stops mid-swing (someone in the tower has been told) | `BRG_LZS_01` at 3.0 ("Citizens! By resolution of the district executive committee, the church of the village of Chetverodnevo is closed.") | |
| 6 | 36.0 | 8 | A the road | fov 50, `static` on **the church door** from the road, the kneeling backs out of focus in the foreground (blur 0.5) | The speaking trumpet reads the slogans, flat, off a paper. **On the door**, in a black cassock and skufia, a grey beard, a ring of keys in his hand: **Father Serafim**. He does not move. Out of focus, the brigade begins to pull the kneeling people off the road, roughly, by the arm. **The camera holds on Serafim and never racks to them.** | `BRG_LZS_02`, `BRG_LZS_03` (the megaphone); a woman's cry, a man's shout, something dropped in the mud; the children | `BRG_LZS_02` at 0.5 ("The bells are surrendered to the needs of industrialization. Go back to your homes."); `BRG_LZS_03` at 4.5 ("The struggle against religion is the struggle for socialism!") | |
| 7 | 44.0 | 7 | B the porch | fov 55, `dolly` in from 6 m to 2.5 m on Serafim, ease `out_sine`, handheld 0.2 | Serafim, close. He raises his free hand, palm down, toward the road behind the camera: *get up, go home*. | the road quieting | `SER_LZS_02` at 0.4 ("Get up, get up, my dears. Not for them, your knees. Go home. Take the children.") | |
| 8 | 51.0 | 7 | B the porch | fov 45, `static`, a two-shot over Volkov's shoulder onto Serafim, blur 0.4 on the shoulder | Volkov on the step below him with a paper. He is correct, formal, twenty-six, and his voice is a touch too loud. | the trumpet far behind | `VOL_LZS_01` at 0.3 ("Citizen Lebedev? Volkov, OGPU plenipotentiary. Here is the warrant. The keys.") | |
| 9 | 58.0 | 7 | B the porch | the reverse: fov 45, `static` over Serafim's shoulder onto Volkov | Serafim's hand closes on the keys. Not a fist. He simply doesn't open it. | — | `SER_LZS_01` at 0.3 ("I won't give you the keys. They aren't mine. I only hold them."); `BRG_LZS_08` at 4.6 behind ("Priest Lebedev! Hand over the keys voluntarily.") | |
| 10 | 65.0 | 6 | B the porch | fov 70, `static` low at the step, the two of them small against the door, the brigade head's boots entering frame | Volkov turns to the brigade head (an older man, a Komsomol cell leader in a leather cap) and keeps his voice down. He is managing it. | — | `VOL_LZS_02` at 0.3 ("No roughness. These people aren't enemies, they're ignorance. The bell comes down, the tower comes down, the silver goes on the inventory. That's all.") | |
| 11 | 71.0 | 6 | B the porch | fov 35, `static` on **the ring of keys in Serafim's hand** at the end of a quiet shot, `dip` 0.4 at the end | Two of the brigade step into frame from either side; their hands close on his arms. **Cut on the first movement.** We do not see him pulled from the door. **Dip to black 0.4 s**; over black, the sound. | the scuffle (two seconds, close): a grunt, cloth, the keys hitting the boards | `SER_LZS_07` [whispers] at 4.0, over black ("Lord, have mercy.") | |
| 12 | 77.0 | 8 | C the tower | fov 28, `crane` from the porch roof up the tower to the bell, arc 2, ease `smooth`, blend 0.6 | Daylight again. A rope goes up to the bell. Two men on the belfry rail work a crowbar at the yoke. Below, out of focus, a cassock sleeve torn at the cuff: Serafim on the ground on his knees between two of the brigade, not held now, just kept there. He is praying. | ropes creak; the yoke's iron | `SER_LZS_08` at 1.0, half-sung, under his breath, the troparion of the day ("Confirming the general resurrection before Thy Passion, Thou didst raise Lazarus from the dead, O Christ God.") | |
| 13 | 85.0 | 6 | C the tower | fov 50, `static` from the ground, looking up | The bell swings out over the rail on the rope. Hands on the rope below. The rope runs. **The bell drops.** | the rope through the hands; a shout | `BRG_LZS_06` at 0.3 ("Comrade peasants! Get up off your knees. Do not obstruct the brigade's work.") | |
| 14 | 91.0 | 5 | C the tower | fov 40, `static` at ground level on the mud where it lands, shake [[0.9, 0.7]] | **The bell hits the ground and cracks**: one dead note and a seam opening up its waist. Mud on the bronze. A villager's hand comes into frame and touches the crack, then is pulled back. | `*bell_crack` (a toll that ends in a split; then nothing) | — | |
| 15 | 96.0 | 7 | C the tower | fov 24, `static` from far down the road, long lens, the tower centre frame, the brigade running out of the porch | The wooden box has gone in and the men have come out. A whistle. The road is cleared back. | `BRG_LZS_07` shouted through the trumpet; a whistle | `BRG_LZS_07` at 0.5 ("Away from the bell tower! Away! There will be a blast!") | |
| 16 | 103.0 | 6 | C the tower | the same frame, hold | **The tower comes down**: the charge takes the base, the shingled tent roof leans, then folds into itself and goes, slowly, in a plume of grey dust that rolls up the road toward the camera and swallows the frame. | `explosion_large` at 1.0 (-2 dB), timbers, the plume (`*timber_fall`); the rooks go up all at once (`amb_crow_flap`) | — | |
| 17 | 109.0 | 7 | C the tower | fov 60, `static`, the dust thinning | Through the dust: the church still standing with a raw stump where the tower was. Serafim on his knees in the road with his hand over his mouth, coughing. Volkov beside the truck, writing on a board. He looks up at Serafim and, for a moment, looks ashamed. | the dust settling; coughing | `SER_LZS_03` at 2.5, quietly, to Volkov ("Young man. Take the silver. Take the bell. Only don't go down into the crypt.") | |
| 18 | 116.0 | 6 | D the crypt stair | fov 55, `dolly` down the stone steps behind two lanterns, handheld 0.35, blend 0.8 | Inside, under the floor: a stone undercroft older than the wooden church over it. A low door at the bottom of the steps and, over it, **a lamp still lit** on its chain, a small flame in red glass. Over the door, cut in the stone, **the line in Church Slavonic**. | footsteps on stone; the lamp's chain | `VOL_LZS_03` at 0.5 ("A crypt? There's no crypt on the inventory. So that's where they keep the silver.") | grade: inline, warm from the lamp (exposure 0.9, saturation 0.7, tint [1.08, 0.96, 0.84], vignette 0.5) |
| 19 | 122.0 | 7 | D the crypt door | fov 40, `static` on the inscription, the lamp's flame at the frame's edge, blur 0.3 | The letters, close. Volkov's lantern comes up to read them. Behind him on the stair, allowed down to see what they do, Serafim reads it first, from memory, in the old tongue. | the lamp; breathing | `SER_LZS_05` at 0.5, in Church Slavonic ("What was closed on the fourth day, let no one open."); `VOL_LZS_04` at 4.2 ("Church Slavonic. 'What was closed on the fourth day...' Well, well.") | |
| 20 | 129.0 | 8 | E the crypt | fov 65, `crane` down from the door's lintel into the room, arc 1, ease `out_quad` | The crypt: a vaulted room the size of a kitchen, a stone altar step, nothing on the walls. On the step, alone, a small vessel the length of a forearm: dark metal, a wax seal gone grey, a cord. No silver anywhere. The brigade men fill the door and go quiet. | — | `VOL_LZS_05` at 2.5 ("Everyone, look. Here is your holy relic. I'll show you now that there is nothing inside it.") | |
| 21 | 137.0 | 7 | E the crypt | fov 45, `static` on Serafim in the doorway between two brigade men | Serafim, not pleading, asking. He uses the young man's first name as a priest would. | — | `SER_LZS_06` at 0.4 ("Arkady. Son. I am asking you. Not for God's sake. For your own."); `SER_LZS_04` at 4.0 ("There is nothing down there that you need. And there is something there that you don't.") | |
| 22 | 144.0 | 8 | E the crypt | fov 32, `dolly` in slow on **Volkov's hands and the vessel** on the step, 1.2 m to 0.6 m, ease `in_sine`, blur 0.6 (shallow) | His hands. The knife under the wax. The wax lifts in one grey curl. The cord. The lid. [breathing heavily] | the wax; his breath; the lamp | `VOL_LZS_06` at 0.5 ("The seal... wax. Old wax. There.") | |
| 23 | 152.0 | 6 | E the crypt | fov 30, `static`, **close on the vessel's mouth** in the lantern's light, hold the full 6 s, blur 0.7 | **The blood is still wet.** A dark liquid that moves when the lantern shakes, catching the light the way only something wet does. No smell of dust. [gore: with Gore full the inside is red and a drop runs down the lip onto the stone; with Gore low or off it reads only as dark and wet, and nothing runs] | silence; the lamp's flame ticks once | `VOL_LZS_07` [whispers] at 2.5 ("It's wet.") | |
| 24 | 158.0 | 6 | E the crypt | fov 50, `static`, the room, Volkov standing up too fast | He recovers in front of the brigade. The clever answer. His voice is wrong. | — | `VOL_LZS_08` at 0.4 ("Paint. It's paint! Priests have faked worse than this. Inventory it and box it.") | |
| 25 | 164.0 | 5 | E the crypt | fov 40, `static` on Serafim in the door; the men move past him | He has stopped asking. He says it to nobody, flat, like a doctor giving a date. | — | `SER_LZS_09` at 0.8 ("There. Now wait. Four days.") | `dip` at the end, 0.6 → **black** |
| 26 | 169.0 | 5 | black | — | **Black.** | silence | — | **card** (title only, hold 4): **The fourth day.** |
| 27 | 174.0 | 7 | F the mortuary | fov 50, `dolly` along a row of iron beds, handheld 0.15, blend 1.0 | The mortuary room off the fever ward of the district hospital: whitewashed, a tiled stove gone cold, a nurse in a white kerchief at the door to the ward with her back to us. Three iron beds at the near end with **sheets drawn up over the faces**, awaiting the cart. A chart on a nail: a date, 18.IV. On the sheet of the nearest, a bandaged hand lies outside the cover. | a clock through the wall; the nurse's shoes | `VOL_LZS_09` at 1.0, off-screen, from the ward ("Three. The ones who handled the vessel. Doctor, what is this? Typhus?") | `ward` |
| 28 | 181.0 | 7 | F the mortuary | fov 35, `static` on the nearest sheet, hold | **The sheet moves.** Once, at the chest, as if someone under it had drawn breath. Then the bandaged hand turns over. **Cut before anything sits up.** [gore: a stain spreading on the sheet at the bitten hand; off with Gore off] | the sheet; a bed spring | — | |
| 29 | 188.0 | 8 | G the cordon | fov 24, `static`, long lens across a snowfield at night, blend 0.8 | A late snow has turned the thaw back. **The OGPU cordon**: a line of men in greatcoats and winter caps with rifles slung, forty metres apart, their backs to us, facing a village; a field telephone on a post; a fire in a drum. Beyond them, at the end of the road, **Chetverodnevo burns**, the church's stump black against it. Figures move in the fire's light far off, walking. We cannot tell whose. | the wind (`wind_howl`); the fire; far off, no screams, only the fire; `*whispers_far` very faint (the horror pass's Russian whispers, if its key exists; else nothing) | `VOL_LZS_10` at 1.0, on the field telephone, close ("Write: typhus. District quarantine. The village... there is no village. Understood? There is no village.") | `night` |
| 30 | 196.0 | 6 | G the cordon | fov 55, `static` on the church door, a lantern on it | The church door, shut. Nailed over it, a painted board: **ТИФ · КАРАНТИН · ВХОД ВОСПРЕЩЁН** (painted on the prop, not a UI font). A hammer's last blows. Below the board, where a hand took the keys from the lock, the key ring hangs on its nail, untouched. | hammer blows; the fire behind | — | |
| 31 | 202.0 | 8 | H the train | fov 45, `static`, a hard-class compartment at night, a lamp swinging, blend 1.0 | A Moscow train. Volkov on the bench, upright, with a **grey lead case** on his knees and both arms around it. His cap off. Snow going by the window. He is not asleep and will not be. | `a1_train_steam` (-10 dB); the rail joints; the lamp's chain | `VOL_LZS_11` [whispers] at 2.0 ("I wasn't bitten. I wasn't bitten. I wasn't...") | `night`; **music** in: the first bars of the chant bed (T-192's `*chant_bed`, or the Orthodox fragment under it), -16 dB |
| 32 | 210.0 | 8 | A the road (dawn, spring) | fov 32, `dolly` slowly along the same ruts as shot 2, now dry, blend 1.5 | The same road in late spring from the same place: grass, no church, no tower, no houses, a few blackened timbers in the nettles. **Nothing stands.** The rooks. | rooks; wind; the chant very low | — | `memory` |
| 33 | 218.0 | 6 | black | — | Black. **Card.** The chant ends on its held note. | — | — | **card** (title only, hold 5): **Chetverodnevo is not on any map.** `fade_at` 222, `end` black → the main menu |

Running length 224 s with the cards (the work order's "about 3 minutes"). Lines heard: SER 01–09, VOL 01–11, BRG
01–03, 06–08 (BRG_04 and _05 are the brigade's other two slogans for the horror pass's menu / Archive use and for a
longer cut; T-194 may play them under shots 5–6 if the road needs more).

## 2. "FOURTH DAY" — October 1944   ~95 s

East Prussia, the German line in the rain, October 1944; four days later the field grave. Plays as the **opening of a
new campaign start** (before Map 0's GRAVELIGHT ONE, which follows it after its black) and from the Archive. No squad
(`cast: false`). Grade opens `storm`. Bed: `*rain_field` (rain on canvas and mud) under far guns (`war_artillery_boom`
at -14 dB). The Soviet officers are three: Volkov (forty now, grey at the temples, a state-security colonel's shoulder
boards (NKGB by 1944), the cornflower-blue cap with the maroon band under a rain cape) and two Red Army officers of the
division (gymnastyorka and shoulder boards under plash-palatka rain capes, an ushanka and a pilotka); none of them is a
real person and nobody's rank or unit is said, except that one of the Returned repeats a division number
(`RTN_CLOSE_04`), a number not meant to identify any real formation.

| # | t | dur | set | camera | what is seen | sound | lines | grade / card |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.0 | 6 | black | — | Black. Rain. | `*rain_field`; far guns | — | **card** (at 0.8, hold 5): **EAST PRUSSIA** / *the East Prussian line · the German line* / *October 1944  ·  rain* |
| 2 | 6.0 | 9 | I the German line | fov 28, `dolly` along a flooded trench at waist height, slow, handheld 0.25, blur 0.35 | **Rain, mud, a German line**: a trench of brown water, a sandbagged MG position under a tarpaulin, a field telephone wire, a church spire with no roof far off in the rain, a dead horse in the wire (no close-up). Helmets move under the parapet. No faces close. | rain; a Spandau's cover being dragged; German voices too far to make out | — | `storm` |
| 3 | 15.0 | 8 | J the OP | fov 50, `static`, inside a dugout, looking out of its slit past three heads in capes | **The Soviet observation post**: a dugout roofed with logs, a trench periscope, a field telephone, a map in oilcloth. Two army officers with binoculars. Between them, not looking through anything, **Volkov**, his hands in his cape. The telephone. | rain on the logs; the telephone's buzz | `SVR_FTD_01` at 1.5 (the handset, Front HQ: "'Birch', this is 'Don'. Has Moscow's instruction been received? Over."); `VOL_FTD_01` at 5.0 ("Received. The batteries are loaded with the special rounds. We begin on the signal.") | |
| 4 | 23.0 | 6 | J the OP | fov 35, `static` on the telephone handset in Volkov's hand, his face in the slit's light behind | He gives the handset to the colonel without a word. The colonel's order is HQ's. | — | `SVR_FTD_02` at 0.6 ("Fire when ready. The specials: three salvoes, no more. Over.") | |
| 5 | 29.0 | 9 | I the German line | fov 24, `static`, the long lens from the Soviet side onto the German trench 600 m off, shake [[2.0, 0.3], [2.7, 0.3], [3.3, 0.25]] | The salvo. **The shells hit and don't explode properly**: no fireball, no splinters. Each lands with a thud and opens like a seed pod in a low, dirty brown puff that lies down in the rain instead of rising. The men in the trench look at them. One pokes at a casing with a rifle. | the guns behind us (`war_artillery_near`), the shells' wrong, soft bursts (`*shell_soft`), then only rain | — | |
| 6 | 38.0 | 7 | J the OP | fov 45, `static` two-shot, Volkov and the colonel at the slit | The colonel lowers the binoculars and asks with his face. Volkov answers without taking his eyes off the trench. | — | `VOL_FTD_02` at 0.5 ("No. They aren't supposed to burst. They only need to open."); `VOL_FTD_03` at 4.0 ("Blood. Volunteers'. More than that you are not cleared to know, Comrade Colonel.") | |
| 7 | 45.0 | 6 | black / caption | — | **Black**, the rain continuing under it. **Card** (title only): **Four days later.** | rain, then silence | — | **card** (title only, hold 4) |
| 8 | 51.0 | 8 | K the field graves | fov 60, `crane` up from the mud over a row of fresh mounds, arc 1.5, ease `smooth`, blend 1.0 | Morning, no rain, low cloud. **A field grave**: a row of mounds behind an aid station's tents, a wooden pyramid marker on each with a tin star and a pencilled name under a scrap of glass, a shovel still in the heap. Red Army soldiers at a field kitchen with their backs to it. | the kitchen; a kettle; crows | `SVR_FTD_03` at 1.0 from a set on the kitchen's cart ("'Don', this is 'Birch'. The enemy in front of us is not answering. The line is empty. Over.") | `cold` |
| 9 | 59.0 | 8 | K the field graves | fov 35, `static` low on **one mound**, the marker in frame | **The earth moves.** A clod rolls. A ridge rises along the mound's spine and the marker leans. The soldiers behind, one by one, **turn to look at it**. Nobody reaches for a rifle. Not yet. | the earth (`emerge_dig_earth`, `emerge_burst_earth` at 6.5) | `RTN_CLOSE_01` at 6.8, from inside the earth, muffled ("Mama.") | |
| 10 | 67.0 | 7 | K the field graves | fov 50, `static` on the soldiers' faces, the mound out of focus behind them | Their faces. Boys. One takes off his cap. One crosses himself and looks round to see who saw. The sergeant's hand goes to his rifle sling and stops there. | a hand comes out of the earth (sound only); the kettle boils over | `SVR_FTD_04` at 1.5, the set on the cart ("All stations. Our dead... are getting up. This is not panic. I can see them. Over."); `SVR_FTD_05` at 5.0 ("This is 'Don'. Cease transmission. Not one word of this on the air. Write: an epidemic among the enemy. Out.") | |
| 11 | 74.0 | 14 | L the road west | fov 24, `dolly` very slow, parallel to the road from 40 m, the long lens flattening them into one line, ease `linear`, blend 1.2 | **The last shot: a long line of the risen walking west in greatcoats past their own guns.** Dozens, in the road and beside it, greatcoats stiff and white with frost, some bareheaded, some in burial wrappings, boots missing, walking the way men walk who are very tired. Past a battery of 76 mm guns whose crews stand off and let them pass. One gunner holds out a hand as if to stop a friend, and takes it back. Nobody shoots. | boots and bare feet in the mud; the wind; very low, the horror pass's Russian whispers (`*whispers_far`); the chant bed enters at 6.0, -18 dB | `VOL_FTD_04` at 2.0, off, close to the microphone ("The fourth day. Always the fourth."); `VOL_FTD_05` at 8.0 ("They don't know whose they are. They just walk. West.") | `cold` → inline at 10.0: saturation 0.4 |
| 12 | 88.0 | 7 | black | — | Black. | the chant's held note | — | `fade_at` 86.5, `end` black → a campaign start goes on to GRAVELIGHT ONE (§4); the Archive returns to the gallery |

## 3. "STAUB" — Kaltenbrunn, 20 December 1944   ~64 s

The dust mill on the night of the Erwachen. Plays as **Kaltenbrunn's arrival** (on map01's load, standalone or from
the Map 0 exfil, before the arrival grace) and from the Archive. No squad in the picture (`cast: false`; the squad
is on the road, not here yet). Grade `violet` at its low end (lift 0.012 only) opening to `cold` on the hill. Bed:
the Staubmühle (`*mill_bed`: a ball mill turning, a fan, a Geiger-like tick that is the resonance meter). Every
German line is subtitled; Reinholt is REI, the plant's loudspeaker and the weather station's intercom are PA.

| # | t | dur | set | camera | what is seen | sound | lines | grade / card |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.0 | 5 | black | — | Black. The mill under it. | `*mill_bed` | `PA_STB_01` at 0.8 ("Attention. Dust mill two, canning begins. Masks on. Masks on.") | **card** (at 0.6, hold 4.5): **KALTENBRUNN** / *Staubmühle II · Projekt Wiederkehr* / *20 December 1944  ·  21:50* |
| 2 | 5.0 | 7 | M the dust mill | fov 32, `dolly` along the sifter's glass front, 2 m, handheld 0.2, blur 0.4, blend 0.8 | **The violet powder**: a fine dust sliding down a glass-fronted sifter into a hopper, lit from inside the machine, so fine it hangs. Men in rubber masks and gauntlets at the hopper. A canister under it fills. Nothing on the walls but a Wiederkehr mark and a lot number board. | the mill; the sifter's rattle | — | `violet` (low) |
| 3 | 12.0 | 7 | M the dust mill | fov 45, `static`, **Reinholt at the gauges**: a bank of three dials (fineness, resonance, temperature) and a clock | Reinholt in a white coat over her dress, hair pinned, a pencil. **She watches the gauges**, not the men. The resonance needle sits high. She writes a number. | the resonance tick quickens | `REI_STB_01` at 0.5 ("Fineness twelve microns. Through the mill once more. The dust must float, not fall."); `REI_STB_02` at 4.6 ("Near the Heart it no longer waits four days. Minutes. Write it down: minutes.") | |
| 4 | 19.0 | 7 | N the north ramp | fov 40, `dolly` along a rail of canisters, handheld 0.3, blend 0.6 | Outside, in the snow, under floodlights: **the canisters loaded onto rockets aimed east**. Six squat rockets on a rail frame, each with a steel canister clamped under its nose, a crew in winter whites; the rail points at the black line of hills. The rockets are placard-level (no markings but a lot number; ART rule as Morgenrot). | the floods' hum; a wrench; snow | `REI_STB_03` at 1.0, off, from the control hut's open door ("The canisters go east. Return to sender. That was the General Staff's phrase, not mine."); `PA_STB_03` at 5.0 ("Launch in sixty seconds. Clear the north ramp.") | `cold` |
| 5 | 26.0 | 7 | O the weather station | fov 55, `static`, the hut's lit window on the hill, the anemometer's cups and **the wind vane** in silhouette on its mast against the valley's lights | A hut on the hill above the plant with an anemometer and a vane on a pole; below it in the dark, **the lights of the villages**: Kaltenbrunn village in the valley, Wilcza Góra across it, a dozen farms, a lamp at the Kreuzweg's crossroads far north-west. The vane points steadily east, into the wind from the west. | the wind; the cups spinning | `REI_STB_04` at 0.5, on the intercom ("Weather station, confirm the wind."); `PA_STB_02` at 2.4 (the weather officer: "Weather station to control. Wind from the west, three metres a second, steady. Clear to proceed.") | |
| 6 | 33.0 | 6 | N the north ramp | fov 24, `static`, long lens from the hill onto the ramp, shake [[1.0, 0.5], [1.6, 0.4], [2.2, 0.4]] | The launch, seen from the hill: **six streaks going east** over the hills, low, their exhaust lighting the snow. The crews watch them go. | `*rocket_salvo` (six whumps and a tearing), then the wind | — | |
| 7 | 39.0 | 7 | O the weather station | fov 35, `static` on **the wind vane**, hold the whole shot | **The weather report going wrong.** The cups slow, stop, and start the other way. **The vane swings**: a quarter turn, a hesitation, then round, until it points west. The cups race. | the cups; the mast's wire singing (`wire_buzz`) | `PA_STB_04` at 1.5 (the weather officer, rising: "Control, weather station. The wind is turning. East. Wind from the east, rising. Control, abort! Abort!") | |
| 8 | 46.0 | 8 | O the weather station | fov 50, `dolly` slowly toward the window and the valley beyond, ease `in_sine` | **The dust coming back over the hills**: on the eastern ridge line a violet haze, lit from inside by nothing, rolls down toward the valley like a slow wave, and **the lights of the villages go out one by one** as it reaches them: the eastern farms, then Kaltenbrunn village, then Wilcza Góra, then the lamp at the crossroads. The plant's floods are the last lights left. | the wind; `PA_STB_05` under it; the chant bed's low fragment (-20 dB) | `PA_STB_05` at 0.4 ("Attention. Dust alarm. Close all doors. This is not a drill."); `PA_STB_06` at 4.6, the weather officer, fading ("...Control, please answer. Control. The lights in Wilcza Góra are... Control?") | `violet` rising to full over the shot |
| 9 | 54.0 | 6 | P the Heart (Core Vault) | fov 40, `static`, Reinholt's hand on the Heart's dial, the violet from below, blend 0.8 | **That same night, the other thing that was true**: Reinholt alone at the Heart's console in the Core Vault, her hand turning the resonance to its stop, the pencil still behind her ear, her face lit from below. She is not looking at the gauges now. | the Heart's hum (`pylon_hum` pitched, or `nachtglas_layer`); the alarm far above | `REI_STB_05` [whispers] at 0.4 ("No. No, not today. Not tonight."); `REI_STB_06` at 3.2 ("Liesl. Mama is here. Count to a hundred.") | `violet` |
| 10 | 60.0 | 4 | black | — | Black. The hum climbs and stops. | — | — | `fade_at` 59.0, `end` black → Kaltenbrunn's arrival banner and the match |

## 4. "GRAVELIGHT ONE" — Map 0's crash, rebuilt   ~78 s

Inside the C-47 over the front at night, 23 December 1944, 23:10 to 23:41. Plays on **Map 0's first match start**
(standalone and campaign), ahead of the inn opening (T-072/T-076), whose title card and settled view then follow
exactly as built: this cutscene ends in black and hands the player their own eyes at the inn's spawn with nothing
about the opening's timings, the look rule or round 1 changed. Also in the Archive. **The squad is the players'
chosen characters** (CinemaCast; bots and the empty seats fill in from the four so there are always four passengers:
the stand-ins of anyone not in the match are built like the bots'). The cast needs one new thing from T-194: a
`sit` pose (`squad: {"sit": [[x, y, z, yaw], ...]}`) for the bucket seats; failing that, shots 3, 6 and 9 are shot
from behind or on hands and the window, and never need a seated face. Grade `night`. Bed: the engines
(`*c47_engines`, two radials in sync, dropping out at 10), the airframe (`kranich_creak`, `kranich_rattle`), wind.
Selwyn is on the intercom (the radio chain, as his SEL lines are), the squad's lines are shouted over the engines.

| # | t | dur | set | camera | what is seen | sound | lines | grade / card |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.0 | 6 | black | — | Black; engines. | `*c47_engines` | — | **card** (at 0.6, hold 5): **GRAVELIGHT ONE** / *a C-47 out of Brindisi · over the Silesian front* / *23 December 1944  ·  23:10* |
| 2 | 6.0 | 8 | Q the C-47 cabin | fov 60, `dolly` aft to forward down the cabin's centre at seated head height, handheld 0.4 (the airframe), blend 0.8 | **Inside the C-47**: bucket seats along both walls, the static line, cargo lashed under a net, a red dome lamp, frost on the inside of the skin. The four passengers strapped in on the port side with their kit between their boots. Nobody is talking. One is asleep or pretending. | engines; the airframe's rattle | `SEL_GL1_01` at 1.0, intercom ("Pilot to passengers. We've crossed the Silesian border, twenty-three ten. Forty minutes to the drop. Stay strapped in, there's weather.") | `night` |
| 3 | 14.0 | 8 | Q the C-47 cabin | fov 45, `static` over a passenger's shoulder at **the window**, blur 0.3 on the shoulder | **Through the window: flares.** The ground 600 m down, snow, black woods, a river. White parachute flares hang over it in a line, and under them, **columns of figures walking west in the snow**, hundreds, in no formation, past gun pits and burning vehicles, and nothing fires at them. | `war_flare_pop` far, twice; the engines | `SEL_GL1_02` at 0.5 ("Navigator says that's the front below us. Those are their flares, not ours. Have a look if you like. Then don't.") | |
| 4 | 22.0 | 9 | Q the C-47 cabin | fov 35, `static`, closer on the window, the glass frosted at the edges, a flare lighting the cabin white for a second (light event: a white omni at the window, energy 2.5, range 4, fading) | The columns, closer under a flare: greatcoats, bare heads, the walk. A German battery under them in the snow, its crews standing off. Then a Soviet gun line further east, firing west, over the heads of the walkers. **Both armies and the dead between them.** | `war_artillery_boom`; `war_mg_distant`; `war_flare_pop` | squad `*_GL1_01` at 1.0 (the character at the window, whoever it is: Dutch "That ain't a parade down there. Those are people. Hundreds of them. Where the hell are they going?" / Peg "Soviet greatcoats. Walking west, no formation, no weapons. Pilot, those men are walking through their own artillery." / Deacon [whispers] "Yea, though I walk through the valley... Lord, they are walking. Look at them walk." / Wren "Russians. Hundreds. Walking into German guns and the guns are not firing. ...Nothing about this is right."); `SEL_GL1_03` at 5.5 ("Someone with glasses tell me what those columns are. On the snow. Walking west. Nobody down there is shooting at them.") | |
| 5 | 31.0 | 7 | R the cockpit | fov 55, `static` from the cockpit doorway over Selwyn's and the co-pilot's shoulders onto the windscreen | **Selwyn** in his sheepskin and leather helmet, the co-pilot beside him, the instrument panel's dim red. Ahead through the windscreen: the dark hills, snow, and **a violet light** low on the horizon, bearing 040, a thread first, then a column. | the engines; the intercom's click | `SEL_GL1_04` at 1.5 ("Light ahead, bearing oh-four-oh. Violet. That's no flare.") | |
| 6 | 38.0 | 7 | Q the C-47 cabin | fov 50, `static`, the four faces along the port wall, lit violet from the starboard windows | The violet comes through the starboard windows and lies across their faces. One checks a watch. The dome lamp dims. | the engines falter once; a watch (sound: nothing; the point is it has stopped) | squad `*_GL1_02` at 0.8 for a second present character (Deacon "Hold my hand, if you want to. I don't mind." / Wren "Count with me. Jeden, dwa, trzy... it helps. Cztery..." / Peg "Nobody breathe. Heads down, hands on the frame." / Dutch "Hang on. Hang on, hang on—") | `night` → `violet` over 3 s |
| 7 | 45.0 | 7 | R the cockpit | fov 40, `static` on the panel and Selwyn's hands, shake [[1.5, 0.6]] | **The violet column** fills the windscreen. **The engines die**, both at once: the needles fall, the panel's lamps go out, the propellers windmill. Selwyn's hands do everything right in the dark. | **the engines stop** (the bed cuts to the airstream only: `wind_howl` rising, `kranich_wind_gust`), the props windmilling (`*prop_windmill`) | `SEL_GL1_05` at 0.4 ("Both engines— ...Both engines gone. Instruments dead. Hold on to something, chaps. I'm going to put her down.") | `violet` |
| 8 | 52.0 | 8 | S the glide (exterior) | fov 32, `dolly` alongside and a little below the gliding C-47, the camera 30 m off its port wing, the ground coming up, ease `linear`, handheld 0.1 | Outside for one shot: the dark aircraft, props turning slowly, no lights, **gliding** down over a snowfield with the violet column behind it. Ahead and below, a crossroads, a stable, and **the inn's lit windows**, every one of them warm, the only lamplight for miles. | the airstream; the far war (`war_artillery_boom`, -16 dB) | `SEL_GL1_06` at 2.0 ("There's a building. Lit windows. I'll take the field beside it. Brace. Brace. Brace!") | `night` |
| 9 | 60.0 | 6 | Q the C-47 cabin | fov 65, `static` low from the cabin floor looking forward, handheld 0.7, shake [[3.8, 1.0], [4.4, 0.9], [5.0, 0.7]], roll 0 → -8 | The cabin from the floor: boots, hands on the seat frames, heads down, the net straining. **The crash**: the first touch, the second, the floor jumps, the lamp goes, cargo breaks loose across the frame, the picture whites out in snow through a torn skin. | `war_crash_boom`, metal (`hull_groan`, `a1_sheet_rattle`), snow, glass | squad: no words, breathing (no new line; the bake's breaths) | `cut` to **black** at 5.2 |
| 10 | 66.0 | 7 | black | — | **Black.** Ringing silence, then the small sounds come back: a fire starting, a ticking, the wind. | `fire_crackle` growing; `amb_wind_gust` | `SEL_GL1_07` at 1.5, faint, from the nose ("...Is anyone... I can't move my legs. Get out. Get out before she burns."); `SEL_GL1_08` at 4.8 ("Co-pilot's gone. Leave me. Go on. ...God bless.") | |
| 11 | 73.0 | 5 | black | — | Black into the inn opening. | the wind | — | `end` black at 78 → **the existing match start**: the inn opening's title card GASTHAUS ZUM KREUZWEG / the Crossroads Inn · 9 km northwest of Kaltenbrunn / 23 December 1944 · night over the player's own settled view, exactly as T-184 built it |

The squad's `*_GL1_01` lines are spoken by **the character at the window** (the first human player's character; solo,
yours), `*_GL1_02` by one other character present (bots count). Each character has one of each, so no two players
hear the same line twice. Selwyn's eight lines are the spine; the squad's are few and frightened on purpose.

## 5. The Moscow 1953 epilogue card   ~22 s

After the Fernflug canon ending (KÜNDIGUNG) and its credits, before the return to the menu. **Not voiced**: cards and
one image; no narrator (contract C3 prefers cards without a voice). Dread, not a sequel advert: no music but the
chant's last note held and let die; no Operator; nothing moves except the hand. Grade `memory` at half strength.

| # | t | dur | set | camera | what is seen | sound | card |
|---|---|---|---|---|---|---|---|
| 1 | 0.0 | 5 | black | — | Black. | a vault's silence; a ventilation fan far off | **card** (at 0.5, hold 4.5): **MOSCOW** / *Laboratory No. 4 · the vault* / *1953* |
| 2 | 5.0 | 10 | T the vault | fov 40, `dolly` in 1.5 m to 0.9 m over 10 s on the case, ease `in_sine`, blur 0.6 | A steel shelf in a concrete vault, one bulb in a cage. On the shelf, **the grey lead case** from the train, its paint worn to the metal at the corners by twenty-three years of hands. **An old man's hand rests on it**: liver spots, a signet ring, the cuff of a good suit, no uniform now. The hand does not lift. The fingers tighten once, as if the case had moved. | the bulb's hum; the fan; the chant's last note, very low | — |
| 3 | 15.0 | 7 | black | — | Black. Two cards, the second after the first has gone. | the note dies | **card** (title only, hold 3): **The vessel is still there.** → **card** (title only, hold 3.5): **It is still wet.** then `end` black → the menu |

---

## 6. SETS

Every set is a small stage scene of its own (`gravelight/world/cinema_sets/<id>.tscn`, loaded only for the cutscene,
freed after; the director's `map` is the stage root, so `target` / `rel` / `light` resolve against it). Nothing here
is a play space: no navmesh, no colliders beyond what the people stand on, no spawns. Period-correct and plain.
**Existing** = already in the game and reusable as is or re-dressed; **new/free** = a free CC0 / CC-BY asset (credit
in `assets/*/SOURCE.txt`) or our own geometry; the generators' kit (gen_map00's timber, planks, snow, fences, the
wayside shrine, the signpost, lanterns; gen_map01's tin sheds, floods, rails, pipework, the Core Vault's console; the
Fernflug acts' huts and instruments) covers most of it.

### 6.1 Lazarus Saturday (sets A–H)
| set | what it needs | from |
|---|---|---|
| **A the road** | 120 m of rutted village road in thaw: brown standing water in the ruts, dirty snow in the ditches and under the fences, birches both sides, log houses (izby) with carved window frames and thatch or plank roofs, wattle fences, a well with a sweep, a dog, rooks. Shot 32 is the same road in late spring: grass, nettles, four blackened sill-logs, no buildings. | road, mud and snow materials from Map 0's Grounds (existing); izby **new/free** (a CC0 log cabin kit re-roofed, or gen_map00's timber kit: log walls are a stacked-cylinder loop); birches **new/free**; well and fences our own |
| **B the church porch** | A wooden parish church (not grand): a log nave on a stone undercroft, plank cladding weathered grey, a west porch with three steps, a double door with iron straps and a ring lock, a small onion dome on the nave ridge (dull metal, not gold), a plain wooden cross on it. Icons are **never shown** close (the door is shut throughout; respect, and no copyrighted icon art): the only church furniture seen is the lamp in the crypt. | **new/free** (a CC0 wooden church or our own loft; the Fernflug Act I church (map04a `ambient_map04a_church`) is Catholic and stone, not a match, but its door and steps can be reused) |
| **C the bell tower** | A separate tent-roofed (shatrovy) wooden bell tower beside the church, 14 m, an open belfry with a rail, one bronze bell (about 60 cm, a yoke, a rope), shingled tent roof. It must come down: a pre-fractured version (base charge: the bottom 2 m breaks out, the tower leans 15 degrees, folds at the belfry and falls toward the road in a dust plume), the stump after. The bell as a separate prop with a crack state (a dark seam, a dent). | bell: Map 0's radio egg bell / Totenhafen's church bell mesh (existing); tower **our own** geometry (a loft, two states + the fall as a tween or baked keys); dust: the existing explosion / `amb_m1_dust` particles |
| **D the crypt stair** | A stone stair down from a trapdoor in the nave floor, 12 steps, whitewash gone to stone, a low door with a bar, and over it on a chain **the lamp** (a lampada: a red glass cup in a brass holder, a small flame, never out), and above the door the line cut in the stone in Church Slavonic (**"Є́же затвори́ся въ де́нь четве́ртый, никто́же да отве́рзетъ"**, the bible's text and orthography, LAZARUS §1.3 and §12: a texture on the lintel, our own, the same letters as `SER_LZS_05`'s speech; the exact letters are not read by the player and the subtitle gives the English). | Kaltenbrunn's Salt Chapel stone and candle kit (existing); the lamp **our own** (a small loft + the candle flame shader) |
| **E the crypt** | A vaulted room 4 x 5 m, a single stone step before a bare stone altar slab against the east wall, nothing on the walls (the watchers kept nothing here but the lamp and the vessel). **The vessel**: 35 cm, dark bronze or pewter, a cylinder with a domed lid, a grey wax seal over a cord, no inscription, no cross on it (it is a vessel, not a reliquary of a saint); its open state shows a dark wet interior (gore: red with a running drop; off: dark and glossy). A lantern (kerosene, 1920s) and a knife for Volkov. | the Salt Chapel's vault kit (existing); the vessel **our own** (two states) |
| **F the mortuary** | The mortuary room off the district hospital's fever ward (the three died on 15.IV and rise on the night of 18.IV, so they lie here and not in a ward): whitewashed plaster, a tiled stove gone cold, three iron beds without blankets and an empty fourth, enamel basins, a chart on a nail (pencilled date 18.IV.30), a window with frost, an oil lamp, a door ajar to the lit ward. Three beds with sheets over the faces; one sheet animated (a breath at the chest, a hand turning). A nurse's back in a white kerchief and apron, in the doorway. | Kaltenbrunn's Barracks beds and stove (existing, re-dressed white); the sheet **our own** (a cloth mesh with two shape keys) |
| **G the cordon** | A snowfield at night (a late snow over the thaw), a line of men in greatcoats and winter caps with slung rifles 40 m apart, a field telephone on a post, a fire drum, a sledge; 300 m off, the village burning (fire cards, embers, the church's stump), far figures walking in the firelight (the horror pass's distant walkers, T-192's MultiMesh, if landed; else six low-poly silhouettes on a path). The church door with the painted board **ТИФ · КАРАНТИН · ВХОД ВОСПРЕЩЁН** nailed over it and the key ring on a nail. | Map 0's snow, fences, fire and ember effects (existing); the board **our own** texture |
| **H the train** | A 1930 hard-class compartment at night: varnished wood benches, a luggage rack, a swinging oil lamp, a window with snow going by (a scrolling card), a door with a brass handle. The grey lead case (40 x 25 x 25 cm, dull, two hasps, a rope handle). | Act I's Bahnhof carriage interior (map04a, existing) re-dressed; the case **our own** (it returns in §5) |

### 6.2 Fourth Day (sets I–L)
| set | what it needs | from |
|---|---|---|
| **I the German line** | 200 m of trench in rain: flooded trench floor, sandbags, duckboards, a tarpaulin over an MG position, telephone wire on stakes, barbed wire, a dead horse in it (far), shell holes full of water, a roofless church spire 1 km off, a wrecked assault gun as a silhouette (placard level; no markings). The "soft shells": a shell burst effect that is a thud, a low brown puff and no flash. Rain: the Totenhafen storm rain (`ambient_map02_storm`) over a field. | Fernflug Act I's trench and sandbag kit (existing), Totenhafen's rain (existing), wire and stakes (Map 0's MG nest, existing) |
| **J the OP** | A dugout: log roof, an observation slit with a trench periscope, a field telephone (Soviet UNA-F type, a wooden box with a handset), a map under oilcloth, a candle in a tin, three officers in rain capes. | Act I's bunker interior (existing); the telephone and periscope **our own** small props |
| **K the field graves** | Behind an aid station's tents on a morning of low cloud: a row of eight mounds, each with a wooden pyramid marker, a tin star on top and a pencilled name under glass (the star is a period grave marker, shown with respect, never framed as a symbol), a shovel in the heap, a field kitchen (a towed boiler) with a kettle, a cart with a radio set (a wooden box, a whip aerial), eight soldiers at the kitchen. One mound animated (the earth lifting: the zombie emergence effect `emerge_*_earth` re-coloured to mud). | Map 0's / Kaltenbrunn's emergence effects (existing); tents and kitchen **new/free** or our own |
| **L the road west** | A muddy road at morning with a battery of four 76 mm field guns (ZiS-3 silhouettes, placard level) beside it and their crews standing off; thirty to sixty **risen in greatcoats** walking west in a loose line (the horror pass's Soviet risen skins on the zombie rig in a scripted walk along a spline, frost-white, some in burial wrappings, boots missing; no AI, no hitboxes). | T-192's skins (existing after the horror pass); the guns **new/free** (a CC0 ZiS-3) or our own |

### 6.3 Staub (sets M–P)
| set | what it needs | from |
|---|---|---|
| **M the dust mill** | Inside Kaltenbrunn's Laboratory Wing or a mill hall off the Generator Hall: a ball mill (a riveted drum on rollers, a motor, a belt), a glass-fronted sifter with violet dust sliding in it (the Nachtglas mote material animated as a fine fall), a hopper, a canister under it, a bank of three gauges and a clock, a lot-number board, the Wiederkehr mark stencilled once; men in rubber masks and gauntlets. Reinholt's white coat. **No eagle, no flag, no runes.** | Kaltenbrunn's Lab Wing and Generator Hall kit (existing), the Nachtglas mote shader (existing); the mill and sifter **our own** |
| **N the north ramp** | Outside in snow under floodlights: a rail frame launcher with six squat rockets (placard level: a tube, fins, a nose with a clamped steel canister; think a heavy Nebelwerfer frame, no markings), a crew in winter whites, a control hut with an open door, the hills east. The launch is six streaks (the Morgenrot exhaust effect, scaled down) over the ridge. | Map 1's Minehead Yard floods, snow and sheds (existing); the frame and rockets **our own** loft (Morgenrot's rocket parts, scaled) |
| **O the weather station** | A hut on the hill above the plant (a Wetterwarte: a plank hut with a lit window, an instrument screen, an anemometer with cups and a wind vane on a 6 m mast). Below, the valley at night with the villages' lights (lit cards on the landscape: Kaltenbrunn village, Wilcza Góra, farms, the Kreuzweg's lamp far north-west), each switchable so they go out one by one. The violet haze: a volumetric fog bank that rolls down from the eastern ridge (Map 1's fog volume with the violet tint). | Fernflug Act III's radar hut and Map 0's landscape with lit window cards (existing); the vane and cups **our own** (animated: the swing in shot 7) |
| **P the Heart** | Kaltenbrunn's Core Vault as built (the Heart, the console, the dial): reuse the Requiem ending's camera positions (campaign.json / the Requiem runner) for the console. | existing (map01) |

### 6.4 Gravelight One (sets Q–S)
| set | what it needs | from |
|---|---|---|
| **Q the C-47 cabin** | The intact interior of the hull T-126 built as a wreck (gen_map00 `build_wreck_hull` / `_dress_wreck_hull`: the ribs, planked floor, bucket seats along the port wall, the static line, the cargo net and crate, the choked cockpit doorway): built **whole** this time, both walls' bucket seats, the round windows (eight a side), a red dome lamp, frost on the skin, the cargo lashed; the floor must take the shake and the roll; the cargo breaks loose at the crash (three crates on a tween). The window view is a sky-dome and a scrolling ground card 600 m down: snow, woods, a river, gun pits, burning vehicles, flare lights (point lights on parachutes drifting down), and the walking columns (T-192's distant walkers as a MultiMesh on the card, or 200 billboard figures in a loose file). | the wreck's dressing (existing, mirrored and completed); the ground card **our own** |
| **R the cockpit** | The pinned cockpit's seats and panel from `LandscapeProps.pinned_cockpit` (existing), **intact**: two seats, the panel with lit red instruments whose needles can fall and lamps go out, the control columns, the windscreen frame with glass. Selwyn (people.json `selwyn`, existing: sheepskin, leather helmet) in the left seat, a co-pilot (a kit variant of Selwyn's, no face shown close) in the right. Outside the windscreen: the sky-dome, the hills, the violet column (Map 0's distant-war flares and the Kaltenbrunn violet beam effect, existing). | existing (re-posed) |
| **S the glide** | One exterior: a whole C-47 (the wreck's hull mesh made whole: nose, both wings, both engines, the tail, props that turn) gliding over Map 0's own landscape toward the inn; the camera flies beside it. Use Map 0 itself as the stage for this one shot (the inn, the stable and the lit windows exist; the aircraft is a one-shot prop on a spline that ends where the wreck lies). | Map 0 (existing); the whole C-47 **our own** from the wreck's parts (PlaneModels has a Mosquito and a B-29; a Dakota loft is the same kit) |

### 6.5 The epilogue (set T)
| set | what it needs | from |
|---|---|---|
| **T the vault** | A concrete vault 3 x 3 m, one caged bulb, a steel shelf, the lead case from set H (aged: paint worn at the corners), an old man's hand and cuff (a hand mesh from people.json's hands, aged skin texture, a signet ring, a good dark suit cuff; no uniform). | Groom Lake's bunker concrete (existing); the hand our own (people.json `hand_res` 1 hands, re-textured) |

## 7. CAST AND COSTUMES

Period-correct, plain, no caricature. No real person. Insignia exist but are never framed close enough to read, and
no political symbol is ever the subject of a shot. Built as modelled people (people.json rows, `tools/build_people.sh`)
in the PatronBody / stand-in pipeline the inn's patrons and Selwyn already use; posed and walked by the cutscene's
runner (the cast's `place` / `face` / `walk`, plus the `sit` and `kneel` poses this document asks T-194 for).

| who | 1930 | 1944 | notes |
|---|---|---|---|
| **Father Serafim Lebedev** (SER) | 59 (b. 1871), lean, grey beard to the chest, hair tied back; a black cassock (ryasa) worn at the cuffs, a black skufia, a pectoral cross on a chain (plain wood or dark metal, not gold), felt boots in galoshes; a ring of four iron keys | — | never a zombie on screen; his fate is a diary line (T-190). Gentle, unhurried, he looks at people's faces. |
| **Arkady Volkov** (VOL) | 26, clean-shaven, a thin face; OGPU plenipotentiary: khaki gymnastyorka, breeches, black boots, a leather belt and shoulder strap, the OGPU service cap (dark-blue crown, maroon band; check ART_FACTIONS before build), a greatcoat over the shoulders in the cordon, a leather map case, a holstered Nagant **never drawn**; later a civilian coat and cap on the train | 40, grey at the temples, heavier; state-security colonel (NKGB by 1944; the agency is never named on screen or in a line): a tunic with shoulder boards, the cornflower-blue cap with the maroon band, a rain cape; a wedding ring | frightened, clever, ambitious; he never raises his voice except once (LZS 24), and that is the frightened one. In 1953 only his hand. |
| **The brigade** (BRG, ~12) | district Komsomol and League activists: town overcoats and quilted jackets, peaked caps and budenovka-style winter caps, red armbands of plain cloth, two red cloths on poles; crowbars, ropes, a tin speaking trumpet, a wooden dynamite box; the brigade head older, in a leather cap and a leather coat | — | not thugs: tired young people doing a job they were given; the two who take Serafim's arms are never seen doing it |
| **The villagers** (~40) | peasants in sheepskins, quilted coats, shawls, felt boots and bast shoes in the mud, caps off; children | — | kneeling, then pulled up (off camera); no faces in distress close; nobody is struck on screen |
| **The OGPU cordon** (~8) | greatcoats, winter caps (budenovka), rifles slung, felt boots | — | backs to the camera, 40 m apart |
| **The nurse** | a white kerchief and apron over a grey dress | — | her back only |
| **Red Army officers** (2, 1944) | — | gymnastyorka with 1943 shoulder boards under plash-palatka rain capes, an ushanka and a pilotka, binoculars, map cases | fictional; the colonel speaks only through the handset (SVR) |
| **Red Army soldiers** (~8, 1944) | — | greatcoats, ushanki, PPSh and Mosin rifles slung, mess tins | young; one takes his cap off, one crosses himself |
| **The risen** (30–60, 1944 and the C-47's window) | — | T-192's Soviet risen skins: greatcoats stiff and white with frost, bare heads, burial wrappings on some, boots missing | the horror pass owns the look; here they only walk |
| **Dr. Augusta Reinholt** (REI) | — | as built (people.json / her existing model) with a white lab coat over her dress, hair pinned, a pencil | measured, tired; her hands do the acting |
| **The mill crew** (~6) | — | grey work coats, rubber masks and gauntlets, rubber aprons; the ramp crew in winter whites; no insignia at all | |
| **The weather officer** (PA) | — | heard only (the intercom) | |
| **Flt Lt Harry Selwyn** (SEL) and the co-pilot | — | as built (people.json `selwyn`: sheepskin flying jacket, RAF blue-grey trousers, flying boots, a silk scarf, a leather helmet); the co-pilot the same kit without the scarf, never shown close | |
| **The squad** (DUT PEG DEA WRN) | — | their own models and kit as built, with the winter additions the Map 0 arrival already gives them; a parachute harness over the kit in the cabin (a strap set, our own) | the players' characters |
| **Volkov's hand** (1953) | — | an old man's hand: liver spots, a signet ring, a good suit cuff | the only thing of him seen in 1953 |

## 8. BUILD NOTES for T-194 (the Opus builder)

1. **Data, not code, for the timelines.** Put each cutscene's definition in `data/gravelight/cutscenes_lazarus.json`
   (`lazarus_saturday`, `fourth_day`, `staub`, `gravelight_one`, `epilogue_1953`) in the campaign.json `cutscenes`
   shape (`seconds`, `shots[]` with CinemaShot keys, `title`/`subtitle`/`time`/`title_at`/`title_hold`, `fade_at`,
   `fade_s`, `end`, `music`, `grade`), one `_what` per shot copied from the "what is seen" column, so `CinemaDirector.
   validate(def, lines)` and the clip tool (`tools_src/clip_cutscene.tscn --cut=`) work on them unchanged, and
   test_cinema's "every cutscene validates / every target exists in its scene" checks extend to them.
2. **Cards mid-timeline.** The director shows one title card per definition (`title`, `title_at`). Lazarus Saturday
   needs three (the opening, "The fourth day.", the last), Fourth Day two, the epilogue three. Add a per-shot `card`
   event (`{"title", "subtitle", "time", "at", "hold"}` → `CinemaOverlay.title_card`, once per shot like `caption`),
   which is the smaller change and keeps one definition per cutscene; or chain definitions (`lazarus_saturday_a`,
   `_b`) with `end: "black"` and the runner starting the next on `finished`. Either way the cards' text is exactly
   §1–§5's. A title-only card (`subtitle` and `time` empty) must draw cleanly (check `title_card` with empty strings).
3. **Stages.** One scene per set group (§6), loaded by a `LazarusCutscene` runner (`gravelight/ui/cinema/` or
   `gravelight/world/cinema_sets/`) that builds the director over the stage with `cast: false` (1930, 1944, Staub) or
   the cast (Gravelight One), and swaps stages at the `dip` cuts (the director's `shot_started` with the shot's
   `_set` key is the hook: free the last stage, instance the next, re-point `director.map`; the dip hides the swap).
   Keep every stage under 150k triangles and no shadows but the lamp's; the Compatibility renderer must play them.
4. **People.** The stand-ins are RemoteBody / PatronBody people built from people.json rows (`serafim`, `volkov_1930`,
   `volkov_1944`, `brigade_a..d`, `villager_a..f`, `nurse`, `rkka_officer_a/b`, `rkka_soldier_a..d`, `mill_worker`,
   `copilot`) through tools/build_people.sh; kits per §7 (make_kits: a cassock is a long coat with no buttons shown, a
   skufia a soft cap, a gymnastyorka a pullover shirt with a stand collar; **no insignia meshes at all**, a flat
   armband strip for the brigade). Poses needed beyond the cast's `place`/`face`/`walk`: `kneel` (the villagers, Serafim
   at 12), `sit` (the train, the C-47, the OP), `hands` (the vessel, the dial, the case: a hand rig close-up is cheaper
   as a separate hands-only prop under the camera than a full body). Serafim is never a zombie, never falls on screen,
   never bleeds on screen.
5. **The window.** Shots GL1 3–4 and 6 look through a cabin window at a ground card. Build it as a 2 km x 2 km plane
   600 m under the cabin, scrolling at 60 m/s along -X, with the walkers as a MultiMesh of 200 greatcoat billboards on
   a 1.2 m/s walk cycle, flare lights on a parachute drift (a `light` event per flare won't do, they need to move:
   a tiny script), and the fires as Map 0's distant-war fire cards. The cabin itself needs the airframe's hand-held
   (`handheld` 0.4) and the roll at the crash.
6. **Gore.** Read `GLSettings.gore` ("off" / "low" / "full"): the vessel's red and the running drop (LZS 23), the
   stain on the sheet (LZS 28) and a dark stain on the mound (FTD 9) draw only on `full`; on `low` the vessel is red
   without the drop; on `off` everything reads as dark and wet. Nothing else in the four cutscenes is gore.
7. **Sound.** New keys marked `*` in §1–§5 go into audio.json through a `gen_audio_*.py` (synthesized, as T-154 and
   T-157 did) or a CC0 pack with its SOURCE.txt; the chant bed and the Russian whispers are T-192's keys (use them when
   they land; validate() will name any missing key). Selwyn's intercom lines play on the radio chain (`SEL` is cast
   there); the squad's `*_GL1_*` lines play positional from the stand-ins; the Russian and German lines play 2D.
8. **Hooks.** Prologue: `MainMenu._ready` (the T-144 live menu) plays `lazarus_saturday` when `ProfileSave.profile.
   prologue_seen` is false, sets it true on `finished` or skip, then shows the menu. Campaign start: `Campaign.start`
   plays `fourth_day` then `gravelight_one` then loads map00 as now. Standalone Map 0 first match start: `InnOpening.
   should_play` already gates round 1; play `gravelight_one` from MapRoot before the opening's settled view begins
   (the opening's `look.min_seconds` clock must start after the cutscene ends). Kaltenbrunn: on map01's load,
   `staub` before the arrival banner. Fernflug: `epilogue_1953` after KÜNDIGUNG's credits. Archive: five rows in the
   cutscene gallery (`menu_archive.gd` is T-200's; give them the ids and the titles, they wire it).
9. **Net.** Host-driven exactly like ExfilCutscene: the host's clock, every peer its own copy, `request_skip_local`
   votes, the host's `finished` ends everyone's. A late joiner during a cutscene sees black with the card and the
   skip bar until it ends.
10. **Tests.** test_cinema: the five definitions validate against lines.json, their lengths (224 / 95 / 64 / 78 / 22 s
    ± 30 %), every `vo` id exists and is a `_LZS_` / `_FTD_` / `_STB_` / `_GL1_` line, no shot's `fov` under 24 or
    over 70, the mid-timeline cards' exact text; a smoke per cutscene through clip_cutscene (plays, skips, no missing
    node); an online smoke for one (the host ends it, the client follows); the prologue flag set after a skip.
11. **Film it.** `tools/wsl_cutscene_clip.sh` (WSL + Xvfb, software GL, never a window on the owner's PC) with a still
    per second into `morning/clips/t194_*`; the respect reviewer (T-202) reads the stills against §1's rules.

## 9. AS BUILT (T-194; DECISIONS T-194)

> T-206 (the polish pass, DECISIONS T-206) re-blocked the acting and corrected eleven cameras over this build without
> changing a beat, a line or a length; the shot-by-shot notes, with what is still off and needs assets, are
> docs/CUTSCENE_POLISH.md. Where a position or an effect below differs from the stage code, the code is right.

- **Data** `data/gravelight/cutscenes_lazarus.json`: the five definitions, `sets` (14 stage ids on 13 scenes), `cast`
  (every person's look), `hooks`, the Archive `gallery`, `risen_kind`. Lengths: LAZARUS SATURDAY 240 s, FOURTH DAY
  106 s, STAUB 73 s, GRAVELIGHT ONE 84 s, the Moscow card 23 s (each within +15 % of §1-§5: shots were lengthened
  where the lines at reading speed would talk over each other; `test_cinema_lazarus` checks both).
- **Runtime** `gravelight/ui/cinema/`: `CinemaReel` (the stage in a SubViewport with its own World3D, so a set never
  touches the map it plays over; the stage is swapped while the picture is black), `LazarusCinema` (the match-start
  hooks and the host-driven net path), `CinemaTheatre` (the prologue on first launch, the Archive's replays),
  `CinemaLibrary` (the data). The director gained `lines`, `card` and `black` shot events.
- **Stages** `gravelight/world/cinema_sets/` (procedural, our own geometry on the game's CC0 materials and props):
  village (A-C; variant `spring` for shot 32), crypt (D-E), ward (F: built as the mortuary room off the fever ward,
  respect review R-03), cordon (G), train (H), front (I-J; the OP 250 m from the line, not 600, so the long lens reads
  the soft bursts), rear (K-L), mill (M), hill (N-O), heart (P: built small, not map01), c47 (Q-R), glide (S: a small
  night stage, not Map 0 itself), vault (T). People: `CinemaPerson` (relief-squad bodies in costume, posed by
  PatronBody's solver plus kneel / pray / palm / hold); the risen: `CinemaRisen.make(risen_kind, seed)`, the one seam
  for T-192's skins.
- **Kept from the review (T-202)**: the lintel's wording (R-02), 18.IV (R-03), the cards' "a long day's cart" and "the
  East Prussian line" (R-09, R-16); nothing on screen names the NKVD (R-04).
