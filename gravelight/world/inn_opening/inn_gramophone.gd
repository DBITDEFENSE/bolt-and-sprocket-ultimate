class_name InnGramophone
extends Node3D
## The taproom's gramophone on the bar (T-072): the patrons left a record turning when they ran, and it keeps
## playing into the night until somebody shoots it (a decor hit: the needle skids off and the horn rings) or it
## runs down on its own at round `stop_round` (the spring winds out: the record slows and stops). A wind-up cabinet,
## a turning disc and a brass horn; the music is the Siren Gramophone's record loop, quiet. Local presentation (the
## decor-hit protocol): co-op peers each hear their own copy. Origin: the cabinet's foot on the counter, the horn
## toward local -Z.

@export var stop_round: int = 3
@export var volume_db: float = -9.0

var playing: bool = false
var stopped_by: StringName = &""
var _disc: Node3D
var _loop: AudioStreamPlayer3D
var _spin: float = 1.0
var _winding_down: bool = false


func _ready() -> void:
	_block(Vector3(-0.17, 0.0, -0.17), Vector3(0.17, 0.14, 0.17), "furniture")
	_block(Vector3(-0.18, 0.14, -0.18), Vector3(0.18, 0.155, 0.18), "beam")
	_disc = Node3D.new()
	_disc.position = Vector3(0, 0.16, 0)
	add_child(_disc)
	var d: MeshInstance3D = _cyl(_disc, Vector3.ZERO, 0.14, 0.008, "black_paint")
	d.rotation = Vector3.ZERO
	_cyl(_disc, Vector3(0, 0.006, 0), 0.04, 0.004, "paper")   # the label
	_block(Vector3(0.11, 0.16, 0.1), Vector3(0.13, 0.2, 0.12), "brass")   # the tone arm's post
	var arm: MeshInstance3D = MeshInstance3D.new()
	arm.mesh = Props.unit_box()
	arm.scale = Vector3(0.012, 0.012, 0.15)
	arm.position = Vector3(0.07, 0.2, 0.05)
	arm.rotation.y = deg_to_rad(35.0)
	arm.material_override = Mats.get_mat("brass")
	add_child(arm)
	# the horn: a flared brass cone on a neck, pointing out over the counter
	var neck: MeshInstance3D = _cyl(self, Vector3(0.12, 0.3, 0.05), 0.018, 0.25, "brass")
	neck.rotation = Vector3(deg_to_rad(-20.0), 0, 0)
	var horn: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.025
	cm.height = 0.36
	cm.radial_segments = 14
	cm.cap_top = false
	horn.mesh = cm
	horn.material_override = Mats.get_mat("brass")
	horn.position = Vector3(0.12, 0.5, -0.12)
	horn.rotation = Vector3(deg_to_rad(-70.0), 0, 0)
	horn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(horn)
	# the shot volume (decor layer only: nothing walks into it, shots carry on through)
	DecorHit.make_area(self, Vector3(0.05, 0.3, -0.05), 0.24)
	GLBus.round_started.connect(_on_round)
	_start.call_deferred()


func _block(a: Vector3, b: Vector3, key: String) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = Props.unit_box()
	mi.scale = (b - a).abs()
	mi.position = (a + b) * 0.5
	mi.material_override = Mats.get_mat(key)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.position = pos
	mi.material_override = Mats.get_mat(key)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _start() -> void:
	if RoundManager.current_round >= stop_round:
		return
	_loop = AudioDirector.make_loop_3d("gramophone_record", self, volume_db)
	if _loop != null:
		_loop.unit_size = 3.0
		_loop.max_distance = 22.0
		_loop.play()
	playing = true


func _process(delta: float) -> void:
	if not playing and not _winding_down:
		return
	_disc.rotation.y -= delta * TAU * 78.0 / 60.0 * _spin


func _on_round(r: int, _special: bool) -> void:
	if r >= stop_round and playing:
		wind_down()


## The spring runs out: the record slows over a few seconds and stops.
func wind_down() -> void:
	if not playing:
		return
	playing = false
	_winding_down = true
	stopped_by = &"spring"
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void:
		_spin = k
		if _loop != null:
			_loop.pitch_scale = maxf(0.3, k), 1.0, 0.25, 4.0)
	tw.tween_callback(_silence)


func _silence() -> void:
	_winding_down = false
	_spin = 0.0
	if _loop != null:
		_loop.stop()
		_loop.queue_free()
		_loop = null


## A shot: the needle skids across the record and it stops dead.
func on_decor_shot(_col: Area3D, _at: Vector3, _dir: Vector3) -> void:
	if not playing and not _winding_down:
		AudioDirector.play_3d("lamp_knock", global_position + Vector3.UP * 0.4, -2.0)
		return
	playing = false
	stopped_by = &"shot"
	AudioDirector.play_3d("gramophone_needle", global_position + Vector3.UP * 0.2, 0.0, 0.0)
	_silence()
