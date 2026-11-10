class_name ZipLine
extends Interactable
## A zip line (T-229, the owner: "a sniper tower with a zipline"): a cable from a high anchor down to a post. The node
## stands at the anchor, the trolley hangs from it; holding Use there hangs the player from the trolley's bar and runs
## them down the sagging line (the trolley with them), dropping them at `to_pos`. The ride owns the body like a ladder
## climb (physics off, weapons down, the view free); bots and zombies never take it. The cable and its posts are the
## generator's dressing; the trolley is drawn here so it can travel.
## Data-driven per map: data/gravelight/<map>.json "ziplines": [{"name": "...", "pos": [x, y, z] (the anchor, the
## cable's top), "end": [x, y, z] (the cable's low end on its post), "to": [x, y, z] (the landing, feet),
## "yaw": degrees (local -Z toward the rider), "speed": 7.0, "hang": 2.0 (the cable above the rider's feet),
## "sag": 0.3, "target": "down to the yard"}]

@export var end_pos: Vector3 = Vector3.ZERO     # the cable's low end (world)
@export var to_pos: Vector3 = Vector3.ZERO      # where the rider is set down (feet)
@export var speed: float = 7.0                  # m/s along the line
@export var hang: float = 2.0                   # the cable this far above the rider's feet
@export var sag: float = 0.3                    # the cable's dip at mid-span
@export var target: String = "down the line"

var rides: int = 0                              # the smokes count these
var _busy: Dictionary = {}                      # player id -> true while riding
var _trolley: Node3D = null


func _ready() -> void:
	interact_size = Vector3(1.4, 1.8, 1.4)
	interact_offset = Vector3(0, -0.9, 0)        # the bar hangs under the anchor, where a standing rider's hands are
	super._ready()
	add_to_group(&"ziplines")
	_build_trolley()


func get_prompt(_player: Player) -> String:
	return "Hold [%s] to ride the zip line %s" % [prompt_key(&"interact"), target]


func can_interact(player: Player) -> bool:
	return player != null and player.is_alive() and not bool(player.get("downed")) and not _busy.has(player.player_id)


func hold_time(_player: Player) -> float:
	return 0.35


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	ride(player)


func net_local() -> bool:
	return true


## A point on the cable, t 0 at the anchor .. 1 at the low end, with the sag.
func cable_point(t: float) -> Vector3:
	return global_position.lerp(end_pos, t) - Vector3.UP * (sag * 4.0 * t * (1.0 - t))


func ride_seconds() -> float:
	return maxf(0.6, global_position.distance_to(end_pos) / maxf(0.5, speed))


## The ride: up to the bar (the rider hangs `hang` under the cable), down the line with the trolley, then set down.
func ride(player: Player) -> void:
	_busy[player.player_id] = true
	rides += 1
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var tw: Tween = create_tween()
	tw.tween_property(player, "global_position", cable_point(0.0) - Vector3.UP * hang, 0.3)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(player):
			var c: Vector3 = cable_point(t)
			player.global_position = c - Vector3.UP * hang
			if _trolley != null:
				_trolley.global_position = c, 0.0, 1.0, ride_seconds()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(player, "global_position", to_pos, 0.25)
	tw.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.set_physics_process(true)
			player.velocity = Vector3.ZERO
			AudioDirector.play_3d("footstep_metal", to_pos + Vector3.UP * 0.2, -3.0)
		_busy.erase(player.player_id)
		_park_trolley())
	AudioDirector.play_3d("amb_m1_cable_creak", global_position, 2.0)


func _park_trolley() -> void:
	if _trolley != null:
		var tw: Tween = create_tween()
		tw.tween_property(_trolley, "global_position", global_position, 0.6).set_delay(1.5)


## The trolley: two wheels astride the cable, a hanger, the bar. Oriented along the cable.
func _build_trolley() -> void:
	_trolley = Node3D.new()
	_trolley.name = "Trolley"
	add_child(_trolley)
	var dir: Vector3 = (end_pos - global_position)
	dir.y = 0.0
	if dir.length() > 0.01:
		_trolley.rotation.y = atan2(-dir.x, -dir.z)
	for sx: float in [-0.06, 0.06]:
		Props.cyl(_trolley, Vector3(sx, 0.0, 0.0), 0.09, 0.03, "steel", Vector3(0, 0, 90))
	Props.block(_trolley, Vector3(-0.08, -0.14, -0.05), Vector3(0.08, -0.06, 0.05), "iron")
	Props.block(_trolley, Vector3(-0.02, -0.56, -0.02), Vector3(0.02, -0.12, 0.02), "iron")   # the hanger
	Props.cyl(_trolley, Vector3(0, -0.56, 0), 0.02, 0.64, "beam", Vector3(0, 0, 90))          # the bar
	for sx2: float in [-0.3, 0.3]:
		Props.cyl(_trolley, Vector3(sx2, -0.56, 0), 0.03, 0.08, "iron", Vector3(0, 0, 90))


## Spawns every zip line the map's json lists under `root` (a "ZipLines" holder). Returns them.
static func spawn_all(root: Node3D, map_id: StringName) -> Array[ZipLine]:
	var out: Array[ZipLine] = []
	var path: String = ClimbLink.json_path_for(map_id)
	if path == "" or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return out
	var rows: Array = GLData.load_json(path).get("ziplines", [])
	if rows.is_empty():
		return out
	var holder: Node3D = Node3D.new()
	holder.name = "ZipLines"
	root.add_child(holder)
	var i: int = 0
	for row: Dictionary in rows:
		var z: ZipLine = ZipLine.new()
		z.name = str(row.get("name", "ZipLine_%d" % i))
		z.end_pos = ClimbLink._v3(row.get("end", [0, 0, 0]))
		z.to_pos = ClimbLink._v3(row.get("to", [0, 0, 0]))
		z.speed = float(row.get("speed", 7.0))
		z.hang = float(row.get("hang", 2.0))
		z.sag = float(row.get("sag", 0.3))
		z.target = str(row.get("target", "down the line"))
		z.position = ClimbLink._v3(row.get("pos", [0, 0, 0]))
		z.rotation.y = deg_to_rad(float(row.get("yaw", 0.0)))
		holder.add_child(z)
		out.append(z)
		i += 1
	return out
