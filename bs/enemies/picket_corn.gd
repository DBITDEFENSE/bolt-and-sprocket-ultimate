class_name PicketCorn
extends EnemyBase
## Picket Corn — NEW neutral faction (BS_ENEMIES §3.5). 50 HP / 2.5 / 8 sign-bash (only when hostile) / 5 bolts.
## Tall corn stalks with googly eyes, hard hats and hand-painted picket signs ("LOCAL 404", "DENTAL NOW",
## "WE ARE NOT A CROP"). Groups march in a loop (opts loop_center / loop_r / loop_phase) and chant. They're
## NEUTRAL: they never perceive or hunt Bolt; enemies attack them (group "enemy_decoys": the framework's taunt
## rule makes a closer corn the target). HITTING a corn with a player hit (splash included) makes it hostile
## for `hostile_time` (20 s): it chases, sign-bashes for 8 (0.5 s telegraph: the sign goes up, the chant cuts
## to a shout, the hard-hat lamp glows red) and chants angrier. Enemy hits never anger it.
## Spectators (opts spectator) stand still and cheer(). Elite (Shop Steward, union-red rim): if it's hit,
## every corn in its group turns hostile; the Picket Line pop-up doubles its reward when it survives.
## Signals hit_by_player(corn, hit) (the planet's pop-up fails on it) and went_hostile(corn).

signal hit_by_player(corn: Node3D, hit: Combat.Hit)
signal went_hostile(corn: Node3D)

const CHANTS: Array = ["bs.verdant.chant_01", "bs.verdant.chant_02", "bs.verdant.chant_03"]

var corn_group: String = ""
var loop_center: Vector3 = Vector3.INF
var loop_r: float = 5.0
var loop_phase: float = 0.0
var spectator: bool = false
var steward: bool = false
var hostile_t: float = 0.0
var bashes: int = 0
var cheer_t: float = 0.0
var deal_chant: bool = false
var _sign: Node3D
var _sign_lbl: Label3D
var _lamp_mat: StandardMaterial3D
var _chant_i: int = 0
var _chant_t: float = 0.0


func CN() -> Dictionary:
	return def["corn"]


func _build_visual() -> void:
	var husk: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#8fc24a"))))
	flash_mats.append(husk)
	var kernel: StandardMaterial3D = EnemyFx.mat(Color("#ffd23e"))
	EnemyFx.cyl(visual, 0.22, 1.5, Vector3(0, 0.75, 0), husk, 0.16)
	EnemyFx.cyl(visual, 0.2, 0.7, Vector3(0, 1.45, 0), kernel, 0.14)
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0
		EnemyFx.box(visual, Vector3(0.12, 0.5, 0.04), Vector3(cos(a) * 0.22, 0.9 + 0.1 * i, sin(a) * 0.22), husk).rotation.y = -a
	# googly eyes and the hard hat (with its lamp)
	for sx: float in [-0.09, 0.09]:
		EnemyFx.sphere(visual, 0.06, Vector3(sx, 1.55, 0.18), EnemyFx.mat(Color("#ffffff")))
		EnemyFx.sphere(visual, 0.03, Vector3(sx, 1.55, 0.235), EnemyFx.mat(Color("#101010")))
	EnemyFx.cyl(visual, 0.26, 0.14, Vector3(0, 1.86, 0), EnemyFx.mat(Color("#ffb02e")), 0.2)
	_lamp_mat = EnemyFx.mat(Color("#d8dee9"), Color("#d42f2f"), 0.0)
	_lamp_mat.emission_enabled = true
	EnemyFx.sphere(visual, 0.05, Vector3(0, 1.9, 0.22), _lamp_mat)
	# the picket sign
	_sign = Node3D.new()
	_sign.position = Vector3(0.3, 1.0, 0)
	visual.add_child(_sign)
	EnemyFx.box(_sign, Vector3(0.05, 1.4, 0.05), Vector3(0, 0.3, 0), EnemyFx.mat(Color("#c9b89a")))
	EnemyFx.box(_sign, Vector3(0.9, 0.5, 0.04), Vector3(0, 1.1, 0), EnemyFx.mat(Color("#ffd23e")))
	_sign_lbl = Label3D.new()
	_sign_lbl.font_size = 36
	_sign_lbl.pixel_size = 0.006
	_sign_lbl.modulate = Color("#2a1a10")
	_sign_lbl.position = Vector3(0, 1.1, 0.03)
	_sign_lbl.text = "LOCAL 404"
	_sign.add_child(_sign_lbl)
	var back: Label3D = Label3D.new()
	back.font_size = 36
	back.pixel_size = 0.006
	back.modulate = Color("#2a1a10")
	back.position = Vector3(0, 1.1, -0.03)
	back.rotation.y = PI
	back.text = "LOCAL 404"
	_sign.add_child(back)


func _on_activate() -> void:
	add_to_group(&"enemy_decoys")
	add_to_group(&"picket_corn")
	corn_group = str(opts.get("group", ""))
	set_meta(&"corn_group", corn_group)
	spectator = bool(opts.get("spectator", false))
	steward = bool(opts.get("steward", false))
	loop_r = float(opts.get("loop_r", 5.0))
	loop_phase = float(opts.get("loop_phase", 0.0))
	loop_center = opts.get("loop_center", Vector3.INF) if opts.get("loop_center") is Vector3 else Vector3.INF
	if loop_center == Vector3.INF and loop_r > 0.0:
		loop_center = (global_position if is_inside_tree() else position) - Vector3(cos(loop_phase), 0, sin(loop_phase)) * loop_r
	hostile_t = 0.0
	bashes = 0
	cheer_t = 0.0
	deal_chant = false
	aggro = false
	_chant_i = int(loop_phase * 3.0) % CHANTS.size()
	_chant_t = randf_range(1.0, 4.0)
	if steward and not elite:
		elite = true
		_apply_rim()
	_set_chant(CHANTS[_chant_i])


func _set_chant(line_id: String) -> void:
	var txt: String = LevelKit.text(line_id)
	if _sign_lbl != null:
		_sign_lbl.text = txt
		for c: Node in _sign.get_children():
			if c is Label3D:
				(c as Label3D).text = txt


func is_hostile() -> bool:
	return hostile_t > 0.0


## Neutral corn never perceive Bolt; hostile corn already have him.
func _perceive(_dt: float) -> void:
	pass


func _timers(delta: float) -> void:
	super._timers(delta)
	cheer_t -= delta
	if hostile_t > 0.0:
		hostile_t -= delta
		if hostile_t <= 0.0:
			aggro = false
			_lamp_mat.emission_energy_multiplier = 0.0
			_set_chant(CHANTS[_chant_i])
			if state == State.CHASE:
				_set_state(State.IDLE)
	_chant_t -= delta
	if _chant_t <= 0.0 and not is_hostile() and not deal_chant:
		_chant_t = randf_range(3.0, 6.0)
		_chant_i = (_chant_i + 1) % CHANTS.size()
		_set_chant(CHANTS[_chant_i])


## Marching the loop (neutral) or standing on the rim (spectator).
func _idle_update(dt: float) -> void:
	if spectator or loop_center == Vector3.INF or loop_r <= 0.0:
		desired_vel = Vector3.ZERO
		return
	loop_phase += dt * float(CN().get("march_speed", 2.5)) / maxf(1.0, loop_r)
	var goal: Vector3 = loop_center + Vector3(cos(loop_phase), 0, sin(loop_phase)) * loop_r
	var to: Vector3 = goal - global_position
	to.y = 0.0
	if to.length() > 0.3:
		desired_vel = to.normalized() * minf(float(CN().get("march_speed", 2.5)), to.length() * 2.0) * move_mult() if can_move() else Vector3.ZERO
		face(to, dt, 5.0)
	else:
		desired_vel = Vector3.ZERO


func _position_update(dt: float) -> void:
	if not is_hostile():
		_set_state(State.IDLE)
		return
	var d: float = flat_dist_to_target()
	if d < float(CN()["bash_range"]) and contact_cd <= 0.0 and can_attack() and target_alive():
		if AttackTokens.request_melee(self, target_onscreen()):
			begin_telegraph(&"bash", float(telegraph_def(&"bash").get("dur", 0.5)))
			return
	steer_toward(target_pos(), float(CN().get("hostile_speed", 3.2)))
	var _u: float = dt


func _telegraph_update(dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_sign.rotation.x = -k * 1.4                       # the sign goes up overhead
	_lamp_mat.emission_energy_multiplier = 1.0 + k * 3.0
	face(target_pos() - global_position, dt, 10.0)


func _attack_begin() -> void:
	_sign.rotation.x = 0.6                            # the swing
	bashes += 1
	contact_cd = float(CN()["bash_cd"])
	if target_alive() and flat_dist_to_target() < float(CN()["bash_range"]) + 0.4 and not target_dodging():
		hurt_target(float(def["dmg"]), float(CN().get("knock", 6.0)))


func _attack_update(_dt: float) -> bool:
	return state_t >= 0.2


func _recover_update(_dt: float) -> bool:
	_sign.rotation.x = lerpf(_sign.rotation.x, 0.0, 0.2)
	return state_t >= 0.5


func _on_attack_cancelled() -> void:
	_sign.rotation.x = 0.0


## A player hit (anything not dealt by an enemy) is a grievance: hostile for 20 s; the steward angers its group.
func _on_hurt(hit: Combat.Hit, _amount: float, _crit: bool) -> void:
	var by_enemy: bool = hit.source != null and is_instance_valid(hit.source) and (hit.source is EnemyBase or hit.source.is_in_group(&"enemies"))
	if by_enemy and not (hit.source is PicketCorn):
		return
	if hit.weapon_id == &"murk" or hit.weapon_id == &"burning" or hit.weapon_id == &"boss_down":
		return
	hit_by_player.emit(self, hit)
	go_hostile()
	if steward and is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group(&"picket_corn"):
			var c: PicketCorn = n as PicketCorn
			if c != null and c != self and c.corn_group == corn_group and c.is_alive():
				c.go_hostile()


func go_hostile() -> void:
	if spectator:
		return
	var was: bool = is_hostile()
	hostile_t = float(CN().get("hostile_time", 20.0))
	target = get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	aggro = target != null
	_set_chant("bs.verdant.corn_angry")
	_lamp_mat.emission_energy_multiplier = 1.5
	if not was:
		went_hostile.emit(self)
		if is_inside_tree():
			EventBus.bark.emit("bs.verdant.corn_hit")
	if aggro and (state == State.IDLE or state == State.PATROL):
		_set_state(State.CHASE)


## Spectators and the picket line cheer a sealed leak (a hop and a sign wave).
func cheer(seconds: float) -> void:
	cheer_t = seconds


func chant_deal(on: bool) -> void:
	deal_chant = on
	_set_chant("bs.verdant.chant_deal" if on else CHANTS[_chant_i])


func _owns_visual_y() -> bool:
	return true


func _anim(_delta: float) -> void:
	var hv: float = Vector2(velocity.x, velocity.z).length()
	visual.rotation.z = sin(t * 6.0) * (0.08 if hv > 0.2 else 0.02)
	if cheer_t > 0.0:
		visual.position.y = absf(sin(t * 10.0)) * 0.35
		_sign.rotation.z = sin(t * 12.0) * 0.5
	elif state != State.TELEGRAPH and state != State.ATTACK and state != State.RECOVER:
		visual.position.y = 0.0
		_sign.rotation.z = sin(t * 2.0) * 0.12
		_sign.rotation.x = 0.0
