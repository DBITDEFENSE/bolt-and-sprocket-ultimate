class_name AuxBus
extends PowerSwitch
## UPDATE 10 §3 (THE_BAR row 9, DECISIONS T-156): der Kranich's auxiliary bus as a switch you find, not a generic
## Hauptschalter. A tall breaker board on the centre body's starboard wall (BORDNETZ · HILFSSAMMELSCHIENE): seven
## zone breakers in a row, the big rotary main switch, a battery lamp and a red beacon that pulses in the dark cabin
## so you can find it; a hint banner if the cabin is still dark after `hint_after_s`. Throwing it runs the power-on
## sweep: PowerSwitch's lights room by room (zone_order), and with each room its breaker flips; the flight deck's
## instruments come up (the `dial_lit` faces from dark to lit); the Bordfunk crackles alive (radio static at the
## tape deck, then PA_M4B_POWER_01); every perk machine wakes with a sting as its room lights; then PowerSwitch's
## zombie burst. Everything visual runs on every peer (_sequence_visual is mirrored by PowerSwitch).

@export var hint_after_s: float = 45.0
@export var radio_at: Vector3 = Vector3(7.0, 1.2, 48.0)

var _breakers: Array[Node3D] = []
var _dials: Array[StandardMaterial3D] = []
var _hint_t: float = 0.0
var _hinted: bool = false
var stings: int = 0


func _ready() -> void:
	super._ready()
	add_to_group(&"aux_bus")
	_find_dials.call_deferred()


func build_greybox() -> void:
	# the board: a dark grey cabinet 1.6 wide, 2.2 tall, on standoffs
	Props.block(self, Vector3(-0.8, 0.15, -0.18), Vector3(0.8, 2.3, 0.06), "machine_grey")
	Props.block(self, Vector3(-0.82, 2.3, -0.2), Vector3(0.82, 2.38, 0.08), "iron")
	var plate: Label3D = add_label(self, "BORDNETZ\nHILFSSAMMELSCHIENE", Vector3(0, 2.05, -0.19), 18, Color(0.95, 0.88, 0.62))
	# seven zone breakers in a row, each a small arm that flips up when its room comes on
	for i: int in 7:
		var x: float = -0.6 + 0.2 * float(i)
		Props.block(self, Vector3(x - 0.07, 1.45, -0.21), Vector3(x + 0.07, 1.7, -0.18), "black_paint")
		var arm: Node3D = Node3D.new()
		arm.position = Vector3(x, 1.575, -0.22)
		add_child(arm)
		Props.block(arm, Vector3(-0.02, -0.11, -0.03), Vector3(0.02, 0.0, 0.0), "enamel_white")
		arm.rotation.x = 0.0
		_breakers.append(arm)
	# the main switch on its quadrant (PowerSwitch's _lever turns it)
	_lever = Node3D.new()
	_lever.position = Vector3(0.0, 0.95, -0.2)
	add_child(_lever)
	Props.cyl(_lever, Vector3(0, 0, -0.03), 0.16, 0.06, "black_paint", Vector3(90, 0, 0))
	Props.block(_lever, Vector3(-0.03, 0.0, -0.09), Vector3(0.03, 0.22, -0.05), "red_paint")
	var l2: Label3D = add_label(self, "AUS · EIN", Vector3(0, 0.68, -0.19), 13, Color(0.95, 0.9, 0.8))
	# AUS / EIN lamps (PowerSwitch._refresh_lamps drives them) and the beacon
	for i2: int in 2:
		var lamp: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.045
		cm.height = 0.04
		lamp.mesh = cm
		lamp.rotation.x = PI * 0.5
		lamp.position = Vector3(-0.35 + 0.7 * float(i2), 0.95, -0.2)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lamp)
		_lamps.append(lamp)
	_beacon = OmniLight3D.new()
	_beacon.position = Vector3(0, 1.6, -0.9)
	_beacon.omni_range = 7.0
	_beacon.light_energy = 1.0
	_beacon.shadow_enabled = false
	add_child(_beacon)
	GLBus.power_activated.connect(_refresh_lamps)
	_refresh_lamps()


## The flight deck's dial faces (merged into the static batches with their own material): dark until the bus.
func _find_dials() -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.material_override is StandardMaterial3D and mi.material_override.resource_name == "dial_lit" and not _dials.has(mi.material_override):
			_dials.append(mi.material_override as StandardMaterial3D)
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(s) if mi.get_surface_override_material(s) != null else mi.mesh.surface_get_material(s)
			if m is StandardMaterial3D and m.resource_name == "dial_lit" and not _dials.has(m):
				_dials.append(m as StandardMaterial3D)
	if not GameState.power_on:
		for d: StandardMaterial3D in _dials:
			d.emission_energy_multiplier = 0.04


func _process(delta: float) -> void:
	if _thrown or GameState.power_on:
		return
	# the beacon pulses red in the dark cabin: the thing to find
	if _beacon != null:
		_beacon.light_energy = 0.5 + 0.6 * absf(sin(Time.get_ticks_msec() / 400.0))
	_hint_t += delta
	if not _hinted and _hint_t >= hint_after_s and GameState.phase == GameState.Phase.PLAYING:
		_hinted = true
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", "The cabin runs on batteries.\nThe auxiliary bus panel is in the centre body, starboard.", 4.0)


func _sequence_visual() -> void:
	super._sequence_visual()
	var cfg: Dictionary = _cfg()
	var t: float = float(cfg.get("light_sweep_start", 1.5))
	var gap: float = float(cfg.get("light_zone_gap", 0.5))
	for i: int in zone_order.size():
		var zone: StringName = StringName(zone_order[i])
		get_tree().create_timer(t).timeout.connect(_room_on.bind(i, zone))
		t += gap
	# the Bordfunk crackles alive, then speaks
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		AudioDirector.play_3d("radio_static", radio_at, 2.0, 0.0))
	if Net.is_authority():
		get_tree().create_timer(t + 0.8).timeout.connect(func() -> void:
			GLVO.play(StringName(str(cfg.get("vo_bordfunk", "PA_M4B_POWER_01")))))


## One room comes on: its breaker flips, its perk machines wake with a sting, the flight deck's dials light.
func _room_on(i: int, zone: StringName) -> void:
	if i < _breakers.size():
		var tw: Tween = _breakers[i].create_tween()
		tw.tween_property(_breakers[i], "rotation:x", -2.6, 0.12)
		AudioDirector.play_3d("reload_end", global_position + Vector3.UP * 1.5, -4.0, 0.1)
	for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		var pm: Node3D = n as Node3D
		if pm == null or ZoneVolume.zone_at(get_tree(), pm.global_position) != zone:
			continue
		var key: String = "perk_hum_" + String(pm.get("perk_id"))
		AudioDirector.play_3d("perk_tier4_sting" if AudioDirector.has_sound("perk_tier4_sting") else key, pm.global_position + Vector3.UP * 1.2, -10.0, 0.05)
		stings += 1
	if zone == &"F_COCKPIT":
		for d: StandardMaterial3D in _dials:
			var tw2: Tween = create_tween()
			tw2.tween_property(d, "emission_energy_multiplier", 1.6, 1.2)
