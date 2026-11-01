class_name TrappedPilot
extends Interactable
## GRAVELIGHT ONE's pilot, Flight Lieutenant Harry Selwyn (T-126; the owner: "have a pilot trapped in there that you
## can give a gun and he basically turns into a turret because he's stuck in the plane"). He sits pinned in the
## crushed cockpit, his legs caught under the instrument panel. From the cabin, hand him the gun in your hands (never
## your only gun, a wonder weapon, a launcher or a flamethrower: JakubCompanion.offer_rule) and he fights from his
## seat: he picks the nearest zombie he can see through the broken nose and the torn side, turns to it and fires the
## gun's own damage at a wounded man's rate, reloads from its reserve, and calls for ammo when it runs dry. Passing
## him ammo costs the ammo-box price for that gun (the payer's perks apply); handing him another gun gives you his
## back. His kills are scored to the player who armed him. Zombies never go for him: he is out of their reach in the
## nose, and he can't be hurt (data: pilot.json).
## The host runs him; arming, ammo and every shot's flash and tracer are mirrored to the peers.
## Local -Z is the way he faces (out of the nose); the origin is the cockpit floor under his seat.

const LIMB_AIM: Dictionary = {&"head": 1.62, &"torso": 1.2}

var cfgd: Dictionary = {}
var gun: WeaponInstance = null
var giver: int = 0
var body: PatronBody = null
var kills: int = 0
var shots: int = 0
var _gun_model: Node3D = null
var _muzzle: Node3D = null
var _target: Zombie = null
var _think_t: float = 0.0
var _cd: float = 0.0
var _reload_t: float = 0.0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _dry_said: bool = false
var _idle_line_t: float = 20.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _said_at: Dictionary = {}
var _last_line: String = ""
var lines_said: int = 0


static func load_cfg() -> Dictionary:
	return GLData.table("pilot")


## Why he can't take this gun ("" = he can): the rules Jakub uses, plus his own refusals (a launcher or a stream
## weapon can't be fired from a pinned seat). Pure.
static func gift_rule(slot_count: int, w_data: Dictionary, refused_classes: Array) -> String:
	var cls: String = str(w_data.get("class", ""))
	var refused: Array = refused_classes.duplicate()
	if w_data.has("projectile") or w_data.has("stream"):
		refused.append(cls)
	return JakubCompanion.offer_rule(slot_count, StringName(cls), false, refused)


## Shots a minute from his seat: the gun's rate times his own, capped (pure).
static func rate_for(rpm: float, mult: float, cap: float) -> float:
	return minf(maxf(1.0, rpm * mult), cap)


func _ready() -> void:
	cfgd = load_cfg()
	interact_size = Vector3(1.4, 1.6, 0.4)
	interact_offset = Vector3(0, 0.9, 1.2)   # the bulkhead doorway behind his seat, from the cabin
	super._ready()
	add_to_group(&"trapped_pilot")
	_rng.seed = 4101
	body = PatronBody.new()
	add_child(body)
	body.setup({"id": "selwyn", "pose": "sit", "look": cfgd.get("look", {})})
	body.aim_upper_only = true


func build_greybox() -> void:
	pass   # the cockpit is drawn by the map (gen_map00 _dress_wreck); he is his body


# ================================================================== the prompt

func get_prompt(player: Player) -> String:
	var key: String = prompt_key(&"interact")
	var w: WeaponInstance = player.weapons.current()
	if gun != null and not gun.is_full():
		return "Hold [%s] to pass Selwyn ammo for the %s [%s]" % [key, gun.display_name(), price_str(player, ammo_price(player))]
	if w == null:
		return "Flt Lt Selwyn, pinned in his seat" if gun == null else "Selwyn: %s" % gun.display_name()
	match gift_rule(player.weapons.slots.size(), w.data, cfgd.get("refused_classes", ["wonder"])):
		"only_gun":
			return "Selwyn won't take your only gun"
		"refused":
			return "Selwyn can't use the %s from his seat" % w.display_name()
		"":
			if gun == null:
				return "Hold [%s] to give Selwyn your %s" % [key, w.display_name()]
			return "Hold [%s] to give Selwyn your %s (take back the %s)" % [key, w.display_name(), gun.display_name()]
	return ""


func can_interact(player: Player) -> bool:
	if gun != null and not gun.is_full():
		return true
	var w: WeaponInstance = player.weapons.current()
	return w != null and gift_rule(player.weapons.slots.size(), w.data, cfgd.get("refused_classes", ["wonder"])) == ""


func hold_time(_player: Player) -> float:
	return float(cfgd.get("hold_s", 0.6))


func ammo_price(player: Player) -> int:
	if gun == null:
		return 0
	var p: float = float(AmmoBox.price_for(gun.data, gun.upgraded, AmmoBox.cfg()))
	p *= PerkManager.ammo_price_mult(player.player_id) * Muster.mult(player.player_id, "ammo_price_mult")
	return int(round(p))


func interact(player: Player) -> void:
	if gun != null and not gun.is_full():
		if try_purchase(player, &"pilot_ammo", ammo_price(player)):
			_refill()
			Net.mirror(self, &"_refill")
			_say("THANKS_AMMO")
		return
	var w: WeaponInstance = player.weapons.current()
	if w == null or gift_rule(player.weapons.slots.size(), w.data, cfgd.get("refused_classes", ["wonder"])) != "":
		return
	var old: WeaponInstance = gun
	player.weapons.remove_current()
	if old != null:
		player.weapons.give_instance(old)   # his gun comes back to you
	_arm(player.player_id, String(w.id), w.mag, w.reserve, w.tier, WeaponKit.encode(w.kit), String(w.finish))
	Net.mirror(self, &"_arm", [player.player_id, String(w.id), w.mag, w.reserve, w.tier, WeaponKit.encode(w.kit), String(w.finish)])
	_say("GIVEN" if old == null else "SWAP")
	GLBus.weapon_acquired.emit(player.player_id, w.id, &"pilot")


## He takes the gun (host, then every peer): the model goes into his hands, its ammo as it was handed over.
func _arm(by: int, weapon_id: String, mag: int, reserve: int, tier: int, kit: Array, finish: String) -> void:
	giver = by
	gun = WeaponInstance.create(StringName(weapon_id))
	gun.tier = tier
	gun.mag = mag
	gun.reserve = reserve
	if not kit.is_empty():
		gun.kit = WeaponKit.decode(kit, gun)
		gun.refresh_kit()
	gun.finish = StringName(finish)
	_dry_said = false
	_reload_t = 0.0
	if gun.mag <= 0 and gun.reserve > 0:
		_reload_t = _reload_seconds()
	_build_gun_model()


func _refill() -> void:
	if gun == null:
		return
	gun.refill()
	_dry_said = false
	_reload_t = 0.0


func _build_gun_model() -> void:
	if _gun_model != null and is_instance_valid(_gun_model):
		_gun_model.queue_free()
	_gun_model = null
	_muzzle = null
	if gun == null or body == null:
		return
	_gun_model = WeaponModels.build(gun.base_id(), gun.upgraded, gun.finish, {})
	body.hold_gun(_gun_model)
	_muzzle = _gun_model.get_node_or_null("Muzzle") as Node3D


# ================================================================== the turret

func _process(delta: float) -> void:
	if body != null:
		body.aim_weight = move_toward(body.aim_weight, 1.0 if gun != null else 0.0, delta * 3.0)
	if gun == null:
		_idle_line(delta)
		return
	var want_yaw: float = 0.0
	var want_pitch: float = 0.0
	if _target != null and is_instance_valid(_target) and _target.is_active():
		var lp: Vector3 = to_local(_aim_point(_target))
		var eye: Vector3 = _eye_local()
		var d: Vector3 = lp - eye
		want_yaw = clampf(atan2(-d.x, -d.z), -deg_to_rad(float(cfgd.get("max_yaw_deg", 100.0))), deg_to_rad(float(cfgd.get("max_yaw_deg", 100.0))))
		want_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.9, 0.7)
	var turn: float = float(cfgd.get("turn_rad_s", 3.0)) * delta
	_yaw = move_toward(_yaw, want_yaw, turn)
	_pitch = move_toward(_pitch, want_pitch, turn)
	if body != null:
		body.aim_yaw = _yaw
		body.aim_pitch = _pitch
	if not Net.is_authority():
		return
	_cd -= delta
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			var take: int = mini(gun.mag_size() - gun.mag, gun.reserve)
			gun.mag += take
			gun.reserve -= take
		return
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = float(cfgd.get("think_s", 0.2))
		_target = _pick_target()
	if gun.mag <= 0:
		if gun.reserve > 0:
			_reload_t = _reload_seconds()
			AudioDirector.play_3d("reload_mag_out", global_position + Vector3.UP, -6.0)
		elif not _dry_said:
			_dry_said = true
			_say("DRY")
		return
	if _target == null or _cd > 0.0:
		return
	if absf(angle_difference(_yaw, want_yaw)) > deg_to_rad(float(cfgd.get("fire_cone_deg", 7.0))):
		return
	_fire()


func _reload_seconds() -> float:
	return gun.f("reload_partial", 2.5) * float(cfgd.get("reload_mult", 1.4))


func _eye_local() -> Vector3:
	return Vector3(0, float(cfgd.get("eye_y", 1.25)), 0)


func _aim_point(z: Zombie) -> Vector3:
	if z.is_crawler:
		return z.global_position + Vector3.UP * 0.45
	return z.global_position + Vector3.UP * float(LIMB_AIM[&"torso"])


## The nearest zombie in range he can see from his seat (a clear line through the nose or the torn side).
func _pick_target() -> Zombie:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return null
	var eye: Vector3 = to_global(_eye_local())
	var rng_m: float = float(cfgd.get("range_m", 32.0))
	var max_yaw: float = deg_to_rad(float(cfgd.get("max_yaw_deg", 100.0)))
	var best: Zombie = null
	var best_d: float = rng_m * rng_m
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for z: Zombie in dir.active_zombies():
		var p: Vector3 = _aim_point(z)
		var d2: float = eye.distance_squared_to(p)
		if d2 >= best_d:
			continue
		var lp: Vector3 = to_local(p) - _eye_local()
		if absf(atan2(-lp.x, -lp.z)) > max_yaw:
			continue
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, p, 1)
		if not space.intersect_ray(q).is_empty():
			continue   # the hull, a wall, the wing: he can't see it
		best = z
		best_d = d2
	return best


func _fire() -> void:
	var rpm: float = rate_for(gun.f("rpm", 300.0), float(cfgd.get("rate_mult", 0.7)), float(cfgd.get("rate_cap", 550.0)))
	_cd = 60.0 / rpm
	gun.mag -= 1
	shots += 1
	var from: Vector3 = to_global(_eye_local())   # his line of sight: the muzzle model can sit under the sill
	var fx_from: Vector3 = _muzzle.global_position if _muzzle != null else from
	var aim: Vector3 = _aim_point(_target)
	if _rng.randf() < float(cfgd.get("head_chance", 0.25)) and not _target.is_crawler:
		aim = _target.global_position + Vector3.UP * float(LIMB_AIM[&"head"])
	var base_dir: Vector3 = (aim - from).normalized()
	var spread: float = deg_to_rad(gun.f("spread_ads", 0.5) * float(cfgd.get("spread_mult", 1.5)) + float(cfgd.get("spread_add_deg", 0.8)))
	var pellets: int = maxi(1, int(gun.data.get("pellets", 1)))
	var hits: Dictionary = {}
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var end_fx: Vector3 = from + base_dir * 60.0
	for i: int in pellets:
		var b: Basis = Basis.looking_at(base_dir)
		var dir: Vector3 = (b * Vector3(_rng.randfn(0.0, spread * 0.5), _rng.randfn(0.0, spread * 0.5), -1.0)).normalized()
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * float(cfgd.get("range_m", 32.0)) * 1.5,
			WeaponHolder.MASK_SHOT & ~DecorHit.LAYER)
		q.collide_with_areas = true
		var res: Dictionary = space.intersect_ray(q)
		if res.is_empty():
			continue
		var pos: Vector3 = res["position"]
		end_fx = pos
		var col: Object = res["collider"]
		if col is Hitbox:
			var hb: Hitbox = col
			var z: Zombie = hb.enemy as Zombie
			if z == null or not z.is_active():
				continue
			var wl: StringName = z.marke_host_limb() if hb.limb == &"marke" else hb.limb   # T-137
			var dmg: float = gun.f("damage", 50.0) * gun.falloff(from.distance_to(pos)) * gun.limb_mult(wl)
			var cur: Dictionary = hits.get(z, {"dmg": 0.0, "limb": "torso", "bone": ""})
			cur["dmg"] = float(cur["dmg"]) + dmg
			if wl == &"head" or str(cur["limb"]) != "head":
				cur["limb"] = String(hb.limb)
				cur["bone"] = hb.bone
			hits[z] = cur
		elif i == 0:
			Effects.impact(pos, res["normal"], "", col)
	for z2: Variant in hits.keys():
		var zz: Zombie = z2 as Zombie
		var h: Dictionary = hits[z2]
		zz.last_hit_bone = str(h["bone"])
		if zz.take_damage(float(h["dmg"]), StringName(str(h["limb"])), gun.id, giver, &"bullet"):
			kills += 1
			if kills % int(cfgd.get("kill_line_every", 6)) == 1:
				_say("KILL")
	_shot_fx(fx_from, end_fx)
	Net.mirror(self, &"_shot_fx", [fx_from, end_fx])
	if gun.mag <= 0 and gun.reserve > 0:
		_reload_t = _reload_seconds()


## A shot's flash, tracer and report (every peer).
func _shot_fx(from: Vector3, to: Vector3) -> void:
	if gun == null:
		return
	var dir: Vector3 = (to - from).normalized()
	Effects.muzzle_flash(from, dir, gun.id, gun.upgraded, 1.0, true)
	Effects.tracer(from, to, gun.upgraded, gun.weapon_class())
	AudioDirector.play_3d(fire_key(gun), from, 0.0, 0.05)
	if body != null:
		body.kick()


static func fire_key(w: WeaponInstance) -> String:
	var own: String = "fire_" + String(w.base_id())
	return own if AudioDirector.has_sound(own) else str(WeaponHolder.SOUND.get(w.weapon_class(), "gun_rifle"))


# ================================================================== his voice

func _idle_line(delta: float) -> void:
	_idle_line_t -= delta
	if _idle_line_t > 0.0:
		return
	_idle_line_t = float(cfgd.get("call_every_s", 50.0))
	for p: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = p as Player
		if pl != null and not pl.spectating and pl.global_position.distance_to(global_position) < float(cfgd.get("call_within_m", 14.0)):
			_say("CALL")
			return


## A line of his (lines.json speaker SEL), at most one per category per cooldown (pilot.json line_cooldown_s), not
## twice in a row; picked on the host and said on every peer.
func _say(category: String) -> void:
	if not Net.is_authority():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var cds: Dictionary = cfgd.get("line_cooldown_s", {})
	if now < float(_said_at.get(category, -INF)) + float(cds.get(category, 8.0)):
		return
	var pool: Array = []
	for id: String in GLVO.lines.keys():
		var rec: Dictionary = GLVO.lines[id]
		if str(rec.get("speaker", "")) == "SEL" and str(rec.get("category", "")) == category and id != _last_line:
			pool.append(id)
	if pool.is_empty():
		return
	_said_at[category] = now
	var line: String = str(pool[_rng.randi_range(0, pool.size() - 1)])
	_say_line(line)
	Net.mirror(self, &"_say_line", [line])


## The subtitle under his name, and the baked voice from the cockpit when there is one.
func _say_line(line_id: String) -> void:
	var rec: Dictionary = GLVO.lines.get(line_id, {})
	if rec.is_empty():
		return
	_last_line = line_id
	var text: String = GLVO.strip_tags(str(rec.get("text", "")))
	var dur: float = GLVO.duration_for(text, GLVO.rules)
	var path: String = GLVO.audio_path(StringName(line_id))
	if path != "":
		var stream: AudioStream = GLVO.load_stream(path)
		if stream != null:
			var ap: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			ap.bus = &"VO"
			ap.stream = stream
			ap.unit_size = 6.0
			ap.max_distance = 45.0
			ap.position = _eye_local()
			add_child(ap)
			ap.play()
			ap.finished.connect(ap.queue_free)
			dur = maxf(dur, stream.get_length())
	lines_said += 1
	GLBus.vo_line_started.emit(StringName(line_id), StringName(str(cfgd.get("display", "SELWYN"))), text, dur)
