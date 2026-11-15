class_name PerkSpot
extends Node3D
## T-251 (UPDATE 19; the owner: "spread perks randomly around the map"): one of the places on a map where a tonic
## machine may stand. Origin: the floor under the machine's centre; local -Z is the front (the machine's own frame).
## Each match PerkLayout deals the map's machines onto the spots; a spot left without one shows its filler: a Helvetia
## shipping crate nailed shut on its skids, the cabinet that was never unpacked (solid, like a machine: the generator
## bakes one footprint into the navmesh for every spot, whichever stands on it).

@export var spot_id: StringName = &""
@export var zone_id: StringName = &""
## Under the snow: only the cabinet shapes perk_layout.json calls outdoor-safe are dealt here; the crate wears snow.
@export var outdoor: bool = false
## In the start room: only the cheap tonics, never Second Wind (PerkShuffle.allowed).
@export var start: bool = false
## One bought door from the start room: where Second Wind may stand.
@export var near: bool = false

const CRATE: Vector3 = Vector3(0.95, 1.85, 0.7)
const Hay: Script = preload("res://gravelight/world/props_hay.gd")

var machine: Node3D = null
var _filler: Node3D = null
var _body: StaticBody3D = null


func _ready() -> void:
	add_to_group(&"perk_spots")
	# deferred: the map deals its machines in its own _ready (PerkLayout), after every spot's; only the spots the deal
	# leaves free build a crate
	_refresh.call_deferred()


## The row PerkShuffle.assign reads.
func row() -> Dictionary:
	return {"id": String(spot_id), "zone": String(zone_id), "outdoor": outdoor, "start": start, "near": near}


## `m` stands here now (null: nothing does, the crate shows).
func set_machine(m: Node3D) -> void:
	machine = m
	_refresh()


func is_free() -> bool:
	return machine == null or not is_instance_valid(machine)


func _refresh() -> void:
	if not is_inside_tree():
		return
	var free_now: bool = is_free()
	if free_now and _filler == null:
		_build_filler()
	if _filler != null:
		_filler.visible = free_now
	if _body != null:
		_body.collision_layer = 1 if free_now else 0


func _build_filler() -> void:
	_filler = Node3D.new()
	_filler.name = "Filler"
	add_child(_filler)
	var w: float = CRATE.x
	var h: float = CRATE.y
	var d: float = CRATE.z
	var y0: float = 0.09   # on its skids
	var g: Node3D = _filler
	for sx: float in [-1.0, 1.0]:   # the skids
		Props.block(g, Vector3(sx * (w * 0.5 - 0.14) - 0.05, 0.0, -d * 0.5 - 0.04), Vector3(sx * (w * 0.5 - 0.14) + 0.05, y0, d * 0.5 + 0.04), "beam")
	# the box: boards on every face (a dark gap between each pair), a lid proud of the sides
	Props.block(g, Vector3(-w * 0.5 + 0.012, y0, -d * 0.5 + 0.012), Vector3(w * 0.5 - 0.012, h - 0.03, d * 0.5 - 0.012), "char")
	var nb: int = 5
	for k: int in nb:
		var x0: float = -w * 0.5 + w * float(k) / float(nb) + 0.006
		var x1: float = -w * 0.5 + w * float(k + 1) / float(nb) - 0.006
		for sz: float in [-1.0, 1.0]:
			Props.block(g, Vector3(x0, y0, sz * d * 0.5 - 0.012), Vector3(x1, h - 0.03, sz * d * 0.5 + 0.012), "planks")
	var nd: int = 4
	for k2: int in nd:
		var z0: float = -d * 0.5 + d * float(k2) / float(nd) + 0.006
		var z1: float = -d * 0.5 + d * float(k2 + 1) / float(nd) - 0.006
		for sx2: float in [-1.0, 1.0]:
			Props.block(g, Vector3(sx2 * w * 0.5 - 0.012, y0, z0), Vector3(sx2 * w * 0.5 + 0.012, h - 0.03, z1), "planks")
	Props.block(g, Vector3(-w * 0.5 - 0.03, h - 0.03, -d * 0.5 - 0.03), Vector3(w * 0.5 + 0.03, h, d * 0.5 + 0.03), "planks")
	# battens round it at three heights, a diagonal brace across the front and the back, nail heads on the front's
	for by: float in [y0 + 0.06, h * 0.5, h - 0.16]:
		for sz2: float in [-1.0, 1.0]:
			Props.block(g, Vector3(-w * 0.5 - 0.02, by - 0.045, sz2 * (d * 0.5 + 0.012) - 0.014), Vector3(w * 0.5 + 0.02, by + 0.045, sz2 * (d * 0.5 + 0.012) + 0.014), "beam")
		for sx3: float in [-1.0, 1.0]:
			Props.block(g, Vector3(sx3 * (w * 0.5 + 0.012) - 0.014, by - 0.045, -d * 0.5 - 0.02), Vector3(sx3 * (w * 0.5 + 0.012) + 0.014, by + 0.045, d * 0.5 + 0.02), "beam")
		for nx: float in [-w * 0.5 + 0.06, -w * 0.17, w * 0.17, w * 0.5 - 0.06]:
			Props._noshadow(Props.ball(g, Vector3(nx, by, -d * 0.5 - 0.027), Vector3(0.022, 0.022, 0.012), "iron"))
	var diag: float = Vector2(w - 0.12, h * 0.5 - y0 - 0.2).length()
	var ang: float = rad_to_deg(atan2(h * 0.5 - y0 - 0.2, w - 0.12))
	for sz3: float in [-1.0, 1.0]:
		Props.obox(g, Vector3(0, (y0 + h * 0.5) * 0.5 + 0.03, sz3 * (d * 0.5 + 0.012)), Vector3(diag, 0.08, 0.026), "beam", Vector3(0, 0, ang * sz3))
		Props.obox(g, Vector3(0, (h * 0.5 + h) * 0.5 - 0.06, sz3 * (d * 0.5 + 0.012)), Vector3(diag, 0.08, 0.026), "beam", Vector3(0, 0, -ang * sz3))
	# two steel bands and their seals; the consignment tag on its string (blank: T-247, no loud text in the world)
	for bx: float in [-w * 0.28, w * 0.28]:
		Props.block(g, Vector3(bx - 0.02, y0, -d * 0.5 - 0.031), Vector3(bx + 0.02, h + 0.004, -d * 0.5 - 0.027), "steel")
		Props.block(g, Vector3(bx - 0.02, h, -d * 0.5 - 0.03), Vector3(bx + 0.02, h + 0.004, d * 0.5 + 0.03), "steel")
		Props.block(g, Vector3(bx - 0.02, y0, d * 0.5 + 0.027), Vector3(bx + 0.02, h + 0.004, d * 0.5 + 0.031), "steel")
		Props._noshadow(Props.block(g, Vector3(bx - 0.03, h * 0.62, -d * 0.5 - 0.036), Vector3(bx + 0.03, h * 0.62 + 0.05, -d * 0.5 - 0.031), "lead"))
	Props._noshadow(Props.obox(g, Vector3(w * 0.22, h * 0.8, -d * 0.5 - 0.034), Vector3(0.12, 0.17, 0.004), "paper_old", Vector3(0, 0, -7)))
	Props._noshadow(Props.obox(g, Vector3(w * 0.25, h * 0.8 + 0.12, -d * 0.5 - 0.033), Vector3(0.006, 0.09, 0.004), "rubber", Vector3(0, 0, -20)))
	if outdoor:   # a cap of snow on the lid, a drift against its foot
		Props.block(g, Vector3(-w * 0.5 - 0.02, h, -d * 0.5 - 0.02), Vector3(w * 0.5 + 0.02, h + 0.07, d * 0.5 + 0.02), "snow", false)
		Props.ball(g, Vector3(0, h + 0.06, 0), Vector3(w * 0.8, 0.1, d * 0.8), "snow").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Props.snow_drift(g, Vector3(0.1, 0, d * 0.5 + 0.1), Vector3(w + 0.5, 0.28, 0.7))
		Props.snow_drift(g, Vector3(-w * 0.5 - 0.1, 0, -0.05), Vector3(0.5, 0.2, d + 0.3))
	else:   # a crowbar left leaning on it, packing straw at its foot
		Props.obox(g, Vector3(w * 0.5 + 0.09, 0.42, d * 0.12), Vector3(0.026, 0.86, 0.026), "iron", Vector3(0, 0, 11))
		Hay.call("scatter", g, Vector3(-w * 0.2, 0, -d * 0.5 - 0.25), 0.45, 0.3, 10, 251 + String(spot_id).length(), 0)
	Props.bake(_filler)
	_body = StaticBody3D.new()
	_body.name = "FillerBody"
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.set_meta("no_mantle", true)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = CRATE
	cs.shape = box
	cs.position = Vector3(0, CRATE.y * 0.5, 0)
	_body.add_child(cs)
	add_child(_body)
