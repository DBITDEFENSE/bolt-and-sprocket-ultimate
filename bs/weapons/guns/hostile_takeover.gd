extends BSWeapon
## HOSTILE TAKEOVER (BS_WEAPONS §9.3, new). Hold the acquisition beam (18 m, dot 0.9, 4 dps) on a non-boss enemy for
## 0.6 s + 0.01 s per point of its max HP (elites x1.5, heavies x2): it becomes an allied SUBSIDIARY for 10 s
## (status "acquired", meta "bs_subsidiary", a gold tie). Max 2. 1.0 s after each acquisition. Ammo 6 contracts (+2).
## A subsidiary leaves the "enemies" group (our guns ignore it) and joins "subsidiaries" + "enemy_decoys": it keeps
## its own attacks, aimed at the nearest enemy (EnemyBase.target), and enemies within 15 m target it.
## On contract end it is an enemy again at its current HP, stunned 1 s ("restructuring").
## Refusals: bosses ("ACQUISITION BLOCKED — ANTITRUST."), Picket Corn, statues.
## Alt-fire MERGER: aim at one subsidiary while another is within 8 m: they fuse (HP x1.25 combined, damage x1.5,
## size x1.3, contract reset). 1 contract; a merged unit can't merge again.
## Hostile Work Environment: a SERVED subsidiary (Cease & Desist) deals +40% and gains +4 s (served_subsidiary()).
## V3: subsidiaries +20% max HP and a bigger tie. V5: acquisition time -30%, 12 s contracts.
## Ω GOLDEN PARACHUTE: when a contract ends the unit explodes into bolts: 50 at r4 to enemies, plus its normal drop.
## Signatures: hostile_bid (half acquisition time, 6 s contracts), non_compete (enemies that hurt subsidiaries are
## SERVED).

var subs: Array[Dictionary] = []          # {e, t, merged, served, tie}
var beam_target: Node3D = null
var progress: float = 0.0
var beam_on: bool = false
var _dmg_acc: float = 0.0
var _refused: bool = false
var _retarget_t: float = 0.0


func _can_auto_fire() -> bool:
	return false


func contract() -> float:
	if sig() == &"hostile_bid":
		return P("contract_bid", 6.0)
	return P("contract_v5", 12.0) if level() >= 5 else P("contract", 10.0)


func acq_time(e: Node) -> float:
	var hpm: float = float(e.get("max_hp")) if "max_hp" in e else 30.0
	var t: float = P("acq_base", 0.6) + P("acq_per_hp", 0.01) * hpm
	if WeaponData.prop_bool(e, "elite"):
		t *= P("acq_elite", 1.5)
	if WeaponData.prop_bool(e, "heavy"):
		t *= P("acq_heavy", 2.0)
	if level() >= 5:
		t *= P("acq_v5", 0.7)
	if sig() == &"hostile_bid":
		t *= P("bid_mul", 0.5)
	return t


func refusal(e: Node) -> String:
	if e.is_in_group(&"bosses"):
		return "bs.weapon.hostile.refuse.02"
	if e.is_in_group(&"picket_corn") or ("id" in e and str(e.get("id")).contains("corn")):
		return "bs.weapon.hostile.refuse.01"
	if e.is_in_group(&"statues") or WeaponData.prop_bool(e, "statue"):
		return "bs.weapon.hostile.refuse.03"
	return ""


func _tick(dt: float, is_equipped: bool) -> void:
	_update_subs(dt)
	beam_on = false
	if not is_equipped or not fire_held or cooldown > 0.0:
		progress = maxf(0.0, progress - P("acq_decay", 1.0) * dt)
		if not fire_held:
			_refused = false
		return
	if not has_ammo(1):
		empty_feedback()
		return
	var e: Node3D = aimed_enemy(P("range", 18.0), P("dot", 0.9))
	beam_on = true
	var from: Vector3 = mgr.muzzle_pos()
	var end: Vector3 = center_of(e) if e != null else from + aim() * P("range", 18.0)
	WeaponFX.tracer(mgr.world(), from, end, WeaponData.color(id), 0.06 * tier_mul(), dt * 1.5)
	if e == null:
		progress = maxf(0.0, progress - P("acq_decay", 1.0) * dt)
		return
	var no: String = refusal(e)
	if no != "":
		if not _refused:
			_refused = true
			WeaponText.say(no)
			popup.emit(no, center_of(e))
		return
	if e != beam_target:
		beam_target = e
		progress = 0.0
		_dmg_acc = 0.0
	_dmg_acc += dmg(P("dps", float(d.get("damage", 4)))) * dt
	if _dmg_acc >= 1.0:
		var whole: float = floorf(_dmg_acc)
		_dmg_acc -= whole
		deal(e, whole, end, end - from)
	if not alive(e):
		return
	progress += dt
	if progress >= acq_time(e):
		acquire(e)


func acquire(e: Node3D) -> bool:
	progress = 0.0
	beam_target = null
	_prune()
	if subs.size() >= int(P("max_subs", 2)):
		WeaponText.hint("bs.weapon.hint.hostile_full", "hostilefull")
		return false
	if refusal(e) != "" or not use_ammo(1):
		return false
	cooldown = interval()
	e.set_meta(&"bs_subsidiary", true)
	e.remove_from_group(&"enemies")
	e.add_to_group(&"subsidiaries")
	e.add_to_group(&"enemy_decoys")
	e.add_to_group(&"player_allies")
	mgr.apply_status(e, &"acquired", contract())
	if level() >= 3 and "max_hp" in e:
		e.set("max_hp", float(e.get("max_hp")) * P("v3_hp", 1.2))
		e.set("hp", float(e.get("hp")) * P("v3_hp", 1.2))
	if "aggro" in e:
		e.set("aggro", true)
	var tie: MeshInstance3D = WeaponFX.block(e, Vector3(0.12, 0.4, 0.05) * (1.8 if level() >= 3 else 1.0), Vector3(0, 0.9, -0.45), Color("#ffd23e"))
	tie.name = "GoldTie"
	subs.append({"e": e, "t": contract(), "merged": false, "served": false, "tie": tie})
	_retarget_t = 0.0
	popup.emit("bs.weapon.fx.acquired", center_of(e))
	WeaponFX.ring(mgr.world(), e.global_position + Vector3.UP * 0.1, 1.2, WeaponData.color(id), 0.4)
	fired.emit(id)
	mgr.weapon_fired.emit(id)
	return true


func sub_of(e: Node) -> Dictionary:
	for s: Dictionary in subs:
		if s["e"] == e:
			return s
	return {}


func _prune() -> void:
	for s: Dictionary in subs.duplicate():
		var e: Variant = s["e"]
		if not is_instance_valid(e) or not alive(e as Node):
			_cleanup(s)
			subs.erase(s)


func _update_subs(dt: float) -> void:
	_prune()
	for s: Dictionary in subs.duplicate():
		s["t"] = float(s["t"]) - dt
		var e: Node3D = s["e"]
		mgr.apply_status(e, &"acquired", maxf(0.05, float(s["t"])))
		if float(s["t"]) <= 0.0:
			release(s)
	_retarget_t -= dt
	if _retarget_t > 0.0 or subs.is_empty():
		return
	_retarget_t = P("retarget", 0.5)
	for s2: Dictionary in subs:
		var sub: Node3D = s2["e"]
		if "target" in sub:
			var foe: Node3D = nearest_enemy(center_of(sub), P("hunt_range", 30.0))
			sub.set("target", foe)
		for o: Node3D in Combat.in_radius(get_tree(), center_of(sub), P("aggro_radius", 15.0)):
			if not o.is_in_group(&"bosses") and "target" in o:
				o.set("target", sub)


## Contract over: restructuring (or, at Ω, a golden parachute).
func release(s: Dictionary) -> void:
	var e: Node3D = s["e"]
	_cleanup(s)
	subs.erase(s)
	if not alive(e):
		return
	var c: Vector3 = center_of(e)
	if omega():
		popup.emit("bs.weapon.fx.parachute", c)
		var hp_now: float = float(e.get("hp")) if "hp" in e else 9999.0
		mgr.deal_damage(e, make_hit(hp_now + 9999.0, c))
		explode(c, P("omega_r", 4.0), dmg(P("omega_blast", 50.0)))
		return
	mgr.apply_status(e, &"stun", P("release_stun", 1.0))
	if "target" in e:
		e.set("target", mgr.bolt)
	popup.emit("bs.weapon.fx.restructuring", c)


func _cleanup(s: Dictionary) -> void:
	var e: Variant = s["e"]
	if not is_instance_valid(e):
		return
	var n: Node = e as Node
	if n.has_meta(&"bs_subsidiary"):
		n.remove_meta(&"bs_subsidiary")
	n.remove_from_group(&"subsidiaries")
	n.remove_from_group(&"enemy_decoys")
	n.remove_from_group(&"player_allies")
	n.add_to_group(&"enemies")
	var st: StatusEffects = mgr.status_node(n)
	if st != null:
		st.clear(&"acquired")
	var tie: Variant = s.get("tie")
	if tie != null and is_instance_valid(tie):
		(tie as Node).queue_free()
	if bool(s.get("served", false)) and "dmg_mult" in n:
		n.set("dmg_mult", float(n.get("dmg_mult")) / P("served_dmg", 1.4))


## Hostile Work Environment (called by Cease & Desist): +4 s and +40% damage, once.
func served_subsidiary(e: Node, bonus: float, mul: float) -> void:
	var s: Dictionary = sub_of(e)
	if s.is_empty():
		return
	s["t"] = float(s["t"]) + bonus
	if not bool(s["served"]):
		s["served"] = true
		if "dmg_mult" in e:
			e.set("dmg_mult", float(e.get("dmg_mult")) * mul)


## Non-Compete Clause: whoever hurts a subsidiary gets SERVED.
func on_any_hit(enemy: Node, hit: Combat.Hit, _killed: bool) -> void:
	if sig() != &"non_compete" or not enemy.has_meta(&"bs_subsidiary"):
		return
	var src: Node = hit.source
	if src != null and is_instance_valid(src) and src.is_in_group(&"enemies") and src.has_node("Status"):
		mgr.apply_status(src, &"served", P("non_compete_served", 6.0))


# ---- MERGER

func _on_alt_pressed() -> void:
	_prune()
	var a: Dictionary = _aimed_sub()
	if a.is_empty() or bool(a["merged"]):
		WeaponText.hint("bs.weapon.hint.merger", "merger")
		return
	var ea: Node3D = a["e"]
	var b: Dictionary = {}
	for s: Dictionary in subs:
		if s != a and not bool(s["merged"]) and (s["e"] as Node3D).global_position.distance_to(ea.global_position) < P("merge_range", 8.0):
			b = s
			break
	if b.is_empty():
		WeaponText.hint("bs.weapon.hint.merger", "merger")
		return
	if not use_ammo(1):
		return
	var eb: Node3D = b["e"]
	if "max_hp" in ea and "max_hp" in eb:
		ea.set("max_hp", (float(ea.get("max_hp")) + float(eb.get("max_hp"))) * P("merge_hp", 1.25))
		ea.set("hp", (float(ea.get("hp")) + float(eb.get("hp"))) * P("merge_hp", 1.25))
	if "dmg_mult" in ea:
		ea.set("dmg_mult", float(ea.get("dmg_mult")) * P("merge_dmg", 1.5))
	var vis: Node3D = ea.get("visual") as Node3D if "visual" in ea else null
	if vis != null:
		vis.scale *= P("merge_scale", 1.3)
	if "radius" in ea:
		ea.set("radius", float(ea.get("radius")) * P("merge_scale", 1.3))
	a["t"] = contract()
	a["merged"] = true
	_cleanup(b)
	subs.erase(b)
	WeaponFX.lightning(mgr.world(), center_of(eb), center_of(ea), WeaponData.color(id), mgr.rng)
	if eb.has_method("despawn"):
		eb.call("despawn")
	else:
		eb.queue_free()
	popup.emit("bs.weapon.fx.merger", center_of(ea))
	fired.emit(id)


func _aimed_sub() -> Dictionary:
	var best: Dictionary = {}
	var bd: float = P("dot", 0.9)
	for s: Dictionary in subs:
		var e: Node3D = s["e"]
		var to: Vector3 = center_of(e) - origin()
		if to.length() > P("range", 18.0) * 1.5:
			continue
		var dt: float = to.normalized().dot(aim())
		if dt > bd:
			bd = dt
			best = s
	return best


func _on_holster() -> void:
	progress = 0.0
	beam_target = null


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["acquire"] = clampf(progress / acq_time(beam_target), 0.0, 1.0) if beam_target != null and alive(beam_target) else 0.0
	s["subs"] = subs.size()
	s["subs_max"] = int(P("max_subs", 2))
	s["beam"] = beam_on
	return s
