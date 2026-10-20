class_name Sprocket
extends Node3D
## Sprocket, Bolt's floating companion (makeSprocket / updateSprocket / setSprocketExpr / showBark,
## index.html:2919, 3900-3999, 11267). Springs after a point over Bolt's left shoulder in his facing frame,
## has one big eye with four moods (normal, happy, alarmed, smug) and blinks. Barks (SprocketBarks) are
## driven by EventBus: player_damaged -> lowhp, enemy_killed -> bolts + combat, idle input -> idle; other
## systems' bark ids (EventBus.bark, e.g. Bolt's splash quips) are voiced here too. Super Sprocket is the
## SuperProtocol child. Group "sprocket".
##
## API: bolt, mood, set_mood(m, secs), bark(line_id), barks: SprocketBarks, super: SuperProtocol,
##      damage_mult() (2.0 while the protocol runs), static damage_mult_for(tree) for weapons/enemies,
##      voice_filter + set_voice_filter(id) (firmware cosmetic hook: stored, not applied yet; later milestone).

signal mood_changed(mood: StringName)
signal barked(line_id: String)

const MOODS: Array[StringName] = [&"normal", &"happy", &"alarmed", &"smug"]
const EYE_CYAN: Color = Color("#3ee6ff")
const EYE_RED: Color = Color("#ff2222")

var F: Dictionary
var M: Dictionary
var bolt: Bolt = null
var mood: StringName = &"normal"
var mood_t: float = 0.0
var barks: SprocketBarks
var super_protocol: SuperProtocol
var voice_filter: StringName = &""
var vel: Vector3 = Vector3.ZERO
var t: float = 0.0
var blink_t: float = 3.0
var blinking: bool = false
var _head: Node3D
var _eye: MeshInstance3D
var _lid: MeshInstance3D
var _eye_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D
var _kit: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _placed: bool = false


func _ready() -> void:
	var D: Dictionary = Data.table("bs/sprocket")
	F = D["follow"]
	M = D["moods"]
	add_to_group(&"sprocket")
	barks = SprocketBarks.new()
	super_protocol = SuperProtocol.new()
	super_protocol.name = "Super"
	super_protocol.sprocket = self
	add_child(super_protocol)
	_build()
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.bolts_changed.connect(_on_bolts)
	EventBus.bark.connect(_on_bus_bark)
	_apply_mood()


static func damage_mult_for(tree: SceneTree) -> float:
	var s: Sprocket = tree.get_first_node_in_group(&"sprocket") as Sprocket if tree != null else null
	return s.damage_mult() if s != null else 1.0


func damage_mult() -> float:
	return super_protocol.damage_mult() if super_protocol != null else 1.0


## Firmware voice-filter cosmetic (GDD §3.3). Hook only: stored and saved, applied in a later milestone.
func set_voice_filter(id: StringName) -> void:
	voice_filter = id
	BS.flags["sprocket.voice_filter"] = String(id)


# ------------------------------------------------------------------ moods and barks

func set_mood(m: StringName, secs: float = 2.0) -> void:
	if not (m in MOODS):
		return
	if m == mood:
		mood_t = maxf(mood_t, secs)
		return
	mood = m
	mood_t = secs
	_apply_mood()
	mood_changed.emit(mood)


## Plays a bark line (subtitle + voice) and looks smug about it.
func bark(line_id: String) -> void:
	if line_id == "":
		return
	BSText.say(line_id)
	var bm: Array = M["bark"]
	if not super_protocol.active:
		set_mood(StringName(str(bm[0])), float(bm[1]))
	barked.emit(line_id)


func _hp_frac() -> float:
	return bolt.hp / maxf(1.0, bolt.max_hp) if bolt != null else 1.0


func _on_player_damaged(_amount: float, _hp: float) -> void:
	var h: Array = M["hurt"]
	if not super_protocol.active:
		set_mood(StringName(str(h[0])), float(h[1]))
	bark(barks.try_bark("lowhp", _hp_frac(), BS.blocked()))


func _on_enemy_killed(_enemy: Node, _by: StringName) -> void:
	bark(barks.try_bark("bolts", _hp_frac(), BS.blocked()))
	bark(barks.try_bark("combat", _hp_frac(), BS.blocked()))


func _on_bolts(_total: int, delta: int) -> void:
	if delta > 0 and not super_protocol.active:
		var b: Array = M["bolts"]
		set_mood(StringName(str(b[0])), float(b[1]))


func _on_bus_bark(line_id: String) -> void:
	bark(line_id)


func on_super(on: bool) -> void:
	_kit.visible = on
	_body_mat.albedo_color = Color("#ff6a4a") if on else Color("#9fb3c8")
	if on:
		set_mood(&"alarmed", float(super_protocol.C["duration"]))
	else:
		mood_t = 0.0
		set_mood(&"normal", 0.0)
	_apply_mood()


# ------------------------------------------------------------------ per frame

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"super_sprocket") and not BS.blocked():
		super_protocol.activate()


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	t += dt
	_tick_face(dt)
	if bolt == null or not is_instance_valid(bolt):
		return
	visible = not bolt.dead
	var moving: bool = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward").length() > 0.2 \
		or Input.is_action_pressed(&"fire") or not bolt.scripted.is_empty()
	bark(barks.tick(dt, moving, BS.blocked()))
	var want: Vector3 = super_protocol.update(dt)
	var stiff: float = float(F["stiffness"])
	if want == Vector3.INF:
		want = shoulder_point()
		rotation.y = lerp_angle(rotation.y, bolt.motor.yaw, BoltMotor.damp(8.0, dt))
	else:
		if super_protocol.zip > 0.1:
			stiff *= 4.0
		var to: Vector3 = (super_protocol.target.call("get_center") as Vector3) - global_position if super_protocol.target != null else Vector3.ZERO
		if to.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), BoltMotor.damp(10.0, dt))
	follow(want, dt, stiff)
	var hs: float = Vector2(bolt.motor.vel.x, bolt.motor.vel.z).length()
	rotation.x = clampf(hs * 0.035, 0.0, 0.4)
	rotation.z = sin(t * (8.0 if super_protocol.active else 3.1)) * (0.1 if super_protocol.active else 0.07)


## The hover point beside Bolt's left shoulder (feet + facing-frame offset + bob).
func shoulder_point() -> Vector3:
	var o: Array = F["offset"]
	var off: Vector3 = Vector3(float(o[0]), float(o[1]) + sin(t * float(F["bob_rate"])) * float(F["bob_amp"]), float(o[2]))
	var feet: Vector3 = bolt.global_position - Vector3(0, bolt.motor.hy, 0)
	return feet + Basis(Vector3.UP, bolt.motor.yaw) * off


## Damped spring toward `want`; snaps when it falls too far behind (respawn, teleports).
func follow(want: Vector3, dt: float, stiff: float = -1.0) -> void:
	if stiff < 0.0:
		stiff = float(F["stiffness"])
	if not _placed or global_position.distance_to(want) > float(F["max_lag"]) * 3.0:
		global_position = want
		vel = Vector3.ZERO
		_placed = true
		return
	var acc: Vector3 = (want - global_position) * stiff - vel * float(F["damping"]) * sqrt(stiff / float(F["stiffness"]))
	vel += acc * dt
	global_position += vel * dt


func _tick_face(dt: float) -> void:
	if mood_t > 0.0:
		mood_t -= dt
		if mood_t <= 0.0 and mood != &"normal":
			set_mood(&"normal", 0.0)
	blink_t -= dt
	if blink_t <= 0.0 and mood != &"alarmed":
		if not blinking:
			blinking = true
			_apply_mood()
		if blink_t <= -float(M["blink_len"]):
			blinking = false
			blink_t = randf_range(float(M["blink_min"]), float(M["blink_max"]))
			_apply_mood()
	if super_protocol != null and super_protocol.active:
		_eye_mat.emission_energy_multiplier = 3.0 + sin(t * 12.0)
	# gesture while a Sprocket line is on screen is handled by the cutscene player through set_mood


# ------------------------------------------------------------------ look

func _apply_mood() -> void:
	if _eye == null:
		return
	var s: Vector3 = Vector3(1, 1, 0.45)
	var off: Vector3 = Vector3.ZERO
	_lid.visible = false
	var col: Color = EYE_RED if super_protocol != null and super_protocol.active else EYE_CYAN
	match mood:
		&"happy":
			s = Vector3(1.05, 0.42, 0.45)       # squeezed crescent, riding high
			off = Vector3(0, 0.03, 0)
			col = col if col == EYE_RED else Color("#4dffa0")
		&"alarmed":
			s = Vector3(1.32, 1.32, 0.45)       # wide open
			col = EYE_RED if col == EYE_RED else Color("#ff5d5d")
		&"smug":
			s = Vector3(1.0, 0.62, 0.45)        # half-lidded
			off = Vector3(0, -0.02, 0)
			_lid.visible = true
	if blinking:
		s.y = 0.08
	_eye.scale = s
	_eye.position = Vector3(0, 0.02, 0.2) + off
	_eye_mat.emission = col
	_eye_mat.albedo_color = col.lightened(0.5)


func eye_scale() -> Vector3:
	return _eye.scale


func _build() -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color("#9fb3c8")
	_body_mat.metallic = 0.5
	_body_mat.roughness = 0.35
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color("#2a3242")
	_head = Node3D.new()
	_head.name = "Head"
	add_child(_head)
	var body: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.24
	sph.height = 0.46
	body.mesh = sph
	body.material_override = _body_mat
	_head.add_child(body)
	# the big eye: a glowing lens set into a dark bezel on the front (+Z)
	var bezel: MeshInstance3D = MeshInstance3D.new()
	var bz: CylinderMesh = CylinderMesh.new()
	bz.top_radius = 0.16
	bz.bottom_radius = 0.16
	bz.height = 0.06
	bezel.mesh = bz
	bezel.material_override = dark
	bezel.rotation.x = PI * 0.5
	bezel.position = Vector3(0, 0.02, 0.19)
	_head.add_child(bezel)
	_eye = MeshInstance3D.new()
	_eye.name = "Eye"
	var es: SphereMesh = SphereMesh.new()
	es.radius = 0.11
	es.height = 0.22
	_eye.mesh = es
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.emission_enabled = true
	_eye_mat.emission_energy_multiplier = 2.2
	_eye.material_override = _eye_mat
	_head.add_child(_eye)
	_lid = MeshInstance3D.new()
	var lb: BoxMesh = BoxMesh.new()
	lb.size = Vector3(0.3, 0.06, 0.08)
	_lid.mesh = lb
	_lid.material_override = _body_mat
	_lid.position = Vector3(0, 0.09, 0.24)
	_lid.rotation.z = 0.18
	_head.add_child(_lid)
	var ant: MeshInstance3D = MeshInstance3D.new()
	var am: CylinderMesh = CylinderMesh.new()
	am.top_radius = 0.012
	am.bottom_radius = 0.012
	am.height = 0.22
	ant.mesh = am
	ant.material_override = dark
	ant.position = Vector3(0.06, 0.32, 0)
	_head.add_child(ant)
	var tip: MeshInstance3D = MeshInstance3D.new()
	var tm: SphereMesh = SphereMesh.new()
	tm.radius = 0.035
	tm.height = 0.07
	tip.mesh = tm
	tip.material_override = _eye_mat
	tip.position = Vector3(0.06, 0.44, 0)
	_head.add_child(tip)
	_arm_l = _arm(Vector3(-0.26, -0.04, 0), dark)
	_arm_r = _arm(Vector3(0.26, -0.04, 0), dark)
	# super kit: twin cannons, hidden until the protocol runs
	_kit = Node3D.new()
	_kit.name = "SuperKit"
	_kit.visible = false
	add_child(_kit)
	for sx: float in [-0.2, 0.2]:
		var cn: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.05
		cm.height = 0.34
		cn.mesh = cm
		cn.material_override = dark
		cn.rotation.x = PI * 0.5
		cn.position = Vector3(sx, -0.14, 0.16)
		_kit.add_child(cn)


func _arm(pos: Vector3, mat: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var m: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = Vector3(0.05, 0.16, 0.05)
	m.mesh = b
	m.material_override = mat
	m.position = Vector3(0, -0.08, 0)
	pivot.add_child(m)
	return pivot
