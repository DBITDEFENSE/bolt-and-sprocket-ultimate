class_name ZombieWardrobe
extends RefCounted
## T-269 (docs/u21/t269_zombie_look.md): what a walker wears and how dead it looks, from
## data/gravelight/zombie_wardrobe.json. An outfit is three cloth colours and an optional pattern, a skin a tone and
## a mottling amount; both are written to per-instance parameters of the two shared zombie materials (ZombieBody's
## skin and kit shaders), so a crowd in thirty outfits is the same two materials, the same meshes and the same draw
## calls as a crowd in one. The choice is a pure function of a seed (look_seed: the zombie's net id and its spawn
## health, both already on every peer), so a co-op client's puppet wears what the host's zombie wears.

const PATH: String = "res://data/gravelight/zombie_wardrobe.json"
const PATTERNS: PackedStringArray = ["none", "stripes", "check", "dots"]
## The instance parameters a look sets (a body, its gear and its severed pieces carry the same ones).
const INST_KEYS: PackedStringArray = ["inst_cloth", "inst_cloth2", "inst_accent", "inst_pattern", "inst_wear", "inst_skin", "inst_mottle"]

static var _cfg: Dictionary = {}
static var _off: int = -1   # -1 unread, 0 on, 1 off (`-- --zombie-look=off`: the look before T-269, for the A/B renders)
static var _norim: int = -1


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(PATH)
	return _cfg


static func _arg(v: String) -> bool:
	return ("--zombie-look=" + v) in OS.get_cmdline_user_args()


static func enabled() -> bool:
	if _off < 0:
		_off = 1 if _arg("off") else 0
	return _off == 0 and bool(cfg().get("enabled", true))


## The dark-readability terms (light.min_light, light.rim): off with the whole look, or alone with `--zombie-look=norim`.
static func rim_enabled() -> bool:
	if _norim < 0:
		_norim = 1 if _arg("norim") else 0
	return enabled() and _norim == 0


## Tests: read the file and the switches again.
static func reload() -> void:
	_cfg = {}
	_off = -1
	_norim = -1


## The seed of a zombie's look: its net id (the pool slot, the same on every peer) mixed with its spawn health (sent
## with the spawn event; it changes with the round, so a slot is not dressed the same all match long).
static func look_seed(net_id: int, max_hp: float) -> int:
	return _mix(_mix(net_id + 0x9E37) ^ (roundi(max_hp) * 0x85EB + 0x1F))


## A 31-bit integer hash (the same on every platform: integer arithmetic only, kept inside 53 bits).
static func _mix(x: int) -> int:
	var h: int = x & 0x7FFFFFFF
	h = ((h ^ (h >> 15)) * 0x2C1B3C6D) & 0x7FFFFFFF
	h = ((h ^ (h >> 12)) * 0x297A2D39) & 0x7FFFFFFF
	return (h ^ (h >> 15)) & 0x7FFFFFFF


## A float in [0, 1) from the seed and a stream index.
static func rand01(look: int, stream: int) -> float:
	return float(_mix(look ^ _mix(stream * 7919 + 13)) % 1000003) / 1000003.0


## Which colour (1 = a, 2 = b, 3 = c, 0 = its own) a part key of `kit` takes ("" = a gear piece: the shared table).
static func slot_of(kit: String, key: String) -> int:
	var c: Dictionary = cfg()
	var ks: Dictionary = c.get("kit_slots", {})
	if kit != "" and ks.has(kit):
		return int((ks[kit] as Dictionary).get(key, 0))
	return int((c.get("slots", {}) as Dictionary).get(key, 0))


## The outfit table of a kit on a map: the map's own, else the default's, else {} (the kit keeps its baked colours).
static func outfits_for(map_id: String, kit: String) -> Dictionary:
	var maps: Dictionary = cfg().get("maps", {})
	var m: Dictionary = maps.get(map_id, {})
	if m.has(kit):
		return m[kit]
	return (maps.get("default", {}) as Dictionary).get(kit, {})


## A weighted pick from {name: weight} with roll in [0, 1): in the table's own order, "" when it is empty.
static func pick_weighted(table: Dictionary, roll: float) -> String:
	var total: float = 0.0
	for k: Variant in table.keys():
		if not str(k).begins_with("_"):
			total += maxf(0.0, float(table[k]))
	if total <= 0.0:
		return ""
	var r: float = roll * total
	var last: String = ""
	for k: Variant in table.keys():
		if str(k).begins_with("_"):
			continue
		last = str(k)
		r -= maxf(0.0, float(table[k]))
		if r < 0.0:
			return last
	return last


static func outfit_name(map_id: String, kit: String, look: int) -> String:
	return pick_weighted(outfits_for(map_id, kit), rand01(look, 1))


static func skin_weights() -> Dictionary:
	var w: Dictionary = {}
	var skins: Dictionary = cfg().get("skins", {})
	for k: Variant in skins.keys():
		if skins[k] is Dictionary:
			w[k] = float((skins[k] as Dictionary).get("weight", 1.0))
	return w


static func skin_name(look: int) -> String:
	return pick_weighted(skin_weights(), rand01(look, 2))


static func _lin(hex: Variant, fallback: Color = Color(0.5, 0.5, 0.5)) -> Color:
	if hex is String and Color.html_is_valid(hex as String):
		return Color.html(hex as String).srgb_to_linear()
	return fallback


static func _range(v: Variant, lo: float, hi: float, t: float) -> float:
	if v is Array and (v as Array).size() >= 2:
		return lerpf(float((v as Array)[0]), float((v as Array)[1]), t)
	return lerpf(lo, hi, t)


## The instance parameters of the look `look` for a `kit` zombie on `map_id` (INST_KEYS -> value; linear colours):
##   inst_cloth / inst_cloth2 / inst_accent  rgb = the colour, a = 1 (0 = keep the baked colour)
##   inst_pattern                            rgb = the pattern's colour, a = its kind (PATTERNS index)
##   inst_skin                               rgb = the tone multiplier, a = the mottling amount
##   inst_mottle                             rgb = the colour of the blotches
##   inst_wear                               x = blood (clothes, mouth, hands), y = dead (sockets, veins), z = the
##                                           stain layout's phase, w unused
## A kit without outfits on this map gets the skin and the wear only. Off (the switch, or enabled false): {} .
static func look_params(map_id: String, kit: String, look: int) -> Dictionary:
	if not enabled():
		return {}
	var c: Dictionary = cfg()
	var out: Dictionary = {"inst_cloth": Color(0, 0, 0, 0), "inst_cloth2": Color(0, 0, 0, 0), "inst_accent": Color(0, 0, 0, 0),
		"inst_pattern": Color(0, 0, 0, 0)}
	var o: Dictionary = (c.get("outfits", {}) as Dictionary).get(outfit_name(map_id, kit, look), {})
	if not o.is_empty():
		var a: Color = _lin(o.get("a"))
		var b: Color = _lin(o.get("b"), a)
		var cc: Color = _lin(o.get("c"), a)
		# a little of each zombie's own fade, so two in the same outfit are not the same swatch
		var fade: float = lerpf(0.86, 1.1, rand01(look, 5))
		out["inst_cloth"] = Color(a.r * fade, a.g * fade, a.b * fade, 1.0)
		out["inst_cloth2"] = Color(b.r * fade, b.g * fade, b.b * fade, 1.0)
		out["inst_accent"] = Color(cc.r, cc.g, cc.b, 1.0)
		var pat: int = maxi(0, PATTERNS.find(str(o.get("pattern", "none"))))
		if pat > 0:
			var pc: Color = _lin(o.get("pattern_color"), Color(a.r * 0.35, a.g * 0.35, a.b * 0.35))
			out["inst_pattern"] = Color(pc.r, pc.g, pc.b, float(pat))
	var wear: Dictionary = c.get("wear", {})
	var s: Dictionary = (c.get("skins", {}) as Dictionary).get(skin_name(look), {})
	if s.is_empty() or ZombieBody.SOVIET_KITS.has(kit):
		out["inst_skin"] = Color(1, 1, 1, 0)   # (the Returned keep their frost-white)
		out["inst_mottle"] = Color(0, 0, 0, 0)
	else:
		var mc: Color = _lin(s.get("mottle_color"), Color(0.08, 0.05, 0.1))
		out["inst_mottle"] = Color(mc.r, mc.g, mc.b, 1.0)
		var tone: Array = s.get("tone", [1.0, 1.0, 1.0])
		out["inst_skin"] = Color(float(tone[0]), float(tone[1]), float(tone[2]), clampf(float(s.get("mottle", 0.4)), 0.0, 1.0))
	out["inst_wear"] = Color(_range(wear.get("blood"), 0.15, 0.9, rand01(look, 3)), _range(wear.get("dead"), 0.55, 1.0, rand01(look, 4)),
		rand01(look, 6), 0.0)
	return out


## How much of the map's standing rime (anim.json variation.frost_by_map) a dressed walker keeps. A weapon's freeze is
## not scaled.
static func frost_scale() -> float:
	return clampf(float((cfg().get("wear", {}) as Dictionary).get("frost_scale", 1.0)), 0.0, 1.0)


## The parameters that undo a look (a pooled zombie that becomes a special, a risen person in their own clothes).
static func neutral_params() -> Dictionary:
	return {"inst_cloth": Color(0, 0, 0, 0), "inst_cloth2": Color(0, 0, 0, 0), "inst_accent": Color(0, 0, 0, 0),
		"inst_pattern": Color(0, 0, 0, 0), "inst_skin": Color(1, 1, 1, 0), "inst_mottle": Color(0, 0, 0, 0), "inst_wear": Color(0, 0, 0, 0)}
