class_name Jukebox
extends Interactable
## The jukebox in the hangar's break corner (UPDATE 10 §3 Act III, DECISIONS T-157). Dark and silent until the
## generator's power: then the arch lights up (amber and violet tubes), the bubbles glow, and it plays the act's
## own tune (`jukebox_loop`: a 30 s period-swing pastiche from gen_audio_desert.py, our own composition; no real
## song) from its speaker grille. Using it switches the tune off and on again (a small thing the squad can touch).
## Presentation only; the host's on/off is mirrored to peers. Front faces local -Z.

@export var sound_key: String = "jukebox_loop"

var playing: bool = false
var powered: bool = false
var _player: AudioStreamPlayer3D = null
var _lit: Array[StandardMaterial3D] = []
var _light: OmniLight3D = null
var _t: float = 0.0


func _ready() -> void:
	interact_size = Vector3(1.1, 1.7, 0.9)
	interact_offset = Vector3(0, 0.85, -0.2)
	super._ready()
	add_to_group(&"jukebox")
	GLBus.power_activated.connect(_on_power)
	if GameState.power_on:
		_on_power.call_deferred()


func build_greybox() -> void:
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.2, 0.1)
	wood.roughness = 0.45
	var chrome: StandardMaterial3D = StandardMaterial3D.new()
	chrome.albedo_color = Color(0.8, 0.8, 0.82)
	chrome.metallic = 0.9
	chrome.roughness = 0.2
	var grille: StandardMaterial3D = StandardMaterial3D.new()
	grille.albedo_color = Color(0.12, 0.1, 0.08)
	# the cabinet, the speaker grille, the chrome trim, the record window
	add_box(self, Vector3(1.0, 1.15, 0.62), Vector3(0, 0.575, 0), wood)
	add_box(self, Vector3(0.7, 0.42, 0.03), Vector3(0, 0.38, -0.32), grille)
	add_box(self, Vector3(0.72, 0.03, 0.05), Vector3(0, 0.62, -0.33), chrome)
	add_box(self, Vector3(0.72, 0.03, 0.05), Vector3(0, 0.15, -0.33), chrome)
	var window: StandardMaterial3D = _glow_mat(Color(0.9, 0.75, 0.45))
	add_box(self, Vector3(0.56, 0.26, 0.03), Vector3(0, 0.9, -0.32), window)
	# the arch: three tiers of lit tubes (amber, violet, amber) over the top
	var cols: Array[Color] = [Color(1.0, 0.62, 0.22), Color(0.68, 0.38, 1.0), Color(1.0, 0.75, 0.35)]
	for i: int in 3:
		var arch: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		var r: float = 0.5 - 0.08 * float(i)
		tm.inner_radius = r - 0.035
		tm.outer_radius = r
		tm.rings = 18
		tm.ring_segments = 6
		arch.mesh = tm
		arch.rotation_degrees = Vector3(90, 0, 0)
		arch.position = Vector3(0, 1.15, -0.05 - 0.05 * float(i))
		arch.material_override = _glow_mat(cols[i])
		add_child(arch)
	# the half disc that the arch closes over (the cabinet's top), wood
	var top: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 0.6
	cm.radial_segments = 16
	top.mesh = cm
	top.rotation_degrees = Vector3(90, 0, 0)
	top.position = Vector3(0, 1.15, 0.02)
	top.material_override = wood
	add_child(top)
	# the bubble tubes up the sides
	for sx: float in [-0.44, 0.44]:
		add_box(self, Vector3(0.06, 0.9, 0.06), Vector3(sx, 0.62, -0.3), _glow_mat(Color(0.55, 0.85, 1.0)))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.68, 0.4)
	_light.light_energy = 0.0
	_light.omni_range = 4.5
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.1, -0.6)
	_light.set_meta("zone", &"C_HANGAR")
	add_child(_light)
	_apply_lit(0.0)


func _glow_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c * 0.35
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.0
	_lit.append(m)
	return m


func _apply_lit(k: float) -> void:
	for m: StandardMaterial3D in _lit:
		m.emission_energy_multiplier = 2.6 * k
	if _light != null:
		_light.light_energy = 1.1 * k


func _on_power() -> void:
	if powered:
		return
	powered = true
	_apply_lit(1.0)
	set_playing(true)


func get_prompt(_player: Player) -> String:
	if not powered:
		return "The jukebox is dead (no power)"
	return "Hold [%s] to %s the jukebox" % [prompt_key(&"interact"), "stop" if playing else "play"]


func can_interact(_player: Player) -> bool:
	return powered


func hold_time(_player: Player) -> float:
	return 0.3


func interact(_player: Player) -> void:
	if not powered or not Net.is_authority():
		return
	set_playing(not playing)
	Net.mirror(self, &"set_playing", [playing])


func set_playing(on: bool) -> void:
	playing = on
	if on:
		if _player == null and AudioDirector.has_sound(sound_key):
			_player = AudioDirector.make_loop_3d(sound_key, self, 0.0)
			if _player != null:
				_player.position = Vector3(0, 0.4, -0.35)
				_player.unit_size = 4.0
				_player.max_distance = 40.0
		if _player != null:
			_player.play()
	elif _player != null:
		_player.stop()


func _process(delta: float) -> void:
	if not powered or not playing:
		return
	_t += delta
	# the tubes breathe with the beat (128 bpm)
	var k: float = 0.85 + 0.15 * sin(_t * TAU * 128.0 / 60.0)
	if _light != null:
		_light.light_energy = 1.1 * k
