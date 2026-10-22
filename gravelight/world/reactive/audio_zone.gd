class_name AudioZone
extends Node3D
## A positional ambience source (Update 02 section 8, T-053), one of two kinds:
##   loop    a looping sound at this node (the fireplace's crackle, the wind howling through a broken window). It
##           can swell with the wind (`wind_db` at a full gust) and follow a light (`follow_light`: quieter as that
##           light's base energy sinks; silent once it is out, e.g. the hearth in the Cousins Round) and grow as a
##           window's barricade loses boards (`window`, up to `broken_db` louder with every board gone).
##   random  one-shots from a random point in the `spread` box round this node, every `interval` seconds (the
##           stable's timbers creaking; the horse in the stalls, which only rounds `min_round`..`max_round` hear).
## `min_round` / `max_round` (0 = no limit) and `max_plays` (0 = no limit) gate both kinds. Sounds are AudioDirector
## keys. Presentation only: each co-op peer runs its own. Loops are rechecked five times a second.

@export var sound: String = ""
@export_enum("loop", "random") var mode: String = "loop"
@export var volume_db: float = 0.0
@export var interval: Vector2 = Vector2(15.0, 40.0)
@export var spread: Vector3 = Vector3.ZERO
@export var min_round: int = 0
@export var max_round: int = 0
@export var max_plays: int = 0
@export var wind_db: float = 0.0
@export var follow_light: NodePath = NodePath("")
@export var max_distance: float = 0.0
@export var window: NodePath = NodePath("")
@export var broken_db: float = 0.0

var plays: int = 0
var player: AudioStreamPlayer3D
var _wait: float = 0.0
var _check: float = 0.0
var _light: Light3D
var _light_base: float = 0.0
var _bar: Node = null
var _base_db: float = 0.0   # volume_db plus the bank's own trim for the key
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if not follow_light.is_empty():
		_light = get_node_or_null(follow_light) as Light3D
		if _light != null:
			_light_base = float(_light.get("base_energy")) if _light.get("base_energy") != null else _light.light_energy
	if not window.is_empty():
		_bar = get_node_or_null(window)
	if mode == "loop":
		player = AudioDirector.make_loop_3d(sound, self, volume_db)
		if player != null:
			_base_db = player.volume_db
			if max_distance > 0.0:
				player.max_distance = max_distance
	else:
		_wait = _rng.randf_range(interval.x, interval.y) * 0.5


## True when round `r` is inside this zone's rounds.
func round_ok(r: int) -> bool:
	return (min_round <= 0 or r >= min_round) and (max_round <= 0 or r <= max_round)


## 0..1: how much of the followed light is left (1 with no light).
func light_share() -> float:
	if _light == null or not is_instance_valid(_light) or _light_base <= 0.001:
		return 1.0
	var e: float = float(_light.get("base_energy")) if _light.get("base_energy") != null else _light.light_energy
	if not _light.visible:
		e = 0.0
	return clampf(e / _light_base, 0.0, 1.0)


func _process(delta: float) -> void:
	var r: int = maxi(1, RoundManager.current_round)
	if mode == "loop":
		_check -= delta
		if _check > 0.0 or player == null:
			return
		_check = 0.2
		var share: float = light_share()
		var want: bool = round_ok(r) and share > 0.12 and (max_plays <= 0 or plays < max_plays)
		if want and not player.playing:
			player.play(_rng.randf() * maxf(0.0, player.stream.get_length() - 0.1) if player.stream != null else 0.0)
			plays += 1
		elif not want and player.playing:
			player.stop()
		var wind: float = ReactiveWind.strength(get_tree()) if wind_db != 0.0 else 0.0
		var broken: float = 0.0
		if _bar != null and is_instance_valid(_bar) and _bar.get("boards") != null:
			broken = (6.0 - clampf(float(_bar.get("boards")), 0.0, 6.0)) / 6.0
		player.volume_db = _base_db + wind_db * clampf(wind, 0.0, 1.2) + broken_db * broken + (linear_to_db(maxf(0.05, share)) if _light != null else 0.0)
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _rng.randf_range(interval.x, interval.y)
	if not round_ok(r) or (max_plays > 0 and plays >= max_plays):
		return
	var off: Vector3 = Vector3(_rng.randf_range(-spread.x, spread.x), _rng.randf_range(-spread.y, spread.y), _rng.randf_range(-spread.z, spread.z))
	AudioDirector.play_3d(sound, global_position + off, volume_db)
	plays += 1
