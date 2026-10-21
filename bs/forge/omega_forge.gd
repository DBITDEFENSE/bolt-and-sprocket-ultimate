class_name OmegaForge
extends Node3D
## BLARTZ'S OMEGA FORGE (BS_WEAPONS §2.4-2.5). A level places one with OmegaForge.new() (usually bolted to the
## side of a Blartz kiosk), positions it and add_child()s it. Walk up and press interact:
##   - before the unlock flag (data/bs/forge.json "unlock_flag", story beat blartzRescue, M4): a "cold forge" hint
##   - the first visit plays Blartz's schematics dialogue (bs.forge.blartz.01-11) once
##   - then the Forge screen (ui/bs/forge_ui.gd) opens: install / swap Signature Mods and EVOLVE
## evolve(id): WeaponManager.can_evolve() (deny lines bs.forge.deny.01-04 are spoken), spends 2,000 bolts, sets the
## Omega flag, then plays the ~8 s evolution cutscene (door slam + bellows, gold flare, Ω stamp + banner with the
## Omega name, Blartz's per-weapon line). The cutscene is skippable after the first one (skip()).
## Look: a squat Blartz-green furnace with gold trim, exposed coils, taped warnings, a heat-glass window with the
## gun floating inside, a hand-cranked bellows and the brass plaque "BLARTZ'S OMEGA FORGE · MOD. Ω-1 · PAT. PEND.
## BLZ-40417". All procedural. The interact volume is on physics layer 5 (interactables), like the kiosk.

signal evolved(weapon_id: StringName)
signal cutscene_finished(weapon_id: StringName)
signal opened

const DATA: String = "bs/forge"

## Dev console / tests: treat every Forge as unlocked (ForgeDebug.open_forge sets it).
static var debug_unlock: bool = false

@export var unlocked_override: bool = false

var F: Dictionary = {}
var target: bool = false
var playing: bool = false
var cut_id: StringName = &""
var cut_t: float = 0.0
var cut_step: int = -1
var intro_playing: bool = false
var _intro_i: int = 0
var _intro_t: float = 0.0
var _ui: Node = null
var _door: Node3D
var _window_mat: StandardMaterial3D
var _bellows: Node3D
var _crank: Node3D
var _gun_holder: Node3D
var _stamp: Label3D
var _age: float = 0.0


static func cfg() -> Dictionary:
	return Data.table(DATA) as Dictionary if Data.has_table(DATA) else {}


func _ready() -> void:
	F = cfg()
	process_mode = Node.PROCESS_MODE_ALWAYS       # the cutscene runs while the Forge screen pauses the world
	add_to_group(&"interactables")
	add_to_group(&"omega_forge")
	_build_visual()
	var area: Area3D = Area3D.new()
	area.collision_layer = 1 << 4
	area.collision_mask = 0
	area.monitoring = false
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: SphereShape3D = SphereShape3D.new()
	sh.radius = float(F.get("interact_radius", 3.0))
	cs.shape = sh
	area.add_child(cs)
	add_child(area)


func _exit_tree() -> void:
	if target:
		EventBus.interact_prompt.emit("")


func is_unlocked() -> bool:
	return debug_unlock or unlocked_override or BS.flag(str(F.get("unlock_flag", "blartzRescue")))


func manager() -> WeaponManager:
	var b: Node = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	return b.get_node_or_null("Weapons") as WeaponManager if b != null else null


func _process(dt: float) -> void:
	_age += dt
	_animate(dt)
	if playing:
		_cut_tick(dt)
	if intro_playing:
		_intro_tick(dt)
	var b: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var t: bool = b != null and not BS.blocked() and b.global_position.distance_to(global_position) < float(F.get("interact_radius", 3.0))
	if t != target:
		target = t
		EventBus.interact_prompt.emit(prompt_text() if t else "")
	if t and not BS.blocked() and not playing and Input.is_action_just_pressed(&"interact"):
		interact()


func prompt_text() -> String:
	var key: String = "Y" if AimAssist.last_device == "pad" else "E"
	return "[%s] %s" % [key, WeaponText.text("bs.forge.ui.prompt")]


## What pressing interact does right now: "locked", "intro" (first visit; the screen opens after it) or "open".
func interact() -> String:
	if not is_unlocked():
		WeaponText.hint("bs.forge.ui.locked", "forgelocked")
		return "locked"
	if not BS.flag(str(F.get("intro_flag", "forge.intro_seen"))):
		BS.set_flag(str(F.get("intro_flag", "forge.intro_seen")))
		start_intro()
		return "intro"
	open_ui()
	return "open"


func start_intro() -> void:
	intro_playing = true
	_intro_i = 0
	_intro_t = 0.0


func _intro_tick(dt: float) -> void:
	_intro_t -= dt
	if _intro_t > 0.0:
		return
	var ids: Array = F.get("intro_lines", [])
	if _intro_i >= ids.size():
		intro_playing = false
		open_ui()
		return
	var lid: String = str(ids[_intro_i])
	_intro_i += 1
	WeaponText.say(lid)
	_intro_t = 1.2 + WeaponText.text(lid).length() * 0.055 + float(F.get("intro_gap", 0.4))


func skip_intro() -> void:
	if not intro_playing:
		return
	intro_playing = false
	open_ui()


func open_ui() -> Node:
	if _ui != null and is_instance_valid(_ui):
		return _ui
	var script: GDScript = load("res://ui/bs/forge_ui.gd") as GDScript
	_ui = script.call("open", get_tree(), self)
	opened.emit()
	return _ui


# ------------------------------------------------------------------ evolution

## Why `id` can't evolve ("" = ready): the deny line id.
func check(id: StringName) -> String:
	var m: WeaponManager = manager()
	if m == null:
		return "bs.forge.deny.01"
	return m.can_evolve(id)


## Try to evolve: speaks the deny line and returns it, or spends the bolts, sets Ω and starts the cutscene ("").
func evolve(id: StringName, free: bool = false) -> String:
	var m: WeaponManager = manager()
	if m == null or not m.owns(id):
		WeaponText.say("bs.forge.deny.01")
		return "bs.forge.deny.01"
	if not free:
		var why: String = m.can_evolve(id)
		if why != "":
			WeaponText.say(why)
			return why
	if not m.evolve(id, free):
		return "bs.forge.deny.04"
	evolved.emit(id)
	start_cutscene(id)
	return ""


func can_skip() -> bool:
	var C: Dictionary = F.get("cutscene", {})
	return not bool(C.get("skippable_after_first", true)) or BS.flag(str(F.get("evolve_seen_flag", "forge.evolve_seen")))


func start_cutscene(id: StringName) -> void:
	playing = true
	cut_id = id
	cut_t = 0.0
	cut_step = -1
	_show_gun(id, false)
	_stamp.visible = false


func _beat(i: int) -> float:
	var C: Dictionary = F.get("cutscene", {})
	var keys: Array[String] = ["door", "bellows", "flare", "stamp", "line"]
	var t: float = 0.0
	for k: int in i + 1:
		t += float(C.get(keys[k], 1.0))
	return t


func cutscene_length() -> float:
	return _beat(4)


func _cut_tick(dt: float) -> void:
	cut_t += dt
	while cut_step < 4 and cut_t >= (0.0 if cut_step < 0 else _beat(cut_step)):
		cut_step += 1
		_enter_step(cut_step)
	if cut_t >= cutscene_length():
		_finish_cutscene()


## 0 door slam + bellows, 1 crank, 2 gold flare + reshape, 3 Ω stamp + banner, 4 Blartz's line.
func _enter_step(i: int) -> void:
	match i:
		0:
			_door.rotation.y = 0.0
			WeaponFX.flash(self, global_position + Vector3(0, 1.0, 0.9), Color(1, 0.8, 0.4), 0.5, 0.15)
		1:
			pass
		2:
			_window_mat.emission_energy_multiplier = 4.0
			_show_gun(cut_id, true)
			WeaponFX.blast(self, global_position + Vector3(0, 1.1, 0.75), 1.4, _col("gold", "#ffd23e"))
		3:
			_stamp.visible = true
			EventBus.banner.emit(WeaponData.display_name(cut_id, true), WeaponData.display_name(cut_id, false),
				float((F.get("cutscene", {}) as Dictionary).get("banner_time", 2.6)))
		4:
			var line: String = str(WeaponData.def(cut_id).get("omega_line", ""))
			if line != "":
				WeaponText.say(line)


func skip() -> bool:
	if not playing or not can_skip():
		return false
	for i: int in range(cut_step + 1, 5):
		if i >= 3:
			_enter_step(i)
	_finish_cutscene()
	return true


func _finish_cutscene() -> void:
	if not playing:
		return
	playing = false
	cut_step = 5
	BS.set_flag(str(F.get("evolve_seen_flag", "forge.evolve_seen")))
	_window_mat.emission_energy_multiplier = 1.2
	_door.rotation.y = -1.2
	var id: StringName = cut_id
	cutscene_finished.emit(id)
	var m: WeaponManager = manager()
	if m != null:
		m.wheel_changed.emit()


# ------------------------------------------------------------------ look

func _col(key: String, fallback: String) -> Color:
	return Color.from_string(str((F.get("look", {}) as Dictionary).get(key, fallback)), Color.WHITE)


func _build_visual() -> void:
	var green: StandardMaterial3D = BoltVisual._mat(_col("green", "#3fae5f"), 0.2)
	var gold: StandardMaterial3D = BoltVisual._mat(_col("gold", "#ffd23e"), 0.85)
	var dark: StandardMaterial3D = BoltVisual._mat(_col("dark", "#2a2f3a"), 0.5)
	BoltVisual._box(self, Vector3(1.8, 1.5, 1.4), Vector3(0, 0.75, 0), green)                 # squat furnace
	BoltVisual._box(self, Vector3(1.95, 0.1, 1.55), Vector3(0, 1.52, 0), gold)                # gold trim
	BoltVisual._box(self, Vector3(1.95, 0.1, 1.55), Vector3(0, 0.05, 0), gold)
	BoltVisual._cyl(self, 0.22, 0.9, Vector3(0.45, 2.0, -0.3), dark)                          # chimney
	BoltVisual._cyl(self, 0.26, 0.08, Vector3(0.45, 2.45, -0.3), gold)
	for i: int in 3:                                                                         # exposed coils
		var coil: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.16
		tm.outer_radius = 0.2
		coil.mesh = tm
		coil.material_override = WeaponFX.glow_mat(_col("coil", "#ff8a2e"))
		coil.position = Vector3(-0.92, 0.45 + i * 0.32, 0.2)
		coil.rotation.z = PI / 2.0
		add_child(coil)
	for z: float in [-0.35, 0.35]:                                                            # taped warnings
		var tape: MeshInstance3D = BoltVisual._box(self, Vector3(0.6, 0.08, 0.02), Vector3(0.45, 0.35, 0.71), BoltVisual._mat(_col("tape", "#ffd23e")))
		tape.rotation.z = z
	# heat-glass window + door
	var win: MeshInstance3D = MeshInstance3D.new()
	var wb: BoxMesh = BoxMesh.new()
	wb.size = Vector3(0.8, 0.6, 0.04)
	win.mesh = wb
	_window_mat = StandardMaterial3D.new()
	_window_mat.albedo_color = Color(_col("glass", "#ffb44d"), 0.55)
	_window_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_window_mat.emission_enabled = true
	_window_mat.emission = _col("glass", "#ffb44d")
	_window_mat.emission_energy_multiplier = 1.2
	win.material_override = _window_mat
	win.position = Vector3(-0.2, 0.95, 0.72)
	add_child(win)
	_door = Node3D.new()
	_door.position = Vector3(-0.62, 0.95, 0.73)
	add_child(_door)
	BoltVisual._box(_door, Vector3(0.86, 0.68, 0.05), Vector3(0.43, 0, 0.02), dark)
	_door.rotation.y = -1.2
	_gun_holder = Node3D.new()
	_gun_holder.position = Vector3(-0.2, 0.95, 0.45)
	add_child(_gun_holder)
	# hand-cranked bellows on the side
	_bellows = Node3D.new()
	_bellows.position = Vector3(1.05, 0.6, 0.1)
	add_child(_bellows)
	BoltVisual._box(_bellows, Vector3(0.3, 0.5, 0.6), Vector3.ZERO, BoltVisual._mat(Color("#8b5a2b")))
	_crank = Node3D.new()
	_crank.position = Vector3(0.2, 0.0, 0.0)
	_bellows.add_child(_crank)
	BoltVisual._box(_crank, Vector3(0.05, 0.4, 0.05), Vector3(0, 0.2, 0), gold)
	# brass plaque
	var plaque: Label3D = Label3D.new()
	plaque.name = "Plaque"
	plaque.text = WeaponText.text("bs.forge.plaque")
	plaque.modulate = _col("gold", "#ffd23e")
	plaque.font_size = 28
	plaque.outline_size = 6
	plaque.pixel_size = 0.004
	plaque.position = Vector3(0, 1.32, 0.72)
	add_child(plaque)
	BoltVisual._box(self, Vector3(1.3, 0.12, 0.02), Vector3(0, 1.32, 0.705), BoltVisual._mat(Color("#b08d3a"), 0.9))
	_stamp = Label3D.new()
	_stamp.text = "Ω"
	_stamp.modulate = _col("gold", "#ffd23e")
	_stamp.font_size = 160
	_stamp.outline_size = 16
	_stamp.pixel_size = 0.004
	_stamp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stamp.position = Vector3(-0.2, 1.7, 0.75)
	_stamp.visible = false
	add_child(_stamp)


func _show_gun(id: StringName, evolved_look: bool) -> void:
	for c: Node in _gun_holder.get_children():
		c.queue_free()
	var g: Node3D = Node3D.new()
	g.rotation.y = PI / 2.0
	g.scale = Vector3.ONE * 1.4
	_gun_holder.add_child(g)
	GunModels.build(g, id, 5, evolved_look)


func _animate(dt: float) -> void:
	if _gun_holder != null:
		_gun_holder.rotation.y += dt * 0.8
		_gun_holder.position.y = 0.95 + sin(_age * 2.0) * 0.04
	if playing and cut_step >= 0 and cut_step <= 1:
		_crank.rotation.x += dt * 9.0
		_bellows.scale.y = 1.0 + sin(_age * 9.0) * 0.18
	elif _bellows != null:
		_bellows.scale.y = lerpf(_bellows.scale.y, 1.0, dt * 4.0)
	if _window_mat != null:
		var base: float = 1.2 + sin(_age * 3.0) * 0.2
		_window_mat.emission_energy_multiplier = lerpf(_window_mat.emission_energy_multiplier, base, dt * 1.5)
