class_name StoryProp
extends Interactable
## A fixed, hand-placed story item (docs/gravelight/LORE.md section 13.1): the inn's guest book, a wireless log,
## a child's drawing, an unsent letter, a nailed delivery docket, a framed clipping. Always in the same place and
## always there, even after it has been read. Hold Use to read it in a full-screen reader (StoryReader); the
## first read files it in the Intel Archive. Placements come from data/gravelight/story_props.json (spawn_all);
## the text is the intel.json row with the same id, marked "placement": "fixed" so MapRoot never spawns it at
## random. Reading is personal (net_local), as with every other intel.
##
## Frame: local -Z is the front (the reader's side: the bottom edge of a page lying flat, the face of a sheet
## on a wall), like every Interactable. Flat styles sit on a surface at the node's origin; wall styles hang
## with their back at the origin. The art is procedural, built once per style and cached (InteractableArt).

const DATA_PATH: String = "res://data/gravelight/story_props.json"
const INTEL_PATH: String = "res://data/gravelight/intel.json"
const STYLES: PackedStringArray = ["guest_book", "logbook", "drawing", "letter", "docket", "clipping"]
const WALL_STYLES: PackedStringArray = ["drawing", "docket", "clipping"]
const INK: String = "paint:#2a2432"
const PENCIL: String = "paint:#55514c"
const LEATHER: String = "paint:#3a2416"

@export var intel_id: StringName = &""
@export var style: String = "letter"
## UPDATE 10 (T-154): story_props.json "hidden_until_flag": the item is invisible and can't be read until that
## GameState flag is set (Totenhafen's sailor's letter, under the cutter until it slips into the sea at round 15).
@export var hidden_until_flag: StringName = &""

var title: String = "Story item"
var row: Dictionary = {}


## Spawns every story_props.json entry for `map_key` ("0", "1") under `map`. Returns how many.
static func spawn_all(map: Node3D, map_key: String) -> int:
	var n: int = 0
	for e: Dictionary in GLData.load_json(DATA_PATH).get("props", []):
		if str(e.get("map", "")) != map_key:
			continue
		var p: StoryProp = StoryProp.new()
		p.intel_id = StringName(str(e.get("id", "")))
		p.style = str(e.get("style", "letter"))
		p.hidden_until_flag = StringName(str(e.get("hidden_until_flag", "")))
		p.name = "Story_" + String(p.intel_id)
		var pos: Array = e.get("position", [0.0, 0.0, 0.0])
		if pos.size() >= 3:
			p.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		p.rotation.y = deg_to_rad(float(e.get("yaw", 0.0)))
		p.add_to_group(&"story_props")
		map.add_child(p)
		n += 1
	return n


## The intel.json row for an id ({} when there is none).
static func intel_row(id: StringName) -> Dictionary:
	for r: Dictionary in GLData.load_json(INTEL_PATH).get("intel", []):
		if str(r.get("id", "")) == String(id):
			return r
	return {}


static func is_wall_style(s: String) -> bool:
	return WALL_STYLES.has(s)


func _ready() -> void:
	row = intel_row(intel_id)
	title = str(row.get("title", "Story item"))
	if is_wall_style(style):
		interact_size = Vector3(0.7, 0.7, 0.36)
		interact_offset = Vector3(0, 0, -0.1)
	else:
		interact_size = Vector3(0.7, 0.35, 0.6)
		interact_offset = Vector3(0, 0.1, 0)
	super._ready()
	if hidden_until_flag != &"":
		visible = GameState.has_flag(hidden_until_flag)
		GLBus.flag_changed.connect(func(f: StringName, v: Variant) -> void:
			if f == hidden_until_flag:
				visible = bool(v))


## Shown and readable (a hidden_until_flag item only once its flag is set).
func revealed() -> bool:
	return hidden_until_flag == &"" or GameState.has_flag(hidden_until_flag)


func can_interact(player: Player) -> bool:
	return revealed() and super.can_interact(player)


func build_greybox() -> void:
	var s: String = style if STYLES.has(style) else "letter"
	InteractableArt.place(self, "story_" + s, func(r: Node3D) -> void: build_art(r, s))
	# a faint glint so the item can be found in a dim room (intel pickups do the same, brighter)
	var glint: OmniLight3D = OmniLight3D.new()
	glint.light_color = Color(0.95, 0.88, 0.75)
	glint.light_energy = 0.2 if is_wall_style(s) else 0.3   # plaster right behind a wall item pools the light
	glint.omni_range = 1.1
	glint.omni_attenuation = 1.6
	glint.shadow_enabled = false
	glint.position = Vector3(0, 0, -0.25) if is_wall_style(s) else Vector3(0, 0.22, 0)
	add_child(glint)


func get_prompt(_player: Player) -> String:
	if not revealed():
		return ""
	return "Hold [%s] to read: %s" % [prompt_key(&"interact"), title]


func hold_time(_player: Player) -> float:
	return 0.35


## Reading is personal: it runs on the reader's own machine, like intel.
func net_local() -> bool:
	return true


func interact(player: Player) -> void:
	StoryReader.open_for(player, intel_id, row)


# ================================================================== procedural art (local frame, -Z = front)

static func build_art(g: Node3D, s: String) -> void:
	match s:
		"guest_book":
			_guest_book(g)
		"logbook":
			_logbook(g)
		"drawing":
			_drawing(g)
		"letter":
			_letter(g)
		"docket":
			_docket(g)
		_:
			_clipping(g)


## A row of handwriting: short dark dashes, one per line, with a ragged right edge. Lines run along local X
## and step toward +Z (away from the reader), so the first line is the far one. `yaw` tilts the page.
static func _lines(g: Node3D, origin: Vector3, count: int, width: float, step: float, key: String,
		thick: float = 0.0035, seed_v: int = 1, yaw: float = 0.0) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for i: int in count:
		var w: float = width * rng.randf_range(0.55, 1.0)
		var c: Vector3 = origin + Vector3(-(width - w) * 0.5, 0.0, -step * float(i))
		InteractableArt.OB(g, c.rotated(Vector3.UP, deg_to_rad(yaw)), Vector3(w, 0.0008, thick), key, Vector3(0, yaw, 0))


## Handwriting on a vertical sheet (wall items): lines run along X and step down in Y.
static func _wall_lines(g: Node3D, origin: Vector3, count: int, width: float, step: float, key: String,
		thick: float = 0.0035, seed_v: int = 1, align_left: bool = true) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for i: int in count:
		var w: float = width * rng.randf_range(0.55, 1.0)
		var x: float = origin.x - (width - w) * 0.5 if align_left else origin.x
		InteractableArt.OB(g, Vector3(x, origin.y - step * float(i), origin.z), Vector3(w, thick, 0.0008), key)


## The inn's guest book: open at its last written page, leather boards, ruled columns, a ribbon, an inkwell
## and a pen. Spread 0.46 along X, 0.32 deep.
static func _guest_book(g: Node3D) -> void:
	InteractableArt.OB(g, Vector3(0, 0.012, 0), Vector3(0.47, 0.024, 0.33), LEATHER)
	InteractableArt.OB(g, Vector3(-0.113, 0.038, 0), Vector3(0.215, 0.028, 0.3), "paper")
	InteractableArt.OB(g, Vector3(0.113, 0.038, 0), Vector3(0.215, 0.028, 0.3), "paper")
	InteractableArt.OB(g, Vector3(0, 0.04, 0), Vector3(0.012, 0.03, 0.31), LEATHER)
	# ruled columns (faint red) on both pages, and the landlord's entries
	for x: float in [-0.19, -0.145, -0.04, 0.04, 0.085, 0.19]:
		InteractableArt.OB(g, Vector3(x, 0.0525, 0), Vector3(0.0015, 0.0006, 0.27), "paint:#9a5a52")
	_lines(g, Vector3(-0.112, 0.0526, 0.115), 10, 0.17, 0.026, INK, 0.0035, 3)
	_lines(g, Vector3(0.113, 0.0526, 0.115), 6, 0.17, 0.026, INK, 0.0035, 9)
	# the last line, in a child's pencil, pressed hard
	InteractableArt.OB(g, Vector3(0.1, 0.0528, -0.08), Vector3(0.15, 0.001, 0.0065), PENCIL)
	InteractableArt.OB(g, Vector3(0.07, 0.0528, -0.105), Vector3(0.09, 0.001, 0.0065), PENCIL)
	# ribbon bookmark lying across the right page and over the near edge
	InteractableArt.OB(g, Vector3(0.17, 0.0532, 0.03), Vector3(0.013, 0.0012, 0.24), "red_paint")
	InteractableArt.OB(g, Vector3(0.17, 0.028, -0.161), Vector3(0.013, 0.05, 0.0012), "red_paint")
	# inkwell and pen, east of the book
	InteractableArt.C(g, Vector3(0.31, 0.026, 0.05), 0.03, 0.052, "paint:#14141c")
	InteractableArt.C(g, Vector3(0.31, 0.055, 0.05), 0.021, 0.008, "brass")
	InteractableArt.C(g, Vector3(0.31, 0.062, 0.05), 0.012, 0.006, "paint:#14141c")
	InteractableArt.C(g, Vector3(0.3, 0.005, -0.07), 0.0045, 0.17, "beam", Vector3(90, 25, 0))
	InteractableArt.C(g, Vector3(0.335, 0.005, -0.146), 0.0035, 0.014, "brass", Vector3(90, 25, 0))


## A signals section's field logbook: cloth boards, open, pencil in two hands, the pencil lying across.
static func _logbook(g: Node3D) -> void:
	InteractableArt.OB(g, Vector3(0, 0.009, 0), Vector3(0.33, 0.018, 0.23), "paint:#4b5244")
	InteractableArt.OB(g, Vector3(-0.08, 0.026, 0), Vector3(0.15, 0.016, 0.21), "paper")
	InteractableArt.OB(g, Vector3(0.08, 0.026, 0), Vector3(0.15, 0.016, 0.21), "paper")
	InteractableArt.OB(g, Vector3(0, 0.027, 0), Vector3(0.008, 0.019, 0.22), "paint:#4b5244")
	InteractableArt.OB(g, Vector3(-0.155, 0.0095, 0), Vector3(0.012, 0.02, 0.232), "paint:#3a4034")
	InteractableArt.OB(g, Vector3(0.155, 0.0095, 0), Vector3(0.012, 0.02, 0.232), "paint:#3a4034")
	# the sergeant's hand (left, firm) and the operator's (right, lighter), then the landlord's note below
	_lines(g, Vector3(-0.08, 0.0345, 0.085), 8, 0.12, 0.021, PENCIL, 0.003, 5)
	_lines(g, Vector3(0.08, 0.0345, 0.085), 5, 0.12, 0.021, "paint:#6a665f", 0.0025, 11)
	_lines(g, Vector3(0.08, 0.0345, -0.04), 3, 0.12, 0.021, INK, 0.003, 12)
	# pencil across the right page
	InteractableArt.C(g, Vector3(0.075, 0.0385, 0.0), 0.0038, 0.15, "yellow_paint", Vector3(90, -70, 0))
	InteractableArt.C(g, Vector3(0.1, 0.0385, -0.069), 0.0032, 0.014, "beam", Vector3(90, -70, 0))
	InteractableArt.C(g, Vector3(0.1055, 0.0385, -0.084), 0.0022, 0.018, "paint:#efe6d4", Vector3(90, -70, 0))


## Kaethe's crayon drawing on the back of a brewery order form, pinned slightly crooked.
static func _drawing(g: Node3D) -> void:
	var sheet: Node3D = Node3D.new()
	sheet.rotation.z = deg_to_rad(-2.5)
	g.add_child(sheet)
	InteractableArt.OB(sheet, Vector3(0, 0, -0.004), Vector3(0.3, 0.38, 0.005), "paper")
	var crayon: String = "paint:#3b2a1a"
	# the wireless set, drawn as big as a house, violet pressed through the paper
	InteractableArt.OB(sheet, Vector3(-0.02, 0.0, -0.0075), Vector3(0.19, 0.22, 0.002), "paint:#6a3f9c")
	InteractableArt.OB(sheet, Vector3(-0.02, 0.0, -0.0085), Vector3(0.13, 0.15, 0.0015), "paint:#4b2a78")
	for e: Array in [[Vector3(-0.02, 0.113, 0), Vector3(0.21, 0.01, 0.002)], [Vector3(-0.02, -0.113, 0), Vector3(0.21, 0.01, 0.002)],
			[Vector3(-0.12, 0.0, 0), Vector3(0.01, 0.23, 0.002)], [Vector3(0.08, 0.0, 0), Vector3(0.01, 0.23, 0.002)]]:
		InteractableArt.OB(sheet, (e[0] as Vector3) + Vector3(0, 0, -0.009), e[1] as Vector3, crayon)
	InteractableArt.OB(sheet, Vector3(0.05, 0.08, -0.009), Vector3(0.03, 0.03, 0.002), "paint:#d8c25a")   # the dial
	# the girl in the set: a paper hat, a face, a red drum
	InteractableArt.OB(sheet, Vector3(-0.02, 0.058, -0.0095), Vector3(0.028, 0.028, 0.002), "paint:#efe6d4", Vector3(0, 0, 45))
	InteractableArt.OB(sheet, Vector3(-0.02, 0.03, -0.0095), Vector3(0.026, 0.024, 0.002), "paint:#e8c9a8")
	InteractableArt.OB(sheet, Vector3(-0.02, -0.01, -0.0095), Vector3(0.03, 0.05, 0.002), "paint:#efe6d4")
	InteractableArt.C(sheet, Vector3(-0.02, -0.055, -0.0095), 0.022, 0.002, "red_paint", Vector3(90, 0, 0))
	# the smaller girl outside the set, yellow plaits, a candle
	InteractableArt.OB(sheet, Vector3(0.115, -0.045, -0.009), Vector3(0.02, 0.018, 0.002), "paint:#e8c9a8")
	InteractableArt.OB(sheet, Vector3(0.115, -0.028, -0.0095), Vector3(0.03, 0.008, 0.002), "paint:#e5c540")
	InteractableArt.OB(sheet, Vector3(0.1, -0.055, -0.0095), Vector3(0.006, 0.04, 0.002), "paint:#e5c540")
	InteractableArt.OB(sheet, Vector3(0.13, -0.055, -0.0095), Vector3(0.006, 0.04, 0.002), "paint:#e5c540")
	InteractableArt.OB(sheet, Vector3(0.115, -0.085, -0.009), Vector3(0.024, 0.06, 0.002), "paint:#3a6aa0")
	InteractableArt.OB(sheet, Vector3(0.14, -0.065, -0.0095), Vector3(0.006, 0.03, 0.002), "paint:#efe6d4")
	InteractableArt.OB(sheet, Vector3(0.14, -0.045, -0.0095), Vector3(0.008, 0.01, 0.002), "paint:#f0b030")
	# the careful capitals, and the row of drumbeats along the bottom edge
	_wall_lines(g, Vector3(-0.02, -0.14, -0.0095), 2, 0.24, 0.016, crayon, 0.006, 21, false)
	for i: int in 7:
		var dx: float = -0.1 + 0.033 * float(i)
		InteractableArt.OB(sheet, Vector3(dx, -0.172, -0.0095), Vector3(0.012 if i % 3 != 2 else 0.018, 0.008, 0.002), "red_paint")
	# drawing pins
	InteractableArt.dot(g, Vector3(-0.125, 0.172, -0.009), 0.007, "brass")
	InteractableArt.dot(g, Vector3(0.12, 0.178, -0.009), 0.007, "brass")


## Josef Brenner's unsent letter, unfolded on the blanket, its envelope beside it (no stamp).
static func _letter(g: Node3D) -> void:
	var yaw: float = 6.0
	InteractableArt.OB(g, Vector3(0, 0.0015, 0), Vector3(0.21, 0.003, 0.3), "paper", Vector3(0, yaw, 0))
	for z: float in [-0.05, 0.05]:
		InteractableArt.OB(g, Vector3(0, 0.0032, z).rotated(Vector3.UP, deg_to_rad(yaw)), Vector3(0.2, 0.0004, 0.0015), "paint:#a89a78", Vector3(0, yaw, 0))
	InteractableArt.OB(g, Vector3(0.045, 0.0034, 0.125).rotated(Vector3.UP, deg_to_rad(yaw)), Vector3(0.09, 0.0008, 0.0035), INK, Vector3(0, yaw, 0))
	_lines(g, Vector3(0, 0.0034, 0.095), 14, 0.17, 0.0145, INK, 0.0032, 7, yaw)
	InteractableArt.OB(g, Vector3(0.05, 0.0034, -0.125).rotated(Vector3.UP, deg_to_rad(yaw)), Vector3(0.07, 0.0008, 0.0035), INK, Vector3(0, yaw, 0))
	# envelope, addressed, no stamp
	var ey: float = -14.0
	var ec: Vector3 = Vector3(0.2, 0.003, 0.02)
	InteractableArt.OB(g, ec, Vector3(0.165, 0.006, 0.11), "paint:#d9cdb0", Vector3(0, ey, 0))
	InteractableArt.OB(g, ec + Vector3(0, 0.0032, 0.03).rotated(Vector3.UP, deg_to_rad(ey)), Vector3(0.165, 0.0004, 0.0012), "paint:#b8ab8c", Vector3(0, ey, 0))
	_lines(g, ec + Vector3(0.0, 0.0034, 0.005).rotated(Vector3.UP, deg_to_rad(ey)), 3, 0.09, 0.012, INK, 0.003, 15, ey)


## The Helvetia delivery docket, nailed to the cellar pillar: printed header, ruled form, pen entries, pencil.
static func _docket(g: Node3D) -> void:
	var sheet: Node3D = Node3D.new()
	sheet.rotation.z = deg_to_rad(1.5)
	g.add_child(sheet)
	InteractableArt.OB(sheet, Vector3(0, 0, -0.003), Vector3(0.22, 0.3, 0.004), "paper")
	InteractableArt.dot(sheet, Vector3(0, 0.135, -0.007), 0.006, "steel")
	InteractableArt.OB(sheet, Vector3(0, 0.112, -0.0055), Vector3(0.17, 0.014, 0.0008), "paint:#1e1e22")
	InteractableArt.OB(sheet, Vector3(0, 0.097, -0.0055), Vector3(0.11, 0.005, 0.0008), "paint:#1e1e22")
	InteractableArt.OB(sheet, Vector3(0.07, 0.083, -0.0055), Vector3(0.05, 0.004, 0.0008), "red_paint")   # the docket number
	for i: int in 8:
		var y: float = 0.065 - 0.018 * float(i)
		InteractableArt.OB(sheet, Vector3(0, y - 0.008, -0.0055), Vector3(0.19, 0.0008, 0.0008), "paint:#8a8a8a")
		InteractableArt.OB(sheet, Vector3(-0.07, y, -0.0055), Vector3(0.04, 0.003, 0.0008), "paint:#3a3a3e")   # printed label
	_wall_lines(sheet, Vector3(0.025, 0.066, -0.0058), 8, 0.11, 0.018, INK, 0.0032, 17)
	_wall_lines(sheet, Vector3(0.0, -0.095, -0.0058), 2, 0.17, 0.013, PENCIL, 0.0032, 18, false)
	InteractableArt.OB(sheet, Vector3(0.02, -0.125, -0.0058), Vector3(0.1, 0.0022, 0.0008), INK)   # very small and very neat


## The framed clipping over the benches: a dark frame, a yellowed column, a second cutting tucked in the corner.
static func _clipping(g: Node3D) -> void:
	var fk: String = "paint:#2a1c10"
	InteractableArt.OB(g, Vector3(0, 0.295, -0.012), Vector3(0.5, 0.03, 0.024), fk)
	InteractableArt.OB(g, Vector3(0, -0.295, -0.012), Vector3(0.5, 0.03, 0.024), fk)
	InteractableArt.OB(g, Vector3(-0.235, 0, -0.012), Vector3(0.03, 0.62, 0.024), fk)
	InteractableArt.OB(g, Vector3(0.235, 0, -0.012), Vector3(0.03, 0.62, 0.024), fk)
	InteractableArt.OB(g, Vector3(0, 0, -0.004), Vector3(0.46, 0.58, 0.005), "paint:#5a4a3a")   # the mount
	InteractableArt.OB(g, Vector3(-0.02, 0.02, -0.0085), Vector3(0.28, 0.5, 0.003), "paint:#c9b98a")   # yellowed column
	InteractableArt.OB(g, Vector3(-0.02, 0.235, -0.0105), Vector3(0.22, 0.012, 0.0008), "paint:#1e1e22")   # headline
	InteractableArt.OB(g, Vector3(-0.02, 0.218, -0.0105), Vector3(0.14, 0.005, 0.0008), "paint:#1e1e22")
	InteractableArt.OB(g, Vector3(-0.02, 0.208, -0.0105), Vector3(0.24, 0.0008, 0.0008), "paint:#3a3a3e")
	_wall_lines(g, Vector3(-0.02, 0.192, -0.0105), 24, 0.24, 0.0165, "paint:#3a3a3e", 0.0028, 23, false)
	InteractableArt.OB(g, Vector3(-0.175, 0.0, -0.0105), Vector3(0.004, 0.12, 0.0008), PENCIL, Vector3(0, 0, 8))   # pencil in the margin
	# the smaller cutting from November 1938, tucked in the lower right corner
	var cut: Node3D = Node3D.new()
	cut.position = Vector3(0.14, -0.2, 0)
	cut.rotation.z = deg_to_rad(-7.0)
	g.add_child(cut)
	InteractableArt.OB(cut, Vector3(0, 0, -0.0115), Vector3(0.13, 0.15, 0.003), "paint:#d8ccaa")
	InteractableArt.OB(cut, Vector3(0, 0.06, -0.0135), Vector3(0.1, 0.008, 0.0008), "paint:#1e1e22")
	_wall_lines(cut, Vector3(0, 0.044, -0.0135), 7, 0.1, 0.014, "paint:#3a3a3e", 0.0025, 29, false)
