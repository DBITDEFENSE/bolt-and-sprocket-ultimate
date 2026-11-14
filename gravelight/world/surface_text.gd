class_name SurfaceText
extends RefCounted
## T-247 (the owner, 2026-11-14, eight screenshots of the Inn's Helvetia cellar: "WE NEED TO DO SOMETHING ABOUT THIS
## CRAPPY FONT AND TEXT ON STUFF, REMOVE OR MAKE IT MORE SUBTLE"): the one look for text that sits on a surface in the
## world. Every map generator and every world script styles its Label3D through here, so a sign on the Inn's wall,
## a wall-buy's chalk and a perk machine's board read as the same paint.
##
## What read badly was the Label3D default: Godot's clean UI sans, unshaded (so it glowed in a dark cellar), an outline
## on the interactables' labels, and bright cream at near-full alpha floating over stone like a HUD overlay. Here:
##   - a period face from the repo's own fonts (assets/third_party/google_fonts, all SIL OFL 1.1 or Apache 2.0):
##       PAINT  Stardos Stencil Regular: stencilled or brushed paint on wood, stone, metal (signs, machine boards)
##       CHALK  Special Elite: the rough, uneven typewriter face, for chalk on a board (wall-buys, tallies)
##       PRINT  Old Standard TT: ink on paper, engraved brass and enamel plates (notes, maker's plates, lore)
##       FLOAT  Special Elite, the one look left unshaded: the Crucible's and the crate's rolled-weapon name, which hangs
##              in the box's own glow
##   - lit by the scene (shaded), no outline, never brighter than white (no HDR multipliers);
##   - low contrast: the colour pulled toward its own grey and a light one dimmed, alpha capped per look, so the
##     surface shows through;
##   - a hand-made wobble: a fraction of a degree off true, seeded from the text, so one sign is the same everywhere
##     and two signs are never set dead level side by side.
## Fixed to its surface: never a billboard, never fixed-size, always depth-tested.

enum { PAINT, CHALK, PRINT, FLOAT }

const FONT_PATHS: Dictionary = {
	PAINT: "res://assets/third_party/google_fonts/stardos-stencil/StardosStencil-Regular.ttf",
	CHALK: "res://assets/third_party/google_fonts/special-elite/SpecialElite-Regular.ttf",
	PRINT: "res://assets/third_party/google_fonts/old-standard-tt/OldStandard-Regular.ttf",
	FLOAT: "res://assets/third_party/google_fonts/special-elite/SpecialElite-Regular.ttf",
}
## The most opaque each look gets (the surface always shows through paint and chalk a little).
const MAX_ALPHA: Dictionary = {PAINT: 0.72, CHALK: 0.66, PRINT: 0.9, FLOAT: 0.8}
## How far the colour is pulled toward its own grey (a vivid sign colour reads as old paint).
const DESAT: Dictionary = {PAINT: 0.35, CHALK: 0.5, PRINT: 0.15, FLOAT: 0.3}
## A light colour (luminance above LIGHT_LUM) is multiplied down by this: paint and chalk are never paper-white.
const LIGHT_LUM: float = 0.5
const LIGHT_DIM: float = 0.84
## The wobble: up to this many degrees either way about the text's own axis.
const TILT_DEG: float = 0.9

static var _fonts: Dictionary = {}


## The face for a look (null when the file is missing: the Label3D default then, never an error).
static func font(look: int = PAINT) -> Font:
	if _fonts.has(look):
		return _fonts[look]
	var path: String = str(FONT_PATHS.get(look, FONT_PATHS[PAINT]))
	var f: Font = (load(path) as Font) if ResourceLoader.exists(path) else null
	_fonts[look] = f
	return f


## A colour toned for a surface: no HDR, pulled toward its grey, a light one dimmed, alpha capped.
static func tone(c: Color, look: int = PAINT) -> Color:
	var r: float = clampf(c.r, 0.0, 1.0)
	var g: float = clampf(c.g, 0.0, 1.0)
	var b: float = clampf(c.b, 0.0, 1.0)
	var lum: float = 0.2126 * r + 0.7152 * g + 0.0722 * b
	var k: float = float(DESAT.get(look, 0.3))
	r = lerpf(r, lum, k)
	g = lerpf(g, lum, k)
	b = lerpf(b, lum, k)
	if lum > LIGHT_LUM and look != PRINT:
		r *= LIGHT_DIM
		g *= LIGHT_DIM
		b *= LIGHT_DIM
	return Color(r, g, b, minf(clampf(c.a, 0.0, 1.0), float(MAX_ALPHA.get(look, 0.8))))


## Styles a Label3D for its surface (see the header). Keeps its text, size, position and facing; returns it.
static func apply(l: Label3D, look: int = PAINT) -> Label3D:
	if l == null:
		return l
	var f: Font = font(look)
	if f != null:
		l.font = f
	l.outline_size = 0
	l.shaded = look != FLOAT
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.fixed_size = false
	l.no_depth_test = false
	l.modulate = tone(l.modulate, look)
	if look != FLOAT:
		l.rotation.z += deg_to_rad(wobble(l.text) * TILT_DEG)
	l.set_meta("surface_text", look)
	return l


## A new Label3D in the surface look, added to `parent` at `pos` (local -Z of the parent faces the reader, as
## Props.stencil and Interactable.add_label have always assumed: the label is turned round to read from there).
static func make(parent: Node3D, text: String, pos: Vector3, size_px: int = 32, color: Color = Color(0.85, 0.82, 0.72, 0.7),
		pixel: float = 0.004, look: int = PAINT) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size_px
	l.pixel_size = pixel
	l.modulate = color
	l.position = pos
	l.rotation.y = PI
	apply(l, look)
	if parent != null:
		parent.add_child(l)
	return l


## -1..1 from the text, the same every run (no RNG state: generators stay byte-stable).
static func wobble(text: String) -> float:
	var h: int = hash(text) & 0xFFFF
	return float(h) / 32767.5 - 1.0
