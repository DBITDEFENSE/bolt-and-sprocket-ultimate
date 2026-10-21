class_name Crucible
extends Interactable
## THE CRUCIBLE: a Nachtglas furnace in the Core Vault that "re-teaches" a weapon (WEAPONS.md §11).
## Feed the current weapon (5000) -> 5 s forge -> the upgraded weapon is offered for 15 s. Anyone may
## take it (classic co-op steal); if nobody does, it's lost. Holding an upgraded weapon buys its ammo (2500).
## Co-op: one weapon in the forge at a time ("The Crucible is occupied" for everyone else while it forges);
## the host runs it and mirrors the forge / offer / reset to every peer. A steal gets an Operator remark.
## Local -Z faces the player; origin = floor center.

enum Phase { IDLE, FORGING, OFFERED }

@export var forge_seconds: float = 5.0
@export var offer_seconds: float = 15.0
## Map 0 (T-032): the cellar Crucible waits for the cellar lever, like the Helvetia machines beside it.
@export var needs_power: bool = false

var phase: Phase = Phase.IDLE
var _t: float = 0.0
var _result: StringName = &""
var _fed_by: int = 0
var _glow: OmniLight3D
var _mouth: MeshInstance3D
var _mouth_mat: StandardMaterial3D
var _embers: CPUParticles3D
var _float: Node3D
var _float_label: Label3D
var _roar_t: float = 0.0


## What the Crucible would do for this weapon: &"none", &"nothing", &"upgrade", &"ammo", &"full".
static func action_for(w: WeaponInstance) -> StringName:
	if w == null:
		return &"none"
	if w.upgraded:
		return &"full" if w.is_full() else &"ammo"
	if w.upgrade_id() == &"":
		return &"nothing"
	return &"upgrade"


static func price_for(action: StringName, econ: Dictionary) -> int:
	match action:
		&"upgrade":
			return int(econ["crucible_upgrade"])
		&"ammo":
			return int(econ["crucible_upgraded_ammo"])
	return 0


func _ready() -> void:
	interact_size = Vector3(2.2, 2.0, 0.3)
	interact_offset = Vector3(0, 1.0, -0.95)
	super._ready()
	add_to_group(&"crucible")
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1 << 8
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0, 2.4, 1.6)
	cs.shape = box
	cs.position = Vector3(0, 1.2, 0)
	body.add_child(cs)
	add_child(body)
	GLBus.power_activated.connect(_refresh_power)
	_refresh_power()


func is_powered() -> bool:
	return GameState.power_on or not needs_power


## Unpowered (Map 0 before the lever): the mouth barely glows and the Nachtglas light is off.
func _refresh_power() -> void:
	var on: bool = is_powered()
	if _glow != null:
		_glow.visible = on
	if _mouth_mat != null:
		_mouth_mat.emission_energy_multiplier = 1.0 if on else 0.12


func build_greybox() -> void:
	# the furnace: plinth, riveted drum and dome, Nachtglas buttresses, flue, bellows, the nameplate arch (cached)
	InteractableArt.place(self, "crucible_body", func(r: Node3D) -> void: InteractableArt.crucible_body(r))
	# the mouth (its glow is driven by the forge)
	_mouth_mat = greybox_mat(Color(0.9, 0.45, 0.15), 1.0)
	_mouth = add_box(self, Vector3(1.0, 0.8, 0.05), Vector3(0, 1.15, -0.81), _mouth_mat)
	_mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.75, 0.35, 1.0)
	_glow.light_energy = 0.6
	_glow.omni_range = 6.0
	_glow.position = Vector3(0, 1.2, -1.3)
	add_child(_glow)
	_embers = CPUParticles3D.new()
	_embers.emitting = false
	_embers.amount = 40
	_embers.lifetime = 1.2
	_embers.position = Vector3(0, 1.1, -0.85)
	_embers.direction = Vector3(0, 1, -0.6)
	_embers.spread = 35.0
	_embers.initial_velocity_min = 1.0
	_embers.initial_velocity_max = 3.0
	_embers.gravity = Vector3(0, 0.6, 0)
	var em: SphereMesh = SphereMesh.new()
	em.radius = 0.025
	em.height = 0.05
	em.material = greybox_mat(Color(1.0, 0.6, 0.2), 6.0)
	_embers.mesh = em
	add_child(_embers)
	add_label(self, "THE CRUCIBLE", Vector3(0, 2.62, -1.1), 36, Color(0.9, 0.7, 1.0))
	_float = Node3D.new()
	_float.position = Vector3(0, 1.2, -1.5)
	add_child(_float)
	add_box(_float, Vector3(0.7, 0.12, 0.08), Vector3.ZERO, greybox_mat(Color(0.65, 0.3, 1.0), 4.0))
	_float_label = add_label(_float, "", Vector3(0, 0.25, 0), 34, Color(1.0, 0.85, 0.6))
	_float_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_float.hide()


func _process(delta: float) -> void:
	_quest_glow()
	match phase:
		Phase.FORGING:
			_t += delta
			var k: float = clampf(_t / forge_seconds, 0.0, 1.0)
			if _glow != null:
				_glow.light_energy = lerpf(1.0, 6.0, k) * (1.0 + sin(_t * 18.0) * 0.15)
				_glow.light_color = Color(0.75, 0.35, 1.0).lerp(Color(1.0, 0.6, 0.2), k)
				_mouth_mat.emission_energy_multiplier = lerpf(1.0, 8.0, k)
			_roar_t -= delta
			if _roar_t <= 0.0:
				# One furnace roar per forge (re-fired only if the forge outlasts the recording).
				_roar_t = maxf(1.0, AudioDirector.sound_length("crucible_roar") - 0.2)
				AudioDirector.play_3d("crucible_roar", global_position + Vector3.UP, 0.0, 0.0)
			if _t >= forge_seconds and Net.is_authority():
				_offer()
				Net.mirror(self, &"_offer")
		Phase.OFFERED:
			_t += delta
			if _float != null:
				_float.rotation.y += delta * 1.5
				_float.position.y = 1.2 + sin(_t * 2.0) * 0.06
			if _t >= offer_seconds and Net.is_authority():
				GLBus.crucible_expired.emit(_result)
				_reset()
				Net.mirror(self, &"_reset")


## Requiem quest targets: placing the Nachtglas shard (step 8) and starting the Heartstorm (step 9).
func _quest_target() -> StringName:
	if phase != Phase.IDLE:
		return &""
	if QuestManager.interact_ready(&"crucible_shard"):
		return &"crucible_shard"
	if QuestManager.interact_ready(&"crucible_heartstorm"):
		return &"crucible_heartstorm"
	return &""


func get_prompt(player: Player) -> String:
	var key: String = prompt_key(&"interact")
	match _quest_target():
		&"crucible_shard":
			return "Hold [%s] to place the Nachtglas shard in the Crucible" % key
		&"crucible_heartstorm":
			return "Hold [%s] to begin the HEARTSTORM" % key
	if not is_powered():
		return "Power must be activated"
	match phase:
		Phase.FORGING:
			return "" if player.player_id == _fed_by or GameState.is_solo() else "The Crucible is occupied."
		Phase.OFFERED:
			return "Hold [%s] to take %s" % [key, _display(_result)]
	var w: WeaponInstance = player.weapons.current()
	var econ: Dictionary = GLData.table("economy")
	match action_for(w):
		&"upgrade":
			return "Hold [%s] to feed the Crucible [%d]" % [key, price_for(&"upgrade", econ)]
		&"ammo":
			return "Hold [%s] for upgraded ammo [%d]" % [key, price_for(&"ammo", econ)]
		&"full":
			return "%s ammo full" % w.display_name()
		&"nothing":
			return "The Crucible has nothing to teach this."
	return ""


func can_interact(player: Player) -> bool:
	if _quest_target() != &"":
		return true
	if not is_powered():
		return false
	match phase:
		Phase.FORGING:
			return false
		Phase.OFFERED:
			return true
	var a: StringName = action_for(player.weapons.current())
	return a == &"upgrade" or a == &"ammo"


func interact(player: Player) -> void:
	var qt: StringName = _quest_target()
	if qt != &"":
		QuestManager.interact(qt, player.player_id)
		AudioDirector.play_3d("door_open", global_position + Vector3.UP, 2.0, 0.0)
		return
	if phase == Phase.OFFERED:
		_take(player)
		return
	if phase != Phase.IDLE:
		return
	var w: WeaponInstance = player.weapons.current()
	var econ: Dictionary = GLData.table("economy")
	match action_for(w):
		&"ammo":
			if try_purchase(player, StringName(String(w.id) + "_ammo"), price_for(&"ammo", econ)):
				player.weapons.refill_weapon(w.id)
				feedback_2d(player, "reload_end")
		&"upgrade":
			if try_purchase(player, &"crucible", price_for(&"upgrade", econ)):
				var up: StringName = w.upgrade_id()
				player.weapons.remove_current()
				_forge(player.player_id, String(up))
				Net.mirror(self, &"_forge", [player.player_id, String(up)])


## The weapon goes in and the forge roars (host, then every peer).
func _forge(fed_by: int, result: String) -> void:
	_result = StringName(result)
	_fed_by = fed_by
	phase = Phase.FORGING
	_t = 0.0
	_roar_t = 0.0
	GLBus.crucible_started.emit(fed_by, _result)
	if _embers != null:
		_embers.emitting = true
	AudioDirector.play_3d("door_open", global_position + Vector3.UP, 0.0, 0.0)


## The shard glows brighter with every Totenglocke kill near the heart (10-stage ramp).
func _quest_glow() -> void:
	if phase != Phase.IDLE or _glow == null:
		return
	var q: StringName = &"map01_requiem"
	if QuestManager.is_active(q, &"s8b_charge"):
		var target: int = QuestManager.kill_target(QuestManager.step_def(q, &"s8b_charge"))
		var got: Variant = QuestManager.progress(q, &"s8b_charge")
		var k: float = floorf(10.0 * float(int(got) if got != null else 0) / float(maxi(1, target))) / 10.0
		_glow.light_energy = 0.8 + 4.0 * k
		_glow.light_color = Color(0.75, 0.35, 1.0).lerp(Color(1.0, 0.7, 0.3), k)
	elif QuestManager.is_active(q, &"s9_heartstorm"):
		_glow.light_energy = 5.0 + sin(Time.get_ticks_msec() * 0.01) * 1.5


func _offer() -> void:
	phase = Phase.OFFERED
	_t = 0.0
	GLBus.crucible_ready.emit(_result)
	if _float != null:
		_float_label.text = _display(_result)
		_float.show()
	if _embers != null:
		_embers.emitting = false
	if _glow != null:
		_glow.light_energy = 3.0
	AudioDirector.play_3d("buy", global_position + Vector3.UP, 2.0)


func _take(player: Player) -> void:
	var id: StringName = _result
	player.weapons.give_weapon(id)
	GLBus.weapon_upgraded.emit(player.player_id, id)
	GLBus.weapon_acquired.emit(player.player_id, id, &"crucible")
	if player.player_id != _fed_by and not GameState.is_solo():
		GLVO.play(StringName("OPR_CRUCIBLE_STEAL_0%d" % randi_range(1, 2)))   # co-op steal (relayed to everyone)
	_reset()
	Net.mirror(self, &"_reset")


func _reset() -> void:
	phase = Phase.IDLE
	_t = 0.0
	_result = &""
	if _float != null:
		_float.hide()
	if _glow != null:
		_glow.light_energy = 0.6
		_glow.light_color = Color(0.75, 0.35, 1.0)
		_mouth_mat.emission_energy_multiplier = 1.0
	if _embers != null:
		_embers.emitting = false


static func _display(id: StringName) -> String:
	var t: Dictionary = GLData.table("weapons")
	var row: Dictionary = t.get("upgraded", {}).get(String(id), t["weapons"].get(String(id), {}))
	return str(row.get("name", id))
