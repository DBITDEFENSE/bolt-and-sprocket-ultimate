class_name BallastCoffin
extends Interactable
## Map 2 "Ballast" (MAPS.md Map 2, T-036 follow-up): a lead-sealed Nachtglas coffin a player can lift and carry to
## the crane hook (BallastHook). Carrying is slow (the enemies.json `carry_status`, refreshed every tick) and the
## coffin rides in the carrier's arms; it goes back to its pallet if the carrier goes down. Tuning in
## data/gravelight/map02.json "ballast". Co-op: the host decides, every peer mirrors the lift / return.
## Ballast v2 (UPDATE 10 C2, T-153): the carrier's hands are limited to melee and the pistol slot
## (WeaponHolder.set_carry_limit); a coffin goes to the crane (BallastHook) or overboard (BallastDump), and a gone
## coffin comes back on a free pallet (respawn_at, driven by TotenhafenBallast).

@export var coffin_id: StringName = &"coffin"
@export var unit: String = "BLST-01"
@export var config_table: String = "map02"

var carrier: int = 0           # player id carrying it, 0 = on its pallet
var delivered: bool = false
## A delivered / dumped coffin is gone until respawn_at puts it back on a pallet.
var gone_at_ms: int = 0
var _art: Node3D
var _carried: Node3D


static func cfg(table: String = "map02") -> Dictionary:
	return GLData.load_json("res://data/gravelight/%s.json" % table).get("ballast", {})


func _ready() -> void:
	interact_size = Vector3(2.4, 1.2, 1.2)
	interact_offset = Vector3(0, 0.5, 0)
	super._ready()
	add_to_group(&"ballast_coffins")
	GLBus.player_downed.connect(_on_player_downed)


func build_greybox() -> void:
	_art = Node3D.new()
	_art.name = "Art"
	add_child(_art)
	Props.coffin(_art, Vector3.ZERO, 0.0, unit)


func get_prompt(player: Player) -> String:
	if delivered or carrier != 0:
		return ""
	if _someone_carrying(player.player_id):
		return "You already carry a coffin"
	return "Hold [%s] to lift the coffin (%s)" % [prompt_key(&"interact"), unit]


func can_interact(player: Player) -> bool:
	return not delivered and carrier == 0 and not _someone_carrying(player.player_id)


func hold_time(_player: Player) -> float:
	return float(cfg(config_table).get("lift_seconds", 1.2))


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	lift(player.player_id)
	Net.mirror(self, &"lift", [player.player_id])


## The coffin leaves its pallet for the carrier's arms.
func lift(pid: int) -> void:
	if carrier == pid:
		return
	carrier = pid
	_art.visible = false
	area.collision_layer = 0
	var p: Player = _player(pid)
	if p != null and p.weapons != null:
		p.weapons.set_carry_limit(true)
	if p != null:
		_carried = Node3D.new()
		_carried.name = "CarriedCoffin"
		var c: Dictionary = cfg(config_table)
		var off: Array = c.get("carry_offset", [0.0, 0.75, -0.9])
		_carried.position = Vector3(float(off[0]), float(off[1]), float(off[2]))
		_carried.rotation.y = PI * 0.5
		p.add_child(_carried)
		Props.coffin(_carried, Vector3(0, -0.3, 0), 0.0, unit, false)
	AudioDirector.play_3d("board_slam", global_position + Vector3.UP, -6.0, 0.0)
	GLVO.play_category(&"OPR", "BALLAST_LIFT")


## Back onto the pallet (the carrier went down, or the crane refused it).
func drop() -> void:
	var was: Player = _player(carrier) if carrier != 0 else null
	if was != null and was.weapons != null:
		was.weapons.set_carry_limit(false)
	carrier = 0
	if _carried != null and is_instance_valid(_carried):
		_carried.queue_free()
	_carried = null
	if not delivered:
		_art.visible = true
		area.collision_layer = LAYER_INTERACTABLE


## The crane took it.
func deliver() -> void:
	delivered = true
	drop()
	area.collision_layer = 0
	gone_at_ms = Time.get_ticks_msec()


## Back on a pallet at `pos` with a new stencil (every peer; the host decides where).
func respawn_at(pos: Vector3, new_unit: String) -> void:
	delivered = false
	carrier = 0
	global_position = pos
	if new_unit != "" and new_unit != unit:
		unit = new_unit
		if _art != null:
			for c: Node in _art.get_children():
				c.queue_free()
			Props.coffin(_art, Vector3.ZERO, 0.0, unit)
	if _art != null:
		_art.visible = true
	area.collision_layer = LAYER_INTERACTABLE


func _process(delta: float) -> void:
	if carrier == 0 or delivered:
		return
	var p: Player = _player(carrier)
	if p == null or not p.is_alive():
		drop()
		return
	var status: StringName = StringName(str(cfg(config_table).get("carry_status", "ballast")))
	p.apply_status(status, maxf(0.3, delta * 3.0))


func _on_player_downed(pid: int) -> void:
	if pid == carrier and Net.is_authority():
		drop()
		Net.mirror(self, &"drop")


func _player(pid: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return p
	return null


static func _someone_carrying(pid: int) -> bool:
	for n: Node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(&"ballast_coffins"):
		if int(n.get("carrier")) == pid:
			return true
	return false
