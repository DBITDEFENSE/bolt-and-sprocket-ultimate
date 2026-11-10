class_name LadderClimb
extends Interactable
## A ladder you can climb (T-229, the owner: "make sure ladders work on all maps"). Holding Use at the foot carries the
## player up the ladder line to `to_pos` (the view rising with them, weapons down: the radar tower's T-157 TowerLadder
## is one of these now); a second LadderClimb at the head, with `down` set, carries them back. `zone`: when set, the
## ladder waits for that zone to open (the trapdoor behind the Inn's bar waits for the Old Cellar's door). Zombies take
## the same ladders by their climb links (the map json's climb_links, ClimbLink); bots cannot (their mask leaves the
## climb layers out, T-153), so a ladder is never a route a bot must take.
## Data-driven per map: data/gravelight/<map>.json "ladders": [{"name": "...", "pos": [x, y, z] (where the player
## stands, at the foot or at the head), "yaw": degrees (local -Z toward the player), "to": [x, y, z] (where the
## climb ends), "down": false, "zone": "OLD_CELLAR", "target": "the trapdoor", "climb_s": 2.0 (optional),
## "locked_text": "The hatch is bolted from above"}]. MapRoot spawns them with the climb links.

@export var down: bool = false
@export var to_pos: Vector3 = Vector3.ZERO      # where the climb ends (world)
@export var climb_s: float = -1.0               # seconds on the ladder; <= 0: from the height at 1.6 m/s (0.8 s at least)
@export var zone: StringName = &""              # usable only once this zone is open ("" = always)
@export var target: String = "the ladder"       # "Hold [E] to climb up <target>"
@export var locked_text: String = "Locked"

var climbs: int = 0                             # the smokes count these
var _busy: Dictionary = {}                      # player id -> true while climbing


func _ready() -> void:
	interact_size = Vector3(1.2, 2.0, 1.0)
	interact_offset = Vector3(0, 1.0, 0)
	super._ready()
	add_to_group(&"ladders")


func get_prompt(_player: Player) -> String:
	if not _open():
		return locked_text
	return "Hold [%s] to climb %s %s" % [prompt_key(&"interact"), "down" if down else "up", target]


func can_interact(player: Player) -> bool:
	return _open() and player != null and player.is_alive() and not bool(player.get("downed")) and not _busy.has(player.player_id)


func hold_time(_player: Player) -> float:
	return 0.4


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	climb(player)


## The climb moves the user's own body: it runs on their machine (co-op), like the other movement.
func net_local() -> bool:
	return true


func _open() -> bool:
	return zone == &"" or GameState.is_zone_open(zone)


## Seconds on the ladder line for this climb.
func ride_seconds(from_y: float) -> float:
	if climb_s > 0.0:
		return climb_s
	return maxf(0.8, absf(to_pos.y - from_y) / 1.6)


## The climb: onto the ladder line (this node's x, z), up or down it, then off at to_pos. Physics is off meanwhile
## (the body is carried through the hatch or over the rail it climbs past), the view stays the player's.
func climb(player: Player) -> void:
	_busy[player.player_id] = true
	climbs += 1
	var from: Vector3 = player.global_position
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var line: Vector3 = global_position
	var tw: Tween = create_tween()
	tw.tween_property(player, "global_position", Vector3(line.x, from.y, line.z), 0.25)
	tw.tween_property(player, "global_position", Vector3(line.x, to_pos.y, line.z), ride_seconds(from.y))
	tw.tween_property(player, "global_position", to_pos, 0.35)
	tw.finished.connect(func() -> void:
		if is_instance_valid(player):
			player.set_physics_process(true)
			player.velocity = Vector3.ZERO
			AudioDirector.play_3d("footstep_metal", to_pos + Vector3.UP * 0.2, -4.0)
		_busy.erase(player.player_id))
	AudioDirector.play_3d("footstep_metal", line + Vector3.UP, 0.0)


## Spawns every ladder the map's json lists under `root` (a "Ladders" holder). Returns them.
static func spawn_all(root: Node3D, map_id: StringName) -> Array[LadderClimb]:
	var out: Array[LadderClimb] = []
	var path: String = ClimbLink.json_path_for(map_id)
	if path == "" or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		return out
	var rows: Array = GLData.load_json(path).get("ladders", [])
	if rows.is_empty():
		return out
	var holder: Node3D = Node3D.new()
	holder.name = "Ladders"
	root.add_child(holder)
	var i: int = 0
	for row: Dictionary in rows:
		var l: LadderClimb = LadderClimb.new()
		l.name = str(row.get("name", "Ladder_%d" % i))
		l.down = bool(row.get("down", false))
		l.to_pos = ClimbLink._v3(row.get("to", [0, 0, 0]))
		l.climb_s = float(row.get("climb_s", -1.0))
		l.zone = StringName(str(row.get("zone", "")))
		l.target = str(row.get("target", "the ladder"))
		l.locked_text = str(row.get("locked_text", "Locked"))
		l.position = ClimbLink._v3(row.get("pos", [0, 0, 0]))
		l.rotation.y = deg_to_rad(float(row.get("yaw", 0.0)))
		holder.add_child(l)
		out.append(l)
		i += 1
	return out
