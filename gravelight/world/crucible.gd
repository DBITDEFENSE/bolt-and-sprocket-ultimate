class_name Crucible
extends Interactable
## THE CRUCIBLE: a Nachtglas furnace in the Core Vault that "re-teaches" a weapon (WEAPONS.md §11).
## Feed the current weapon (5000) -> 5 s forge -> the upgraded weapon is offered for 15 s. Anyone may
## take it (classic co-op steal); if nobody does, it's lost.
## Co-op: one weapon in the forge at a time ("The Crucible is occupied" for everyone else while it forges);
## the host runs it and mirrors the forge / offer / reset to every peer. A steal gets an Operator remark.
## Local -Z faces the player; origin = floor center.
## Second and third teaching (T-037, "double and triple pack-a-punch"): a Crucible-taught weapon can be fed again
## (economy "crucible_upgrade_tiers") up to WeaponInstance.max_tier(); it comes back at the next tier
## (weapons.json "crucible_tiers": damage, mag, reserve, reload, a name suffix), full.
## The Crucible sells no ammo (T-083): it only teaches. Ammo for a taught weapon comes from the ammo boxes
## (AmmoBox, economy "ammo_box.upgraded") like any other, so a half-empty taught gun is offered its next teaching,
## never a refill.
##
## T-254 (UPDATE 19, "the crucible more merged and immersed"): the machine is alive, on the timings it always had.
## Cold (no power): dark, the mouth a dull ember, its iron ticking as it settles (crucible_tick). Powered: the fire
## breathes in the mouth and on the floor in front of it, a few sparks drift up. Fed: the door slams (crucible_feed),
## the weapon itself slides into the mouth, a hammer works inside the casing (crucible_clank, the body jolts, sparks
## spit with each blow), the light climbs from violet to white-gold. Done: it comes out as the real upgraded model
## (crucible_out), glowing, and hangs in front of the mouth where the violet bar used to. What stands round the
## machine (the housing that meets the wall and the vault, the flue, soot, gauges) is CrucibleRoom's.
## Everything here is built AFTER ArtCollider.fit, so no new piece ever becomes part of the collider.

enum Phase { IDLE, FORGING, OFFERED }

const CrateFx: GDScript = preload("res://gravelight/world/crate_fx.gd")
## When the hammer falls, as fractions of forge_seconds (it quickens toward the end).
const CLANKS: PackedFloat32Array = [0.17, 0.36, 0.53, 0.68, 0.8, 0.9, 0.97]

@export var forge_seconds: float = 5.0
@export var offer_seconds: float = 15.0
## Map 0 (T-032): the cellar Crucible waits for the cellar lever, like the Helvetia machines beside it.
@export var needs_power: bool = false

var phase: Phase = Phase.IDLE
var _t: float = 0.0
var _result: StringName = &""
var _result_tier: int = 1
var _result_kit: Array = []        # the gun's attachments (WeaponKit.encode): the upgraded gun comes out wearing them
var _result_finish: String = ""
var _fed_by: int = 0
var _glow: OmniLight3D
var _mouth: MeshInstance3D
var _mouth_mat: StandardMaterial3D
var _embers: CPUParticles3D
var _float: Node3D
var _float_label: Label3D
var _roar_t: float = 0.0
# T-254
var _art: Node3D                    # the machine's model (jolts with the hammer; the collider never moves)
var _fire: OmniLight3D              # the mouth's warm light on the floor and the housing
var _idle_embers: CPUParticles3D
var _fed: Node3D                    # the weapon on its way into the mouth
var _out: Node3D                    # the upgraded weapon on offer
var _halo: MeshInstance3D
var _plate: MeshInstance3D
var _live_t: float = 0.0
var _tick_t: float = 3.0
var _clank_i: int = 0
var _jolt: float = 0.0
var _heat: float = 0.0              # 0 cold .. 1 at the end of a forge; cools after


## What the Crucible would do for this weapon: &"none" (no weapon), &"nothing" (it can't be taught), &"upgrade"
## (the next teaching, whatever the ammo state), &"full" (at the top tier: nothing more to teach). Never ammo.
static func action_for(w: WeaponInstance) -> StringName:
	if w == null:
		return &"none"
	if w.upgraded:
		return &"upgrade" if w.tier < WeaponInstance.max_tier() else &"full"
	if w.upgrade_id() == &"":
		return &"nothing"
	return &"upgrade"


## `tier` = the tier of the weapon being fed (0 base): the first teaching costs crucible_upgrade, the later ones
## economy "crucible_upgrade_tiers"[next tier]. Anything but &"upgrade" is free (0): the Crucible sells nothing else.
static func price_for(action: StringName, econ: Dictionary, tier: int = 0) -> int:
	match action:
		&"upgrade":
			if tier >= 1:
				return int((econ.get("crucible_upgrade_tiers", {}) as Dictionary).get(str(tier + 1), int(econ["crucible_upgrade"]) * 2))
			return int(econ["crucible_upgrade"])
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
	ArtCollider.fit(self, self, body)   # T-188: hulls of the forge's art, not the 2.0 x 2.4 x 1.6 m box
	# the brass plate on the feed door (LORE.md 4.2), readable: why this Crucible is on this map (T-075, MachineLore)
	var plaque: LorePlaque = LorePlaque.new()
	plaque.name = "CruciblePlate"
	plaque.lore_key = "crucible"
	plaque.noun = "the brass plate"
	plaque.plate_text = "MOD. R-E\nPAT. PEND. BLZ-40417"
	plaque.plate_size = Vector2(0.42, 0.16)
	plaque.position = Vector3(0.62, 0.42, -0.815)
	plaque.interact_size = Vector3(0.6, 0.32, 0.1)
	plaque.interact_offset = Vector3(0, 0, -0.36)
	add_child(plaque)
	_build_live()   # T-254: after the fit, so none of it is ever collided with
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
		_mouth_mat.albedo_color = Color(0.9, 0.45, 0.15) if on else Color(0.1, 0.035, 0.02)   # T-254: cold is dark (a lamp on it lit it orange)
	if _fire != null:
		_fire.visible = on
		_idle_embers.emitting = on


func build_greybox() -> void:
	# the furnace: plinth, riveted drum and dome, Nachtglas buttresses, flue, bellows, the nameplate arch (cached)
	# our forge (UPDATE_05 section 5, T-094: brick hearth, iron firebox, Nachtglas buttresses); procedural when absent
	var art: Node3D = WorldArt.instance("crucible", "Model")
	if art != null:
		add_child(art)
		_art = art
	else:
		_art = InteractableArt.place(self, "crucible_body", func(r: Node3D) -> void: InteractableArt.crucible_body(r))
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
	_embers.mesh = _spark_mesh()   # T-254: sparks, not glowing balls
	_embers.particle_flag_align_y = true
	_embers.gravity = Vector3(0, -3.5, 0)
	_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_embers)
	add_label(self, "THE CRUCIBLE", Vector3(0, 2.62, -1.1), 36, Color(0.9, 0.7, 1.0))
	_float = Node3D.new()
	_float.position = Vector3(0, 1.2, -1.5)
	add_child(_float)
	add_box(_float, Vector3(0.7, 0.12, 0.08), Vector3.ZERO, greybox_mat(Color(0.65, 0.3, 1.0), 4.0))
	_float_label = add_label(_float, "", Vector3(0, 0.25, 0), 30, Color(1.0, 0.85, 0.6), SurfaceText.FLOAT)
	_float_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_float.hide()


static func _spark_mesh() -> Mesh:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.01, 0.06, 0.01)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.7, 0.32)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.62, 0.25)
	sm.emission_energy_multiplier = 3.0
	bm.material = sm
	return bm


## T-254: what makes the machine live (see the header). No MeshInstance here exists when ArtCollider.fit runs.
func _build_live() -> void:
	if _mouth == null:
		return   # a swapped-in "Visual" scene draws the machine: nothing of ours to animate
	_fire = OmniLight3D.new()
	_fire.name = "FireLight"
	_fire.light_color = Color(1.0, 0.56, 0.24)
	_fire.light_energy = 0.6
	_fire.omni_range = 3.8
	_fire.omni_attenuation = 1.5
	_fire.shadow_enabled = false
	_fire.light_specular = 0.3
	_fire.position = Vector3(0, 0.95, -1.2)
	add_child(_fire)
	_idle_embers = CPUParticles3D.new()
	_idle_embers.name = "IdleEmbers"
	_idle_embers.amount = 7
	_idle_embers.lifetime = 2.4
	_idle_embers.position = Vector3(0, 1.25, -0.84)
	_idle_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_idle_embers.emission_box_extents = Vector3(0.4, 0.3, 0.02)
	_idle_embers.direction = Vector3(0, 1, -0.25)
	_idle_embers.spread = 20.0
	_idle_embers.initial_velocity_min = 0.25
	_idle_embers.initial_velocity_max = 0.6
	_idle_embers.gravity = Vector3(0, 0.25, 0)
	_idle_embers.scale_amount_min = 0.4
	_idle_embers.scale_amount_max = 0.8
	_idle_embers.particle_flag_align_y = true
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_idle_embers.color_ramp = ramp
	_idle_embers.mesh = _spark_mesh()
	_idle_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_idle_embers.emitting = false
	add_child(_idle_embers)
	for c: Node in _float.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).hide()   # the old violet bar: the upgraded weapon itself hangs here now
	_halo = CrateFx.halo(2.0, Color(1.0, 0.72, 0.42, 0.0))
	_halo.name = "OutHalo"
	_halo.position = Vector3(0, 0, 0.12)
	_float.add_child(_halo)
	# the name hangs under the weapon, over the dark hearth, on a dark card (over the white-hot mouth it was lost)
	_float_label.position = Vector3(0, -0.34, 0)
	_float_label.render_priority = 2
	_plate = CrateFx.name_plate()
	_plate.position = _float_label.position
	_plate.hide()
	_float.add_child(_plate)


## The base weapon of a Crucible result ("kar98k_up" -> kar98k; weapons.json "upgraded" rows name their base).
static func base_of(result: StringName) -> StringName:
	var row: Dictionary = (GLData.table("weapons").get("upgraded", {}) as Dictionary).get(String(result), {})
	if row.has("base"):
		return StringName(str(row["base"]))
	return StringName(String(result).trim_suffix("_up"))


## A weapon model sized for the mouth (about `span` metres long), its barrel along local +X, centred on its holder.
static func _weapon_holder(id: StringName, upgraded: bool, span: float = 0.85) -> Node3D:
	var model: Node3D = WeaponModels.build(id, upgraded)
	var bb: AABB = WeaponModels.model_bounds(model)
	var holder: Node3D = Node3D.new()
	holder.scale = Vector3.ONE * clampf(span / maxf(0.2, bb.size.z), 0.5, 2.0)
	var c: Vector3 = bb.get_center()
	model.rotation_degrees = Vector3(0, 90, 0)
	model.position = -Vector3(c.z, c.y, -c.x)
	holder.add_child(model)
	return holder


func _free_fed() -> void:
	if _fed != null and is_instance_valid(_fed):
		_fed.queue_free()
	_fed = null


func _free_out() -> void:
	if _out != null and is_instance_valid(_out):
		_out.queue_free()
	_out = null


## Every frame (T-254): the fire's breathing, the cold ticking, the hammer's jolt dying away, the heat cooling.
func _live(delta: float) -> void:
	if _fire == null:
		return
	_live_t += delta
	var on: bool = is_powered()
	if not on:
		# cold iron ticks as it settles: now and then, quietly, only with somebody near enough to hear it
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = randf_range(2.2, 6.5)
			var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
			if cam != null and cam.global_position.distance_to(global_position) < 14.0:
				AudioDirector.play_3d("crucible_tick", global_position + Vector3(randf_range(-0.6, 0.6), randf_range(0.5, 2.0), 0.0), -4.0, 0.1)
		return
	if phase != Phase.FORGING:
		_heat = move_toward(_heat, 0.35 if phase == Phase.OFFERED else 0.0, delta * 0.25)
	var breath: float = 0.5 + 0.5 * sin(_live_t * 1.9) * sin(_live_t * 0.7 + 1.3)
	var flick: float = 0.06 * sin(_live_t * 13.0) + 0.04 * sin(_live_t * 29.0)
	if phase != Phase.FORGING:
		_mouth_mat.emission_energy_multiplier = 0.85 + 0.3 * breath + flick + _heat * 3.0
	_fire.light_energy = (0.5 + 0.22 * breath + flick) * (1.0 + _heat * 3.5) + _jolt * 1.5
	_fire.light_color = Color(1.0, 0.56, 0.24).lerp(Color(1.0, 0.82, 0.6), _heat)
	_jolt = maxf(0.0, _jolt - delta * 5.0)
	if _art != null:
		_art.position = Vector3(sin(_live_t * 91.0), 0.0, cos(_live_t * 77.0)) * 0.006 * _jolt
	if _halo != null and _float.visible:
		(_halo.material_override as StandardMaterial3D).albedo_color.a = 0.3 + 0.1 * sin(_live_t * 3.3) + _jolt * 0.4


func _process(delta: float) -> void:
	_quest_glow()
	_live(delta)
	match phase:
		Phase.FORGING:
			_t += delta
			var k: float = clampf(_t / forge_seconds, 0.0, 1.0)
			_heat = k
			# the weapon slides in over the first moments; then the hammer, quickening
			if _fed != null and is_instance_valid(_fed):
				var slide: float = clampf(_t / 0.75, 0.0, 1.0)
				var es: float = slide * slide * (3.0 - 2.0 * slide)
				_fed.position = Vector3(0, 1.22, -1.55).lerp(Vector3(0, 1.15, -0.55), es)
				_fed.rotation.y = lerpf(0.0, PI * 0.5, es)
				if slide >= 1.0:
					_free_fed()
			while _clank_i < CLANKS.size() and k >= CLANKS[_clank_i]:
				_clank_i += 1
				_jolt = 1.0
				AudioDirector.play_3d("crucible_clank", global_position + Vector3.UP * 1.2, -1.0 + 3.0 * k, 0.08)
				if _embers != null:
					_embers.restart()
					_embers.emitting = true
			if _glow != null:
				_glow.light_energy = lerpf(1.0, 6.0, k) * (1.0 + sin(_t * 18.0) * 0.15)
				_glow.light_color = Color(0.75, 0.35, 1.0).lerp(Color(1.0, 0.6, 0.2), k)
				_mouth_mat.emission_energy_multiplier = lerpf(1.2, 5.0, k) * (1.0 + 0.5 * _jolt)   # T-254: was 8 (blown out)
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
			return "Hold [%s] to take %s" % [key, _display(_result, _result_tier)]
	var w: WeaponInstance = player.weapons.current()
	var econ: Dictionary = GLData.table("economy")
	match action_for(w):
		&"upgrade":
			if w.upgraded:
				return "Hold [%s] to re-teach %s [%s]" % [key, w.display_name(), price_str(player, price_for(&"upgrade", econ, w.tier))]
			return "Hold [%s] to feed the Crucible [%s]" % [key, price_str(player, price_for(&"upgrade", econ))]
		&"full":
			return "%s has learned all the Crucible can teach." % w.display_name()
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
	return action_for(player.weapons.current()) == &"upgrade"


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
		&"upgrade":
			if try_purchase(player, &"crucible", price_for(&"upgrade", econ, w.tier)):
				var up: StringName = w.upgrade_id()
				var next_tier: int = w.tier + 1
				var kit: Array = WeaponKit.encode(w.kit)
				var fin: String = String(w.finish)
				player.weapons.remove_current()
				_forge(player.player_id, String(up), next_tier, kit, fin)
				Net.mirror(self, &"_forge", [player.player_id, String(up), next_tier, kit, fin])


## The weapon goes in and the forge roars (host, then every peer).
func _forge(fed_by: int, result: String, tier: int = 1, kit: Array = [], finish: String = "") -> void:
	_result = StringName(result)
	_result_tier = tier
	_result_kit = kit
	_result_finish = finish
	_fed_by = fed_by
	if tier >= 2 and Net.is_authority():
		GLVO.play(StringName("OPR_CRUCIBLE_%s_01" % ("TWICE" if tier == 2 else "THRICE")))
	phase = Phase.FORGING
	_t = 0.0
	_roar_t = 0.0
	GLBus.crucible_started.emit(fed_by, _result)
	_clank_i = 0
	if _embers != null:
		_embers.emitting = true
	# T-254: the weapon itself goes in (its own model, as it was fed), the feed door slams behind it
	_free_fed()
	_free_out()
	if _fire != null and is_inside_tree():
		_fed = _weapon_holder(base_of(_result), tier >= 2, 0.8)
		_fed.position = Vector3(0, 1.22, -1.55)
		add_child(_fed)
	AudioDirector.play_3d("crucible_feed" if AudioDirector.has_sound("crucible_feed") else "door_open", global_position + Vector3.UP, 0.0, 0.0)


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
		_float_label.text = _display(_result, _result_tier)
		_float.show()
	if _embers != null:
		_embers.emitting = false
	if _glow != null:
		_glow.light_energy = 3.0
	# T-254: it comes out changed: the real upgraded model, still glowing, out of the mouth to where it hangs
	_free_fed()
	_free_out()
	if _fire != null and _float != null and is_inside_tree():
		# (no overlay on it: the taught weapons' own shader moves their surface and a second pass speckles over it)
		_out = _weapon_holder(base_of(_result), true, 1.2)
		_float.add_child(_out)
		CrateFx.fit_plate(_plate, _float_label)
		_float.position.z = -0.85
		var tw: Tween = create_tween()
		tw.tween_property(_float, "position:z", -1.5, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_jolt = 1.0
	AudioDirector.play_3d("crucible_out" if AudioDirector.has_sound("crucible_out") else "buy", global_position + Vector3.UP, 2.0)


func _take(player: Player) -> void:
	var id: StringName = _result
	player.weapons.give_weapon(id)
	var got: WeaponInstance = player.weapons.find_weapon(id)
	if got != null and _result_tier >= 2:
		got.tier = _result_tier
		got.refill()
		player.weapons.call("_rebuild_gun")
	if got != null and (not _result_kit.is_empty() or _result_finish != ""):
		player.weapons.set_kit(id, _result_kit, _result_finish)
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
	_result_tier = 1
	_result_kit = []
	_result_finish = ""
	if _float != null:
		_float.hide()
		_float.position.z = -1.5
	_free_fed()
	_free_out()
	if _glow != null:
		_glow.light_energy = 0.6
		_glow.light_color = Color(0.75, 0.35, 1.0)
		_mouth_mat.emission_energy_multiplier = 1.0
	if _embers != null:
		_embers.emitting = false


static func _display(id: StringName, tier: int = 1) -> String:
	var t: Dictionary = GLData.table("weapons")
	var row: Dictionary = t.get("upgraded", {}).get(String(id), t["weapons"].get(String(id), {}))
	var suffix: String = ""
	for tc: Dictionary in t.get("crucible_tiers", []):
		if int(tc.get("tier", 1)) == tier:
			suffix = str(tc.get("suffix", ""))
	return str(row.get("name", id)) + suffix
