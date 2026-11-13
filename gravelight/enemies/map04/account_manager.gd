class_name AccountManager
extends HomageBoss
## THE ACCOUNT MANAGER, the finale (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.7, T-113): the Woman in Violet's
## executive machine, a tall ledger-faced unit of the Underwriter's family, her voice through it, attending remotely.
## She stands behind the console and never leaves it. Three contract phases by HP (bosses/map04.json
## "account_manager"): ONBOARDING (the welcome arms: a telegraphed 180° sweep in front of her; the console shielded),
## RENEWAL at `renewal_at` (the renewal clock starts on the MondlichtController; the trial tray appears: every perk
## for a minute, then all of them stripped; her Reinholt line when Dutch is present), COLLECTIONS at `collections_at`
## (the field drops; she prices players in range: a stamp at 90 damage and a tenth of their Scrip; the Kranich's
## crew through the pad every `crew.every` s; three shield-cells orbit her and take most of the damage until shot or
## flung into the vacuum shaft). Each phase is announced and "presented": for `present.seconds` her chest plate is
## open and the torso is the weak point (x`weak_mult`), again every `present.every` s. She never dies: at 0 % (or
## the failsafe) she ESCALATES: folds, says her line, the flag `manager_escalated` unlocks the console's cover.
## Nobody human dies in the finale; the dead are the horde's. Pure rules are static for the tests.
## T-234 (docs/BOSS_REWORK.md, docs/boss_rework/w4_fernflug.md): tall and elegant: the ledger face carries lit
## signature lines (violet script over brass rulings) and the two lenses are her "eyes" (lit, never blinking); the
## chest plate really opens on a hinge when a contract is presented, the signature line behind it lit violet; the
## cabinet wears brass trim and ledger script; her light is a violet spot from the console onto the floor in front
## of her. Sound: `manager_servo` on every move, `manager_stamp` on a pricing, `manager_field_hum` while the field
## is up; every telegraph lights through the kit; the shield-cells hum and spark when hit (ShieldCell). The new
## beat: COLLECTIONS puts the Account's lamps out (the kit; her light stays) and when nobody alive has stood in her
## light for `price.dark_after` s she prices the whole squad at once (`price_all`: a `price.all_telegraph` telegraph
## with the servo and the hum rising and her light flaring, then `price.all_damage` and `price.all_scrip_fraction`
## of every living player's account, cooldown `price.all_cooldown`). The squad rule: with one human standing the
## presented contract stays open `present.seconds` x `present.alone_mult` (she is polite to a squad of one).

enum W { IDLE, ARMS_TELE, ARMS, PRICE_TELE, PRICE, RECOVER, FOLDED, PRICE_ALL_TELE }

const VIOLET: Color = Color(0.4, 0.18, 0.62)
const VIOLET_LIT: Color = Color(0.78, 0.5, 1.0)
const BRASS: Color = Color(0.7, 0.58, 0.3)

var wcfg: Dictionary = {}
var wstate: W = W.IDLE
var phase: int = 1
var station: Vector3 = Vector3.ZERO
var escalated: bool = false
var presenting: float = 0.0
var _present_t: float = 0.0
var _wt: float = 0.0
var _spawn_t: float = 0.0
var _price_target: Player = null
var _crew_t: float = 0.0
var _trial_t: float = -1.0
var _trial_cycle_t: float = 0.0
var _reinholt_t: float = -1.0
var _slots: Array[Dictionary] = []    # per cell: {cell: ShieldCell|null, regen: float (<0 idle), lost: bool}
var _title_done: bool = false
var trial: Node3D = null
var trial_takers: Array[int] = []
var arms_done: int = 0
var prices_done: int = 0
var crews_done: int = 0
var cells_lost: int = 0
var cells_shot: int = 0
var presents_done: int = 0
# T-234
var prices_all_done: int = 0
var dark_t: float = 0.0               # seconds since somebody alive last stood in her light (COLLECTIONS)
var collections_dark: bool = false    # the Account's lamps are out
var _plate_piv: Node3D = null
var _sig_mat: StandardMaterial3D = null
var _sig_light: OmniLight3D = null
var _face_mat: StandardMaterial3D = null
var _spot: SpotLight3D = null
var _field_hum: AudioStreamPlayer3D = null
var _idle_servo_t: float = 6.0
var _plate_open: bool = false


static func table() -> Dictionary:
	return GLData.table("bosses/map04")


func boss_cfg() -> Dictionary:
	return (table().get("bosses", {}) as Dictionary).get("account_manager", {})


## Phase by HP fraction: 1 ONBOARDING, 2 RENEWAL, 3 COLLECTIONS.
static func phase_of(hp_fraction: float, phases: Dictionary) -> int:
	if hp_fraction <= float(phases.get("collections_at", 0.35)):
		return 3
	if hp_fraction <= float(phases.get("renewal_at", 0.7)):
		return 2
	return 1


## Damage taken: x weak on the torso while a contract is presented; x shielded while any cell lives (phase 3).
static func damage_mult(limb: StringName, presenting_now: bool, cells_alive: int, weak: float, shielded: float) -> float:
	var m: float = 1.0
	if presenting_now and limb == &"torso":
		m *= weak
	if cells_alive > 0:
		m *= shielded
	return m


## The Scrip a pricing stamp takes: a fraction of the account, at least 1 when there is anything.
static func price_cut(scrip: int, fraction: float) -> int:
	if scrip <= 0:
		return 0
	return maxi(1, int(round(float(scrip) * fraction)))


## T-234: true when `p` stands in her light: within `range_m` (flat) of `origin` and within acos(cos_min) of `fwd`.
static func in_light(origin: Vector3, fwd: Vector3, p: Vector3, range_m: float, cos_min: float) -> bool:
	var d: Vector3 = p - origin
	d.y = 0.0
	if d.length() > range_m:
		return false
	var f: Vector3 = Vector3(fwd.x, 0, fwd.z)
	if d.length() < 0.05 or f.length() < 0.01:
		return true
	return d.normalized().dot(f.normalized()) >= cos_min


## T-234: the squad pricing is due in COLLECTIONS when nobody has stood in her light for `dark_after` s and its
## cooldown is over.
static func price_all_due(phase_now: int, dark_seconds: float, dark_after: float, cooldown_ready: bool) -> bool:
	return phase_now >= 3 and cooldown_ready and dark_seconds >= dark_after


## T-234: how long a presented contract stays open: `alone_mult` x with one human standing.
static func present_seconds(base: float, humans_up: int, alone_mult: float) -> float:
	return base * (alone_mult if humans_up <= 1 else 1.0)


func _ready() -> void:
	super._ready()
	boss_key = "account_manager"
	ecfg = table()
	wcfg = boss_cfg()
	bcfg = wcfg
	station = _v3(wcfg.get("station", [28.0, 0.0, -34.0]))


static func _v3(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and (a as Array).size() >= 3 else Vector3.ZERO


func modelled() -> bool:
	return false


func person_id() -> String:
	return "account_manager"


func rcfg() -> Dictionary:
	return wcfg.get("rework", {})


func say(line_id: String) -> void:
	if line_id != "":
		GLVO.play(StringName(line_id))


func spawn_manager(_at: Vector3, health: float) -> void:
	spawn_homage(station, health)
	enemy_id = &"account_manager"
	wstate = W.IDLE
	_wt = 2.0
	_spawn_t = 0.0
	phase = 1
	escalated = false
	presenting = 0.0
	dark_t = 0.0
	collections_dark = false
	_present_t = float((wcfg.get("present", {}) as Dictionary).get("every", 20.0)) * 0.5
	_crew_t = 6.0
	_trial_t = -1.0
	_trial_cycle_t = 0.0
	_set_inst("inst_dirt", 0.0)
	RoundManager.reserve_alive(1)
	if _field_hum != null:
		_field_hum.play()
	if not _title_done:
		_title_done = true
		var hud: BossHud = BossHud.new()
		_map().add_child(hud)
		hud.title_card(str(wcfg.get("title", "THE ACCOUNT MANAGER")), str(wcfg.get("subtitle", "attending remotely")), str(wcfg.get("date_line", "MONDLICHT  ·  RR-7")))
		hud.add_bar("account_manager", self, str(wcfg.get("title", "THE ACCOUNT MANAGER")), "the contract")
	say(str(wcfg.get("spawn_vo", "")))
	_servo(0.0)
	get_tree().create_timer(6.0).timeout.connect(func() -> void: _present(1))


func _map() -> Node:
	var n: Node = get_parent()
	while n != null and not (n is MapRoot):
		n = n.get_parent()
	return n if n != null else get_parent()


# ================================================================== the model (T-234)

func _mesh_box(parent: Node3D, center: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	bm.material = m
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = bm
	mi.position = center
	parent.add_child(mi)
	return mi


func _build_costume() -> void:
	var brass_m: StandardMaterial3D = HomageBoss.mat_ex(BRASS, 0.35, 0.9)
	var violet_m: StandardMaterial3D = HomageBoss.mat_ex(VIOLET, 0.3, 0.4, 0.12, VIOLET_LIT)   # the first render bloomed the plate white at 0.5
	# the ledger face: a tall plate over the head, brass rulings and lit signature lines (her script), the lenses lit
	costume("Head", [HomageBoss.boxp(Vector3(0.3, 0.42, 0.06), Vector3(0, 0.1, -0.12), VIOLET)], 0.6)
	var head: Node3D = bone_attachment("Head")
	if head != null:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 41
		for i: int in 5:
			_mesh_box(head, Vector3(0, -0.07 + 0.045 * float(i), -0.152), Vector3(0.24, 0.003, 0.004), brass_m)
		_face_mat = StandardMaterial3D.new()
		_face_mat.albedo_color = VIOLET_LIT
		_face_mat.emission_enabled = true
		_face_mat.emission = VIOLET_LIT
		_face_mat.emission_energy_multiplier = 1.2
		for i: int in 9:
			var y: float = -0.06 + 0.045 * float(i % 5) + rng.randf_range(0.0, 0.03)
			var len_: float = rng.randf_range(0.05, 0.16)
			var x: float = rng.randf_range(-0.1, 0.1)
			var mi: MeshInstance3D = _mesh_box(head, Vector3(x, y, -0.154), Vector3(len_, 0.006, 0.003), _face_mat)
			mi.rotation.z = rng.randf_range(-0.25, 0.25)
		_mesh_box(head, Vector3(0, 0.31, -0.12), Vector3(0.32, 0.02, 0.08), brass_m)
	eye_glow(Color(0.92, 0.75, 1.0), 1.4, 0.0, [Vector3(-0.07, 0.16, -0.16), Vector3(0.07, 0.16, -0.16)])
	# the chest plate (the contract) on a hinge at its top edge; the signature line and its light behind it
	var chest: Node3D = bone_attachment("Chest")
	if chest != null:
		_plate_piv = Node3D.new()
		_plate_piv.name = "PlateHinge"
		_plate_piv.position = Vector3(0, 0.4, -0.14)
		chest.add_child(_plate_piv)
		_mesh_box(_plate_piv, Vector3(0, -0.25, -0.02), Vector3(0.42, 0.5, 0.04), violet_m)
		_mesh_box(_plate_piv, Vector3(0, -0.25, -0.045), Vector3(0.36, 0.42, 0.005), HomageBoss.mat_ex(Color(0.3, 0.14, 0.5), 0.25, 0.5))
		for i: int in 3:
			_mesh_box(_plate_piv, Vector3(0, -0.12 - 0.1 * float(i), -0.048), Vector3(0.3, 0.003, 0.003), brass_m)
		_mesh_box(chest, Vector3(0, 0.15, -0.1), Vector3(0.4, 0.5, 0.03), HomageBoss.mat_ex(Color(0.08, 0.06, 0.1), 0.5, 0.3))
		_sig_mat = StandardMaterial3D.new()
		_sig_mat.albedo_color = BRASS
		_sig_mat.metallic = 0.9
		_sig_mat.roughness = 0.3
		_sig_mat.emission_enabled = true
		_sig_mat.emission = VIOLET_LIT
		_sig_mat.emission_energy_multiplier = 0.0
		_mesh_box(chest, Vector3(0, 0.0, -0.12), Vector3(0.3, 0.02, 0.02), _sig_mat)
		_sig_light = OmniLight3D.new()
		_sig_light.light_color = VIOLET_LIT
		_sig_light.light_energy = 0.0
		_sig_light.omni_range = 3.0
		_sig_light.shadow_enabled = false
		_sig_light.position = Vector3(0, 0.05, -0.25)
		chest.add_child(_sig_light)
	# the welcome arms: long sleeves, telescoping in the sweep, brass at the joints
	for side: String in ["Left", "Right"]:
		costume(side + "UpperArm", [HomageBoss.cyl(0.07, 0.06, 0.34, Vector3(0, -0.15, 0), VIOLET), HomageBoss.sph(0.075, Vector3(0, 0.0, 0), BRASS)], 0.3)
		costume(side + "LowerArm", [HomageBoss.cyl(0.06, 0.05, 0.36, Vector3(0, -0.16, 0), VIOLET), HomageBoss.sph(0.06, Vector3(0, -0.36, 0), BRASS), HomageBoss.sph(0.065, Vector3(0, 0.0, 0), BRASS)], 0.3)
	# the skirt of the unit: a cabinet from the hips down, brass trim, ledger script down its face
	costume("Hips", [HomageBoss.boxp(Vector3(0.5, 0.9, 0.4), Vector3(0, -0.45, 0), VIOLET)], 0.4)
	var hips: Node3D = bone_attachment("Hips")
	if hips != null:
		for e: Array in [[Vector3(0, -0.02, 0), Vector3(0.54, 0.03, 0.44)], [Vector3(0, -0.89, 0), Vector3(0.54, 0.03, 0.44)],
				[Vector3(-0.255, -0.45, -0.205), Vector3(0.02, 0.9, 0.02)], [Vector3(0.255, -0.45, -0.205), Vector3(0.02, 0.9, 0.02)]]:
			_mesh_box(hips, e[0], e[1], brass_m)
	cracks("Hips", 12, 0.205, -0.8, -0.1, VIOLET_LIT, 1.5, 23)
	# her light: a violet spot from over the console onto the floor in front of her
	_spot = SpotLight3D.new()
	_spot.light_color = VIOLET_LIT
	_spot.light_energy = 1.8
	_spot.spot_range = 10.0
	_spot.spot_angle = 38.0
	_spot.spot_attenuation = 0.9
	_spot.shadow_enabled = false
	_spot.position = Vector3(0, 2.8, -0.4)
	_spot.rotation.x = -deg_to_rad(52.0)
	add_child(_spot)
	_field_hum = AudioDirector.make_loop_3d("manager_field_hum", self, float(rcfg().get("field_hum_db", -10.0)))


## The chest plate swings open (a presented contract) or shut.
func _set_plate(open: bool) -> void:
	if _plate_open == open:
		return
	_plate_open = open
	if _plate_piv != null:
		var tw: Tween = create_tween()
		tw.tween_property(_plate_piv, "rotation:x", -1.9 if open else 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _sig_mat != null:
		_sig_mat.emission_energy_multiplier = 3.0 if open else 0.0
	if _sig_light != null:
		_sig_light.light_energy = 2.2 if open else 0.0


func _servo(db: float = -4.0) -> void:
	AudioDirector.play_3d("manager_servo", global_position + Vector3.UP * 1.6, db + float(rcfg().get("servo_db", -4.0)) + 4.0, 0.05)


## True when `p` stands in her light.
func player_in_light(p: Player) -> bool:
	var pc: Dictionary = wcfg.get("price", {})
	return in_light(global_position, -global_basis.z, p.global_position, float(pc.get("light_range", 7.0)), float(pc.get("light_cos", 0.35)))


func _humans_up() -> int:
	var n: int = 0
	for p: Player in alive_players():
		if not p.is_bot:
			n += 1
	return n


func _tick(delta: float) -> void:
	if escalated:
		global_position = station
		velocity = Vector3.ZERO
		return
	_spawn_t += delta
	_wt -= delta
	if _spawn_t > float(ecfg.get("failsafe_seconds", 360.0)):
		escalate()   # a round can never softlock on her
		return
	var new_phase: int = phase_of(hp_fraction(), wcfg.get("phases", {}))
	if new_phase != phase:
		for ph: int in range(phase + 1, new_phase + 1):
			_enter_phase(ph)
		phase = new_phase
	global_position = station   # she never leaves the console
	velocity = Vector3.ZERO
	if target != null:
		_face(Vector3(target.global_position.x, global_position.y, target.global_position.z))
	# the contract presented now and then: the open plate
	if presenting > 0.0:
		presenting -= delta
		if presenting <= 0.0:
			_set_plate(false)
	else:
		_present_t -= delta
		if _present_t <= 0.0:
			_present(phase)
	if phase >= 2:
		_tick_trial(delta)
	if phase >= 3:
		_tick_collections(delta)
		var someone: bool = false
		for p: Player in alive_players():
			if player_in_light(p):
				someone = true
				break
		dark_t = 0.0 if someone else dark_t + delta
	match wstate:
		W.IDLE:
			if _wt > 0.0:
				return
			var ac: Dictionary = wcfg.get("arms", {})
			var pc: Dictionary = wcfg.get("price", {})
			if cd_ready("arms") and target != null and dist_to(target) <= float(ac.get("reach", 7.0)) + 1.0:
				wstate = W.ARMS_TELE
				_wt = tele_len(float(ac.get("telegraph", 1.2)))
				bstate = B.TELEGRAPH
				_servo(0.0)
				fx.tele(VIOLET_LIT, 4.0, _wt)
			elif price_all_due(phase, dark_t, float(pc.get("dark_after", 6.0)), cd_ready("price_all")):
				wstate = W.PRICE_ALL_TELE
				_wt = tele_len(float(pc.get("all_telegraph", 1.4)))
				bstate = B.TELEGRAPH
				_servo(2.0)
				fx.tele(VIOLET_LIT, 6.0, _wt)
				if _field_hum != null:
					_field_hum.volume_db = float(rcfg().get("field_hum_db", -10.0)) + 6.0
					_field_hum.play()
				if _spot != null:
					var tw: Tween = create_tween()
					tw.tween_property(_spot, "light_energy", 9.0, _wt * 0.8)
				fx.extra_dread = 0.5
				if prices_all_done == 0:
					var vo: Array = pc.get("vo", [])
					say(str(vo[1]) if vo.size() > 1 else "")
			elif phase >= 3 and cd_ready("price") and _pick_price_target(float(pc.get("range", 14.0))) != null:
				_price_target = _pick_price_target(float(pc.get("range", 14.0)))
				wstate = W.PRICE_TELE
				_wt = tele_len(float(pc.get("telegraph", 0.9)))
				bstate = B.TELEGRAPH
				_servo(-2.0)
				fx.tele(VIOLET_LIT, 4.0, _wt)
				if prices_done == 0:
					say(str((pc.get("vo", []) as Array)[0]) if (pc.get("vo", []) as Array).size() > 0 else "")
			else:
				_wt = 0.4
		W.ARMS_TELE:
			if _wt <= 0.0:
				_sweep()
				wstate = W.RECOVER
				_wt = 1.0
				bstate = B.RECOVER
		W.PRICE_TELE:
			if _wt <= 0.0:
				_stamp()
				wstate = W.RECOVER
				_wt = 0.8
				bstate = B.RECOVER
		W.PRICE_ALL_TELE:
			if _wt <= 0.0:
				_stamp_all()
				wstate = W.RECOVER
				_wt = 1.2
				bstate = B.RECOVER
		W.RECOVER:
			if _wt <= 0.0:
				wstate = W.IDLE
				bstate = B.MOVE
				_wt = 0.3
		_:
			pass


func _enter_phase(ph: int) -> void:
	_servo(1.0)
	match ph:
		2:
			var ctl: Node = get_tree().get_first_node_in_group(&"mondlicht_controller")
			if ctl != null and ctl.has_method("begin_renewal_clock"):
				ctl.call("begin_renewal_clock")
			_offer_trial()
			var tc: Dictionary = wcfg.get("trial", {})
			for pid: int in GameState.player_ids:
				if GameState.character_of(pid) == &"dutch" and not GameState.is_bot(pid):
					_reinholt_t = float(tc.get("reinholt_after", 10.0))
		3:
			_remove_trial()
			GameState.set_flag(&"manager_field_down")
			# T-234: the field drops (its hum with it) and the Account's lamps go out; her light stays. The lamps are
			# captured before the cells spawn (their glows are no_dim too): a captured light that is freed later would
			# trip the kit's flicker.
			if _field_hum != null:
				_field_hum.stop()
			collections_dark = true
			fx.lights_dim(station, float(rcfg().get("dark_radius", 22.0)), float(rcfg().get("dark_level", 0.1)), 3.0)
			fx.lights_flicker(2.0, 0.8)
			BossFx.burst("motes", station + Vector3.UP * 1.8, get_tree(), 2.0, 1.6)
			dark_t = 0.0
			_spawn_cells()
			_crew_t = 4.0
	_present(ph)


## The contract presented: the phase's line, the plate open for `seconds` (the torso x weak); longer for one human.
func _present(ph: int) -> void:
	var pc: Dictionary = wcfg.get("present", {})
	presenting = present_seconds(float(pc.get("seconds", 3.0)), _humans_up(), float(pc.get("alone_mult", 1.5)))
	_present_t = float(pc.get("every", 20.0))
	presents_done += 1
	_set_plate(true)
	_servo(-2.0)
	var vo: Array = pc.get("vo", [])
	if ph - 1 < vo.size() and presents_done <= 3:
		say(str(vo[ph - 1]))
	_hit_done = false


func presenting_now() -> bool:
	return presenting > 0.0


# ---------------------------------------------------------------- ONBOARDING: the welcome arms

func _sweep() -> void:
	var ac: Dictionary = wcfg.get("arms", {})
	arms_done += 1
	moves_used["arms"] = int(moves_used.get("arms", 0)) + 1
	_servo(3.0)
	var fwd: Vector3 = -global_basis.z
	BossFx.burst("motes", global_position + fwd * 2.0 + Vector3.UP * 1.2, get_tree(), 1.0, 1.4)
	for p: Player in alive_players():
		if Bordwart.in_arc(global_position, fwd, p.global_position, float(ac.get("reach", 7.0))):
			hit_player(p, float(ac.get("damage", 80)) * squad_damage_mult)
			AudioDirector.play_3d("boss_hit_glass", p.global_position + Vector3.UP, 2.0)
			var away: Vector3 = p.global_position - global_position
			away.y = 0.0
			p.external_push(away.normalized() * float(ac.get("push", 7.0)) + Vector3(0, 2.5, 0), 0.35, &"push")
	set_cd("arms", cd_for(float(ac.get("cooldown", 5.0))))


# ---------------------------------------------------------------- RENEWAL: the trial

func _offer_trial() -> void:
	if trial != null and is_instance_valid(trial):
		return
	var path: String = "res://gravelight/world/map04/trial_offer.gd"
	if not ResourceLoader.exists(path):
		return
	trial = (load(path) as GDScript).new() as Node3D
	trial.name = "TrialOffer"
	trial.set("manager", self)
	_map().add_child(trial)
	trial.global_position = station + _v3(wcfg.get("trial_offset", [-3.5, 0.0, 1.5]))


func _remove_trial() -> void:
	if trial != null and is_instance_valid(trial):
		for l: Node in trial.find_children("*", "Light3D", true, false):
			l.set_meta("no_dim", true)   # about to be freed: never one of the kit's captured lamps
		trial.queue_free()
	trial = null


## A player took the trial: every tonic, for `offer_seconds`; bots never do.
func accept_trial(pid: int) -> void:
	if GameState.is_bot(pid) or trial_takers.has(pid):
		return
	trial_takers.append(pid)
	PerkManager.grant_all(pid)
	Interactable.feedback_2d(_player_of(pid), "perk_buy" if AudioDirector.has_sound("perk_buy") else "buy", -2.0)
	if _trial_t < 0.0:
		_trial_t = float((wcfg.get("trial", {}) as Dictionary).get("offer_seconds", 60.0))


func _player_of(pid: int) -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			return p
	return null


## The trial has ended: every taker's perks are stripped, all of them.
func end_trial() -> void:
	_trial_t = -1.0
	if trial_takers.is_empty():
		return
	for pid: int in trial_takers:
		for perk: Variant in PerkManager.owned(pid).duplicate():
			PerkManager.remove(pid, StringName(perk))
		GLBus.perks_lost.emit(pid)
	trial_takers.clear()
	say(str((wcfg.get("trial", {}) as Dictionary).get("vo_end", "")))
	if trial != null and is_instance_valid(trial):
		trial.set("taken", [] as Array[int])


func _tick_trial(delta: float) -> void:
	if _trial_t > 0.0:
		_trial_t -= delta
		if _trial_t <= 0.0:
			end_trial()
	if _reinholt_t > 0.0:
		_reinholt_t -= delta
		if _reinholt_t <= 0.0:
			_reinholt_t = -1.0
			say(str((wcfg.get("trial", {}) as Dictionary).get("reinholt_vo", "")))


# ---------------------------------------------------------------- COLLECTIONS: the stamp, the crew, the cells

func _pick_price_target(range_m: float) -> Player:
	var best: Player = null
	var best_d: float = INF
	for p: Player in alive_players():
		var d: float = dist_to(p)
		if d <= range_m and d < best_d and has_los(p):
			best_d = d
			best = p
	return best


## One stamp on one player: the damage, the cut, the mark.
func _price(p: Player, damage: float, fraction: float) -> void:
	hit_player(p, damage * squad_damage_mult)
	var cut: int = price_cut(Economy.get_scrip(p.player_id), fraction)
	if cut > 0:
		Economy.grant(p.player_id, -cut)
	AudioDirector.play_3d("manager_stamp", p.global_position + Vector3.UP, 2.0, 0.04)
	Effects.static_burst(p.global_position + Vector3.UP, 1.2)
	BossFx.burst("motes", p.global_position + Vector3.UP * 1.2, get_tree(), 0.8, 1.0)


func _stamp() -> void:
	var pc: Dictionary = wcfg.get("price", {})
	set_cd("price", cd_for(float(pc.get("cooldown", 8.0))))
	var p: Player = _price_target
	_price_target = null
	if p == null or not is_instance_valid(p) or not p.is_alive() or dist_to(p) > float(pc.get("range", 14.0)) + 2.0 or not has_los(p):
		return
	prices_done += 1
	moves_used["price"] = int(moves_used.get("price", 0)) + 1
	_price(p, float(pc.get("damage", 90)), float(pc.get("scrip_fraction", 0.1)))
	var vo: Array = pc.get("vo", [])
	if prices_done == 2 and vo.size() > 1:
		say(str(vo[1]))


## T-234: nobody stood in her light: the whole squad is priced at once, wherever they are.
func _stamp_all() -> void:
	var pc: Dictionary = wcfg.get("price", {})
	set_cd("price_all", cd_for(float(pc.get("all_cooldown", 20.0))))
	prices_all_done += 1
	moves_used["price_all"] = int(moves_used.get("price_all", 0)) + 1
	dark_t = 0.0
	AudioDirector.play_3d("manager_stamp", global_position + Vector3.UP * 1.5, 6.0, 0.02)
	BossFx.burst("motes", global_position + Vector3.UP * 2.0, get_tree(), 2.5, 2.0)
	for p: Player in alive_players():
		_price(p, float(pc.get("all_damage", 60)), float(pc.get("all_scrip_fraction", 0.05)))
	if _field_hum != null:
		_field_hum.stop()
		_field_hum.volume_db = float(rcfg().get("field_hum_db", -10.0))
	if _spot != null:
		var tw: Tween = create_tween()
		tw.tween_property(_spot, "light_energy", 1.8, 1.0)
	fx.shake_all(global_position, 0.3, 30.0)


func _tick_collections(delta: float) -> void:
	_crew_t -= delta
	if _crew_t <= 0.0:
		var cc: Dictionary = wcfg.get("crew", {})
		_crew_t = float(cc.get("every", 25.0))
		_bring_crew(cc)
	var sc: Dictionary = wcfg.get("shields", {})
	for i: int in _slots.size():
		var slot: Dictionary = _slots[i]
		if bool(slot["lost"]):
			continue
		if float(slot["regen"]) > 0.0:
			slot["regen"] = float(slot["regen"]) - delta
			if float(slot["regen"]) <= 0.0:
				slot["regen"] = -1.0
				_spawn_cell(i, sc)
			continue
		var c: ShieldCell = slot["cell"] as ShieldCell if is_instance_valid(slot["cell"]) else null
		if c == null or not c.is_active():
			# shot to pieces (the body is recycled and freed by the director): she regrows it after regen_seconds
			cells_shot += 1
			slot["cell"] = null
			slot["regen"] = float(sc.get("regen_seconds", 40.0))


func _bring_crew(cc: Dictionary) -> void:
	var dir: ZombieDirector = director as ZombieDirector
	if dir == null:
		return
	var pad: Vector3 = _v3(wcfg.get("crew_pad", [37.0, 0.3, -37.5]))
	var made: int = 0
	for i: int in int(cc.get("count", 3)):
		var spec: Dictionary = dir._spec_for(&"ganger", RoundManager.take_extra_spawn())
		spec["variant"] = str(cc.get("kit", "soldier"))
		spec["tier"] = StringName(str(cc.get("tier", "jog")))
		var at: Vector3 = pad + Vector3(cos(TAU * float(i) / 3.0) * 1.2, 0, sin(TAU * float(i) / 3.0) * 1.2)
		if dir._activate_at(spec, dir._snap(at)) != null:
			made += 1
		else:
			RoundManager.alive = maxi(0, RoundManager.alive - 1)
	if made > 0:
		crews_done += 1
		Effects.static_burst(pad + Vector3.UP, 2.0)
		_servo(0.0)
		if crews_done == 1:
			say(str(cc.get("vo", "")))


func _spawn_cells() -> void:
	var sc: Dictionary = wcfg.get("shields", {})
	var n: int = int(sc.get("count", 3))
	_slots.clear()
	for i: int in n:
		_slots.append({"cell": null, "regen": -1.0, "lost": false})
		_spawn_cell(i, sc)


func _spawn_cell(i: int, sc: Dictionary) -> void:
	var dir: ZombieDirector = director as ZombieDirector
	if dir == null or escalated or i >= _slots.size():
		return
	var slot: Dictionary = _slots[i]
	var c: ShieldCell = slot["cell"] as ShieldCell if is_instance_valid(slot["cell"]) else null
	if c == null:
		c = ShieldCell.new()
		c.boss = self
		dir.add_extra(c)
		slot["cell"] = c
	c.orbit_phase = TAU * float(i) / float(maxi(1, int(sc.get("count", 3))))
	c.orbit_radius = float(sc.get("orbit_radius", 2.6))
	c.orbit_height = float(sc.get("orbit_height", 1.7))
	c.orbit_rpm = float(sc.get("orbit_rpm", 6.0))
	c.shaft_pos = _v3(wcfg.get("shaft", [28.0, 7.0, -30.0]))
	c.shaft_radius = float(wcfg.get("shaft_radius", 2.5))
	RoundManager.take_extra_spawn()
	c.spawn_cell(ShieldCell.orbit_pos(station, c.orbit_phase, 0.0, c.orbit_radius, c.orbit_height, c.orbit_rpm), float(sc.get("hp", 2000)))
	GLBus.enemy_spawned.emit(c.enemy_id, c.get_instance_id())


## A cell went into the shaft: gone for good (no regrowth), her line.
func on_cell_lost(c: ShieldCell) -> void:
	cells_lost += 1
	for slot: Dictionary in _slots:
		if slot["cell"] == c:
			slot["lost"] = true
			slot["regen"] = -1.0
	say(str((wcfg.get("shields", {}) as Dictionary).get("vo_lost", "")))


func live_cells() -> Array:
	var out: Array = []
	for slot: Dictionary in _slots:
		var c: ShieldCell = slot["cell"] as ShieldCell if is_instance_valid(slot["cell"]) else null
		if c != null and c.is_active() and not c.gone_for_good:
			out.append(c)
	return out


# ---------------------------------------------------------------- damage and the escalation

func take_damage(amount: float, limb: StringName, weapon_id: StringName, by_player: int, kind: StringName = &"bullet", armor_piercing: bool = false) -> bool:
	if escalated:
		return false
	var sc: Dictionary = wcfg.get("shields", {})
	var m: float = damage_mult(limb, presenting_now(), live_cells().size() if phase >= 3 else 0, float((wcfg.get("present", {}) as Dictionary).get("weak_mult", 2.5)), float(sc.get("shielded_mult", 0.2)))
	return super.take_damage(amount * m, limb, weapon_id, by_player, kind, armor_piercing)


func _tele_glow() -> float:
	return 4.0 if wstate in [W.ARMS_TELE, W.PRICE_TELE, W.PRICE_ALL_TELE] else (2.0 if presenting_now() else 0.0)


## No Cousins' hum and no breath (she is a machine): a servo adjusts now and then while she waits.
func _update_audio(delta: float) -> void:
	_idle_servo_t -= delta
	if _idle_servo_t <= 0.0 and wstate == W.IDLE:
		_idle_servo_t = randf_range(5.0, 9.0)
		_servo(-10.0)


## 0 %: she never dies. She folds, the voice steps away, the console unlocks.
func _boss_die(_limb: StringName, _weapon_id: StringName, _by_player: int, _kind: StringName) -> void:
	escalate()


func escalate() -> void:
	if escalated:
		return
	escalated = true
	hp = maxf(hp, 1.0)
	wstate = W.FOLDED
	bstate = B.SPECIAL
	presenting = 0.0
	_release_all_grabs("escalated")
	_tele_light.light_energy = 0.0
	for hb: Hitbox in _hitboxes:
		hb.collision_layer = 0
	_remove_trial()
	for slot: Dictionary in _slots:
		var c: ShieldCell = slot["cell"] as ShieldCell if is_instance_valid(slot["cell"]) else null
		if c != null and c.is_active():
			c.vanish_for_good()
	_pose.hold = true
	_tree_play("React", str(_anim["clips"]["react"]["stagger"]), 0.2)
	_set_plate(false)
	_servo(2.0)
	if _field_hum != null:
		_field_hum.stop()
	if _face_mat != null:
		_face_mat.emission_energy_multiplier = 0.5
	if _spot != null:
		var tw: Tween = create_tween()
		tw.tween_property(_spot, "light_energy", 0.6, 3.0)
	if fx != null:
		fx.lights_restore(4.0)
		fx.release_dread()
	collections_dark = false
	say(str(wcfg.get("escalate_vo", "")))
	var opr: String = str(wcfg.get("escalated_opr_vo", ""))
	if opr != "":
		get_tree().create_timer(4.5).timeout.connect(func() -> void: GLVO.play(StringName(opr)))
	var scrip: int = int(wcfg.get("escalate_scrip_per_player", 0))
	if scrip > 0:
		for pid: int in GameState.player_ids:
			Economy.grant(pid, scrip)
	for d: Variant in wcfg.get("drops", []):
		PowerupManager.spawn(StringName(str(d)), station + Vector3(0, 0.3, 3.0))
	if str(wcfg.get("flag", "")) != "":
		GameState.set_flag(StringName(str(wcfg["flag"])))
	GLBus.boss_spawned.emit(&"account_manager_escalated")
	RoundManager.release_alive(2)   # her reserve and her extra-spawn count: the round can end around her
	print("[m4d] the Account Manager escalated after %.0f s (arms %d, prices %d, squad prices %d, crews %d, cells shot %d / lost %d)" % [_spawn_t, arms_done, prices_done, prices_all_done, crews_done, cells_shot, cells_lost])


func _on_retreat() -> void:
	RoundManager.release_alive(2)
	if _field_hum != null:
		_field_hum.stop()


func _start_authored_death() -> void:
	_tree_play("Death", "death_knee", 1.0)


func is_active() -> bool:
	return super.is_active() and not escalated
