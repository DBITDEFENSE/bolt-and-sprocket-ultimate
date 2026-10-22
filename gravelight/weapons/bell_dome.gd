class_name BellDome
extends Node3D
## The Totenglocke's alt-fire (T-048): the bell's ring planted as a resonance field. For `seconds`, zombies inside
## `radius` move at (1 - slow) of their speed (Zombie.apply_frost, refreshed) and take `damage_mult` damage
## (Zombie.set_vulnerable). Mitternacht's dome also pulls them toward the bell (`pull` m/s, collision-aware).
## Bosses are slowed but never pulled. One per player at a time (the Totenglocke instance keeps it).
## Co-op: the field runs on the machine that planted it; frost is forwarded to the host by Zombie.apply_frost,
## the damage bonus and the pull only act on zombies this machine simulates.

const TICK: float = 0.1

var radius: float = 6.0
var seconds: float = 8.0
var slow: float = 0.6
var damage_mult: float = 1.25
var pull: float = 0.0
var color: Color = Color(1.0, 0.62, 0.25)
var upgraded: bool = false
var by_player: int = 1

var _t: float = 0.0
var _tick: float = 0.0
var _dome: MeshInstance3D
var _ring: MeshInstance3D
var _mat: ShaderMaterial
var _ring_mat: StandardMaterial3D
var _light: OmniLight3D
var _hum: AudioStreamPlayer3D
var _inside: int = 0

const SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.62, 0.25, 1.0);
uniform float energy = 1.0;
uniform float t = 0.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float h = clamp(lp.y / 6.0, 0.0, 1.0);
	float bands = smoothstep(0.75, 1.0, sin(h * 38.0 - t * 5.0) * 0.5 + 0.5);
	ALBEDO = col.rgb;
	ALPHA = clamp((fres * 0.55 + bands * 0.12 + 0.025) * energy, 0.0, 1.0);
}
"""


## Is a zombie at `zpos` inside a dome at `center`? (A cylinder: flat distance, and within 3 m of height.)
static func contains(center: Vector3, r: float, zpos: Vector3) -> bool:
	return Vector2(zpos.x - center.x, zpos.z - center.z).length() <= r and absf(zpos.y - center.y) <= 3.0


func _ready() -> void:
	_dome = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius
	sm.is_hemisphere = true
	sm.radial_segments = 48
	sm.rings = 16
	_dome.mesh = sm
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh: Shader = Shader.new()
	sh.code = SHADER.replace("/ 6.0", "/ %.2f" % maxf(0.5, radius))
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("col", color)
	_mat.set_shader_parameter("energy", 0.0)
	_dome.material_override = _mat
	add_child(_dome)
	_ring = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = radius - 0.12
	tm.outer_radius = radius
	tm.rings = 64
	tm.ring_segments = 4
	_ring.mesh = tm
	_ring.scale = Vector3(1.0, 0.3, 1.0)
	_ring.position = Vector3(0, 0.05, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(color, 0.9)
	_ring.material_override = _ring_mat
	add_child(_ring)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = radius * 1.2
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.2, 0)
	add_child(_light)
	_hum = AudioDirector.make_loop_3d("totenglocke_dome", self, -2.0)
	if _hum != null:
		_hum.position = Vector3(0, 1.0, 0)
		_hum.play()
	AudioDirector.play_3d("totenglocke_dome_plant", global_position + Vector3.UP, 2.0, 0.0)
	if upgraded:
		AudioDirector.play_3d("totenglocke_midnight", global_position + Vector3.UP, -4.0, 0.0)
	Totenglocke.burst(get_parent(), global_position + Vector3.UP * 0.2, color, 30, 5.0)


func time_left() -> float:
	return maxf(0.0, seconds - _t)


## Zombies inside at the last tick (tests / the smoke).
func inside_count() -> int:
	return _inside


func _process(delta: float) -> void:
	_t += delta
	var grow: float = clampf(_t / 0.35, 0.0, 1.0)
	var fade: float = clampf((seconds - _t) / 0.8, 0.0, 1.0)
	var e: float = grow * fade
	_dome.scale = Vector3.ONE * lerpf(0.2, 1.0, 1.0 - pow(1.0 - grow, 3.0))
	_mat.set_shader_parameter("t", _t)
	_mat.set_shader_parameter("energy", e * (0.85 + 0.15 * sin(_t * 9.0)))
	_ring_mat.albedo_color = Color(color, 0.85 * e)
	_light.light_energy = 1.6 * e * (0.8 + 0.2 * sin(_t * 13.0))
	if _hum != null:
		_hum.volume_db = lerpf(-30.0, -2.0, e)
	if _t >= seconds:
		queue_free()


func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0 or _t >= seconds:
		return
	_tick = TICK
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var c: Vector3 = global_position
	var n: int = 0
	for z: Zombie in dir.active_zombies():
		if not contains(c, radius, z.global_position):
			continue
		n += 1
		z.apply_frost(slow, TICK * 3.0)
		z.set_vulnerable(damage_mult, 0.6)
		if pull > 0.0 and not z.puppet and not Totenglocke.is_boss(z) and z.state == Zombie.State.CHASE:
			var to_c: Vector3 = c - z.global_position
			to_c.y = 0.0
			if to_c.length() > 1.3:
				z.move_and_collide(to_c.normalized() * pull * TICK)
	_inside = n
