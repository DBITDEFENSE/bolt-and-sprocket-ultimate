class_name BoomBoxDevice
extends Node3D
## A landed B.O.O.M. Box: projects the dance floor, makes everyone in range DANCE (status "dancing", applied through
## the target's Status child and a zero-damage Combat.Hit carrying the status), then drops the bass on the next beat
## (BeatClock). Enemies are expected to read Status "dancing" and stop acting (helpless dance, BS_WEAPONS §4).
## Bonus bolt drops: add_bonus_drops(n) when an enemy has it, else EnemyBase.stolen += n (dropped on death).

var weapon: BSWeapon
var amount: float = 45.0
var radius: float = 5.5
var dance_time: float = 1.6
var beat_wait_max: float = 2.5
var drop_mul: float = 1.0
var radio_delay: float = -1.0
var boss_mul: float = 0.7
var launch: float = 0.0
var encore_mul: float = 0.0
var bonus_drops: int = 0
var double_drops: bool = false
var dancers: Array = []           # [{e, t (dance left), wait (beat countdown or -1), done}]
var _encore: Array = []
var _encore_t: float = -1.0
var _floor: MeshInstance3D
var _age: float = 0.0
var _started: bool = false


func _ready() -> void:
	top_level = true
	_floor = WeaponFX.disc(self, radius, Color("#ff4dd2"), 0.3)
	_floor.position.y = -0.3
	var box: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.5, 0.45, 0.4)
	box.mesh = bm
	box.material_override = WeaponFX.glow_mat(Color("#2a1030"))
	add_child(box)


## Runs on the first physics frame (the owner sets global_position right after add_child).
func _start() -> void:
	_started = true
	for c: String in ["#ff4dd2", "#3ee6ff", "#ffd23e"]:
		WeaponFX.ring(get_parent(), global_position, radius, Color(c), 0.5)
	var tree: SceneTree = get_tree()
	for e: Node3D in Combat.in_radius(tree, global_position, radius):
		if e.is_in_group(&"props"):
			continue
		if e.is_in_group(&"bosses") or WeaponData.prop_bool(e, "armored"):
			weapon.deal(e, roundf(amount * boss_mul), e.call("get_center"))   # bosses don't dance, sadly
			continue
		var hold: float = dance_time + (beat_wait_max if radio_delay < 0.0 else 0.0)
		var h: Combat.Hit = weapon.make_hit(0.0, e.call("get_center"))
		h.status = {"dancing": maxf(hold, radio_delay)}
		weapon.mgr.deal_damage(e, h)
		var extra: int = bonus_drops
		if double_drops:
			extra += int(e.get("drops")) if "drops" in e else 4
		if extra > 0:
			if e.has_method("add_bonus_drops"):
				e.call("add_bonus_drops", extra)
			elif "stolen" in e:
				e.set("stolen", int(e.get("stolen")) + extra)
		dancers.append({"e": e, "t": radio_delay if radio_delay >= 0.0 else dance_time, "wait": -1.0, "done": false, "radio": radio_delay >= 0.0})


func has_dancers() -> bool:
	for d: Dictionary in dancers:
		if not bool(d["done"]):
			return true
	return false


func _physics_process(dt: float) -> void:
	if not _started:
		_start()
	_age += dt
	_floor.rotation.y += dt * 0.8
	for d: Dictionary in dancers:
		if bool(d["done"]):
			continue
		var e: Node3D = d["e"]
		if not is_instance_valid(e) or not bool(e.call("is_alive")):
			d["done"] = true
			continue
		if float(d["wait"]) < 0.0:
			d["t"] = float(d["t"]) - dt
			if float(d["t"]) <= 0.0:
				if bool(d["radio"]):
					_drop(d, drop_mul)
				else:
					d["wait"] = minf(BeatClock.time_to_next_beat(get_tree()), beat_wait_max)   # the drop lands ON the beat
		else:
			d["wait"] = float(d["wait"]) - dt
			if float(d["wait"]) <= 0.0:
				_drop(d, drop_mul)
	if _encore_t >= 0.0:
		_encore_t -= dt
		if _encore_t < 0.0:
			for e2: Variant in _encore:
				if is_instance_valid(e2) and bool((e2 as Node3D).call("is_alive")):
					weapon.deal(e2, roundf(amount * encore_mul), (e2 as Node3D).call("get_center"))
			weapon.popup.emit("bs.weapon.fx.encore", global_position)
			_encore.clear()
	if not has_dancers() and _encore_t < 0.0 and _age > 0.6:
		queue_free()


## DROP THE BASS (alt-fire): everyone still dancing takes the drop now.
func drop_now(mul: float) -> void:
	if not _started:
		_start()
	for d: Dictionary in dancers:
		if not bool(d["done"]):
			_drop(d, drop_mul * mul)


func _drop(d: Dictionary, mul: float) -> void:
	d["done"] = true
	var e: Node3D = d["e"]
	if not is_instance_valid(e) or not bool(e.call("is_alive")):
		return
	var st: StatusEffects = e.get_node_or_null("Status") as StatusEffects
	if st != null:
		st.clear(&"dancing")
	var c: Vector3 = e.call("get_center")
	var h: Combat.Hit = weapon.make_hit(roundf(amount * mul), c, c - global_position)
	h.launch = launch
	WeaponFX.flash(get_parent(), c, Color("#ff4dd2"), 0.5, 0.2)
	weapon.mgr.deal_damage(e, h)
	if encore_mul > 0.0:
		_encore.append(e)
		if _encore_t < 0.0:
			_encore_t = BeatClock.time_to_next_beat(get_tree()) + 0.001
