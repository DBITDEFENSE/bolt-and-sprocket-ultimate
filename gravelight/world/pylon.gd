class_name Pylon
extends Interactable
## Resonance Pylon (Map 1): after power, pay 1500 to start a 45 s holdout. It charges only while a player
## stands inside the ring, pauses when empty, and after 3 s empty drains at 2 %/s, never below the last
## 25 % checkpoint. While charging: ×2 spawns in its zone, 2 temp ground spawns at the ring, and the
## round can't end. Three attuned pylons open the Core Vault (flag core_vault_open, zone I_CORE).

enum State { IDLE, CHARGING, ATTUNED }

@export var pylon_id: StringName = &"p1"
@export var zone_id: StringName = &"A_MINEHEAD"
@export var radius: float = 8.0
## Attunement note ("d", "f" or "a"); empty = from PYLON_NOTE by pylon_id (the three pylons spell D minor).
@export var note: StringName = &""

const PYLON_NOTE: Dictionary = {&"a": "d", &"f": "f", &"h": "a"}

var state: State = State.IDLE
var progress: float = 0.0
var _empty_t: float = 0.0
var _was_occupied: bool = true
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D   # the crystal's glow: dull before power, pulsing while charging, bright when attuned
var _beam: MeshInstance3D
var _hud: CanvasLayer
var _hud_label: Label
var _hum: AudioStreamPlayer3D   # looping charge hum (child): plays only while CHARGING
var _net_t: float = 0.0         # co-op: progress updates to the clients (4 Hz)


static func cfg() -> Dictionary:
	return PowerSwitch.map01()["pylon"]


## Pure: the checkpoint the charge can't drain below.
static func checkpoint(p: float, step: float) -> float:
	return floorf(p / step + 0.00001) * step


## Pure: one charge step. Returns [new_progress, new_empty_time].
static func step_charge(p: float, dt: float, occupied: bool, empty_t: float, c: Dictionary) -> Array:
	if occupied:
		return [minf(1.0, p + dt / float(c["charge_seconds"])), 0.0]
	empty_t += dt
	if empty_t > float(c["drain_grace_seconds"]):
		var floor_p: float = checkpoint(p, float(c["checkpoint_step"]))
		p = maxf(floor_p, p - float(c["drain_per_second"]) * dt)
	return [p, empty_t]


## Pure: does this attuned count open the vault?
static func vault_opens(attuned_count: int, required: int) -> bool:
	return attuned_count >= required


func _ready() -> void:
	interact_size = Vector3(1.4, 2.0, 0.3)
	interact_offset = Vector3(0, 1.0, -0.6)
	super._ready()
	add_to_group(&"pylons")
	_build_ring()
	_hud = CanvasLayer.new()
	_hud.layer = 12
	_hud_label = Label.new()
	_hud_label.anchor_left = 0.0
	_hud_label.anchor_right = 1.0
	_hud_label.offset_top = 90.0
	_hud_label.offset_bottom = 130.0
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.add_theme_font_size_override("font_size", 30)
	_hud_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	_hud_label.add_theme_constant_override("outline_size", 6)
	_hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud.add_child(_hud_label)
	_hud.visible = false
	add_child(_hud)
	_hum = AudioDirector.make_loop_3d("pylon_hum", self)
	if _hum != null:
		_hum.position = Vector3.UP * 3.2
	GLBus.power_activated.connect(func() -> void: _ring_mat.emission_energy_multiplier = 0.6)


func build_greybox() -> void:
	# plinth, copper coil, lattice mast, insulator stack, brass cradle and plaque (cached)
	InteractableArt.place(self, "pylon_body", func(r: Node3D) -> void: InteractableArt.pylon_body(r))
	_core = InteractableArt.place(self, "pylon_crystal", func(r: Node3D) -> void: InteractableArt.pylon_crystal(r), Vector3(0, 3.28, 0), false)
	_core_mat = (Mats.get_mat("nachtglas_crystal") as StandardMaterial3D).duplicate() as StandardMaterial3D
	_core.material_override = _core_mat
	var l: Label3D = add_label(self, "RESONANCE PYLON", Vector3(0, 0.908, -0.52), 22, Color(0.9, 0.78, 1.0))
	l.rotation.x = deg_to_rad(-20.0)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = radius - 0.12
	t.outer_radius = radius
	_ring.mesh = t
	_ring_mat = greybox_mat(Color(0.55, 0.25, 1.0), 0.15)
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _ring_mat
	_ring.position = Vector3(0, 0.05, 0)
	_ring.scale = Vector3(1, 0.2, 1)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_beam = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.6
	cyl.height = 40.0
	_beam.mesh = cyl
	var bm: StandardMaterial3D = greybox_mat(Color(0.6, 0.3, 1.0), 5.0)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color.a = 0.45
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam.material_override = bm
	_beam.position = Vector3(0, -16.0, 0)   # fires down toward the Core
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)


func get_prompt(player: Player) -> String:
	match state:
		State.IDLE:
			if not GameState.power_on:
				return "Power must be activated"
			return "Hold [%s] to attune the Resonance Pylon [%s]" % [prompt_key(&"interact"), price_str(player, int(cfg()["cost"]))]
	return ""


func can_interact(_player: Player) -> bool:
	return state == State.IDLE and GameState.power_on


func interact(player: Player) -> void:
	if state != State.IDLE or not GameState.power_on:
		return
	if not try_purchase(player, StringName("pylon_" + String(pylon_id)), int(cfg()["cost"])):
		return
	start_charge()


func start_charge() -> void:
	state = State.CHARGING
	_empty_t = 0.0
	_was_occupied = true
	Net.mirror(self, &"_net_charge", [progress, true])
	var c: Dictionary = cfg()
	var dir: ZombieDirector = _director()
	if dir != null:
		dir.set_spawn_boost(zone_id, float(c["spawn_boost"]))
		var pts: Array = []
		for i: int in int(c["temp_spawns"]):
			var a: float = randf() * TAU
			pts.append(global_position + Vector3(cos(a), 0, sin(a)) * (radius + 1.0))
		dir.add_temp_spawns(_key(), pts, zone_id)
	RoundManager.set_hold(_key(), true)
	_ring_mat.emission_energy_multiplier = 2.5
	if _hum != null and not _hum.playing:
		_hum.play()
	GLVO.play(StringName(str(c["vo_start"])))
	GLBus.pylon_state_changed.emit(pylon_id, &"charging")


func _key() -> StringName:
	return StringName("pylon_" + String(pylon_id))


func _director() -> ZombieDirector:
	return get_tree().get_first_node_in_group(&"director") as ZombieDirector


func _local_player_in_range() -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive() and _in_ring(p.global_position):
			return true
	return false


func _in_ring(p: Vector3) -> bool:
	var d: Vector3 = p - global_position
	return Vector2(d.x, d.z).length() <= radius and absf(d.y) < 4.0


func _process(delta: float) -> void:
	if _core != null:
		_core.rotation.y += delta * (3.0 if state == State.CHARGING else 0.6)
		if _core_mat != null:
			var e: float = 0.25
			match state:
				State.CHARGING:
					e = 1.6 + sin(Time.get_ticks_msec() * 0.008) * 0.6
				State.ATTUNED:
					e = 3.0
				_:
					e = 1.0 if GameState.power_on else 0.25
			_core_mat.emission_energy_multiplier = e
	if state != State.CHARGING:
		_hud.visible = false
		return
	if Net.is_client():
		# the host charges it; here only the ring, the hum and (for a player in the ring) the percentage
		var me: Player = Net.session.local_player if Net.session != null else null
		_hud.visible = me != null and me.is_alive() and _in_ring(me.global_position)
		_hud_label.text = "RESONANCE PYLON   %d%%" % int(progress * 100.0)
		_ring_mat.emission_energy_multiplier = (2.0 + sin(Time.get_ticks_msec() * 0.01) * 0.8) if _was_occupied else 0.8
		return
	var occupied: bool = _local_player_in_range()
	var res: Array = step_charge(progress, delta, occupied, _empty_t, cfg())
	progress = float(res[0])
	_empty_t = float(res[1])
	if occupied != _was_occupied:
		_was_occupied = occupied
		GLBus.pylon_state_changed.emit(pylon_id, &"charging" if occupied else &"paused")
		if not occupied:
			GLVO.play(StringName(str(cfg()["vo_pause"])))
	_hud.visible = occupied
	_hud_label.text = "RESONANCE PYLON   %d%%" % int(progress * 100.0)
	_net_t -= delta
	if _net_t <= 0.0:
		_net_t = 0.25
		Net.mirror(self, &"_net_charge", [progress, occupied])
	_ring_mat.emission_energy_multiplier = (2.0 + sin(Time.get_ticks_msec() * 0.01) * 0.8) if occupied else 0.8
	if progress >= 1.0:
		_complete()


## Co-op client: the host's charge.
func _net_charge(p: float, occupied: bool) -> void:
	if state == State.ATTUNED:
		return
	if state == State.IDLE:
		state = State.CHARGING
		_ring_mat.emission_energy_multiplier = 2.5
		if _hum != null and not _hum.playing:
			_hum.play()
	progress = p
	_was_occupied = occupied


## Co-op client: attuned on the host.
func _net_attuned() -> void:
	state = State.ATTUNED
	progress = 1.0
	_hud.visible = false
	_beam.visible = true
	_ring_mat.emission_energy_multiplier = 3.0
	if _hum != null:
		_hum.stop()
	AudioDirector.play_3d("pylon_attune_" + attune_note(), global_position + Vector3.UP * 2.0, 2.0, 0.0)


func _complete() -> void:
	state = State.ATTUNED
	_hud.visible = false
	Net.mirror(self, &"_net_attuned")
	var c: Dictionary = cfg()
	var dir: ZombieDirector = _director()
	if dir != null:
		dir.set_spawn_boost(zone_id, 1.0)
		dir.remove_temp_spawns(_key())
	RoundManager.set_hold(_key(), false)
	_beam.visible = true
	_ring_mat.emission_energy_multiplier = 3.0
	if _hum != null:
		_hum.stop()
	AudioDirector.play_3d("pylon_attune_" + attune_note(), global_position + Vector3.UP * 2.0, 2.0, 0.0)
	GameState.set_flag(StringName("pylon_" + String(pylon_id)), true)
	var count: int = int(GameState.flags.get(&"pylons_attuned", 0)) + 1
	GameState.set_flag(&"pylons_attuned", count)
	GLBus.pylon_state_changed.emit(pylon_id, &"attuned")
	GLVO.play(StringName(str(c["vo_done"])))
	if vault_opens(count, int(c["required"])):
		_open_vault()


func _open_vault() -> void:
	var c: Dictionary = cfg()
	GameState.open_zone(&"I_CORE")
	GameState.set_flag(&"core_vault_open", true)
	GLBus.explosion.emit(global_position, 30.0)   # the whole-map shake moment
	GLVO.play(StringName(str(c["vo_vault_operator"])))
	get_tree().create_timer(4.0).timeout.connect(func() -> void: GLVO.play(StringName(str(c["vo_vault_reinholt"]))))


## "d" / "f" / "a": this pylon's note (export override, else by pylon_id, else from the id's hash).
func attune_note() -> String:
	if note != &"":
		return String(note)
	if PYLON_NOTE.has(pylon_id):
		return str(PYLON_NOTE[pylon_id])
	return ["d", "f", "a"][absi(hash(pylon_id)) % 3]


## Dev/quest: instantly attune.
func debug_attune() -> void:
	if state == State.ATTUNED:
		return
	if state == State.IDLE:
		start_charge()
	progress = 1.0
	_complete()
