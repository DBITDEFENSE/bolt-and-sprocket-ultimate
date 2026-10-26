# GRAVELIGHT VFX (UPDATE 05 section 6, DECISIONS T-095)

World-space VFX live in the `Effects` autoload (`gravelight/autoload/effects.gd`), the helpers under
`gravelight/world/vfx/`, and the data in `data/gravelight/vfx.json`. Everything is pooled and preallocated: a shot,
a hit or a burst swaps a mesh or texture reference, sets a transform and restarts a one-shot emitter. Nothing is
allocated per shot (GUT `test_vfx` fires 500 shots' worth of everything and counts nodes before and after).

## Quality
`GLSettings.values["vfx_quality"]` = `low | medium | high` (default high; the settings menu option is the UI
section's to add). `Effects.quality()` returns the row from `vfx.json "quality"`: `particles` (a multiplier on
every count), `flash_lights` (the pooled OmniLight budget: 2 / 3 / 4), `casings` (0.5 = every other case),
`near_snow`, `motes`, `smoke`, `flash_core`.

## Muzzle flashes (`FlashPool`)
Driven from `GLBus.weapon_fired` for every shooter. The muzzle is resolved per shooter: the local human's viewmodel
muzzle (`WeaponHolder._muzzle_world()`, wall-clamped), a bot's or teammate's `RemoteBody` "Muzzle", else the shot
origin. One look per weapon class (`vfx.json flash.classes`): petal count, length along the barrel, size, the front
bloom, the light pulse and range, life, the smoke wisp, the HDR tint. Three star textures give shape variety; a
Crucible-taught gun's petals carry a violet fringe; wonder weapons are violet Nachtglas. The flamethrower keeps its
flame (`skip`). With `flash.first_person = "effects"` the holder's own star is zeroed through the `size` meta it
reads (its flash light stays, so no pooled light is spent on the local gun); third-person bodies' own flashes are
hidden the moment the signal arrives (they were shown just before it).

## Casings (`CasingPool`)
The OpenGameArt "Ultimate Low Poly Guns" cartridge set (CC-BY, `assets/third_party/opengameart/pichuliru-cartridges/model.glb`):
15 cases in metres, re-centred and turned so the case axis is +Z, one MultiMesh per case kind (16 instances). The
weapon picks its case through `data/gravelight/weapons/models.json extras.cartridges.casing_for`; the holder's
casing kind (`weapons.json feel.casing`: pistol / rifle / shell) is the fallback. Kinematic arcs: gravity, drag,
spin, one bounce off the floor found by a ray at ejection, then the case lies flat and sinks away at the end of its
life. The first bounce plays `casing_tink` (three synthesized, project-owned samples under
`gravelight/audio/sfx/world/`). `WeaponHolder._eject_casing` still calls `GunFx.eject(kind, from, vel, basis)`,
which forwards to `Effects.casing`; the holder already ejects per shot for autos, on the bolt / pump cycle for bolts
and shotguns, and dumps the Webley's six on reload.

## Impacts (`ImpactFx` + the T-053 decals)
`Effects.impact(pos, normal, surface, collider)` draws the decal (persistent on plain static geometry, T-053) and
the debris for the surface from `vfx.json "impacts"`: a tinted puff, chunks (wood splinters, plaster flakes, stone
chips, glass slivers, hay chaff, cloth threads), sparks on stone and metal, the rise's dirt pool for snow and earth.
New decals: a plaster crater and a glass star; cloth and earth leave no mark. The surface comes from
`Effects.surface_of()`: the collider's `surface` meta, then the ordered `surfaces.name_hints` table (the maps'
static meshes are merged at generation, so the colliders carry no material), then the map's defaults by facing
(`wall_default`, `floor_default`, `open_ground` per map id). `GunFx.surface_of` delegates here.

## Hits
`Effects.blood(pos, toward)` (gore-gated) now adds a mist and droplets. A hit from a Crucible-taught weapon adds the
violet Nachtglas spark burst: `Effects.zombie_hit(pos, toward, weapon_id, upgraded)` is the proper call; until the
holder passes the weapon, a hit reported in the same physics frame as an upgraded `weapon_fired` sparks too (the
bridge). `Effects.nachtglas_spark` serves the Glasshide's plates. `Effects.shatter(pos, color, amount, speed)` is
the pooled crystal burst with a flash light for `Zombie._shards` to call.

## The Great Toll
`GLBus.great_toll(player, origin, direction, range_m)` (emitted by `Totenglocke.toll` / `bot_toll` on a Great
Toll) drives `Effects.toll_ring`: a flat disc racing out to the toll's range with a screen-texture refraction band
on its rim and a violet glow, world-space so a teammate's toll shows. The holder's own full-screen `screen_ring`
for the local human is unchanged.

## Atmosphere (`VfxAtmosphere`, attached by Effects at match start)
- Near snow: a camera-following box of big slow flakes, emitting only under open sky (a ray up every 0.25 s).
  `Snowfall` draws the mid layer and a new far layer (smaller, fainter) per area: snow in depth.
- Dust motes inside the stable's moonlight shafts (the Landscape's `StableMoonLeaks` sheets).
- A low FogVolume over the west field, where the three ground fogs left a gap.
- `FlickerLight` is noise-based (two simplex octaves, a rare gutter); fires (hearth, wreck, candles) burn faster
  and deeper than lanterns (`atmosphere.flicker`). `LampGlow` keeps reading `base_energy`.
- `BreathFog`: a sprinter breathes sooner and faster (`atmosphere.breath`).

## Tools and tests
- GUT `gravelight/tests/unit/test_vfx.gd`.
- `tools/clip_map00.sh` -> `gravelight/tools_src/clip_map00.tscn`: the 60 s round-8 clip through the player-bot's
  eyes with 3 bots, a taught Thompson and the yard; mp4 + 12-frame contact sheet in `morning/clips/u05/`.
- The bench: `docs/gravelight/PERFORMANCE.md` (perf_marks).
