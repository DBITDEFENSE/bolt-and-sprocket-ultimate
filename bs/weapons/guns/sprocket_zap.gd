extends ChainWeapon
## SPROCKET ZAP (BS_WEAPONS §8.3). fireZap (index.html:4783): Sprocket arcs to a first target within 11 m roughly in
## front, then hops to the nearest unhit enemy within 6.5 m; 18 / 14 / 11 (then 10 / 9) down the chain; the last
## target leaves an electric residue (r1.4, 1.6 s, 4 every 0.4 s). Fizzles with no ammo cost if nothing is in range.
## V1 3 targets; V3 4 targets + a third strand + every hit CONDUCTIVE 4 s + residue r2.0; V5 5 targets.
## Ω FULL CHARGE: 5 targets, residue r2.8 for 2.2 s, chain damage never below 11.
## CONDUCTIVE targets are reached +3 m further and take x1.25; FROZEN targets take x2 (double-conductive).
## Alt-fire AMPLIFY (hold): Sprocket hovers in place as a pylon: +1 target, hop 9 m, damage x1.3, ammo drain x1.5.
## Releasing, or Bolt moving > 12 m from the pylon, ends it. Signatures: surge_protector (residue 4 s, stacks),
## long_distance (first range 18 m, one fewer target).
## Sprocket hook: the node in group "sprocket" is the arc origin; if it has set_pylon(on: bool, pos: Vector3) it is
## told when Amplify starts/ends, and zap_fired() when an arc goes out (he points, fires, recoils).

var amplify: bool = false
var pylon_pos: Vector3 = Vector3.ZERO
var amp_t: float = 0.0
var _amp_nagged: bool = false
var _amp_bragged: bool = false


func sprocket() -> Node3D:
	return get_tree().get_first_node_in_group(&"sprocket") as Node3D


func arc_origin() -> Vector3:
	if amplify:
		return pylon_pos
	var s: Node3D = sprocket()
	if s != null:
		return s.global_position
	var b: Bolt = mgr.bolt
	var right: Vector3 = Vector3(cos(b.motor.yaw), 0, -sin(b.motor.yaw)) if b.motor != null else Vector3.RIGHT
	return b.global_position + Vector3(0, 1.1, 0) - right * 0.6


func target_count() -> int:
	var n: int = int(P("targets", 3))
	if omega():
		n = int(P("targets_omega", 5))
	elif level() >= 5:
		n = int(P("targets_v5", 5))
	elif level() >= 3:
		n = int(P("targets_v3", 4))
	if sig() == &"long_distance":
		n -= 1
	if amplify:
		n += int(P("amp_targets", 1))
	return maxi(1, n)


func hop_reach(e: Node3D, base: float) -> float:
	return base + (P("conductive_reach", 3.0) if mgr.has_status(e, &"conductive") else 0.0)


func strands() -> int:
	return int(P("strands", 2)) + (1 if level() >= 3 else 0)


func chain_damage(i: int) -> float:
	var v: float = super.chain_damage(i)
	return maxf(v, P("omega_min_dmg", 11.0)) if omega() else v


func _fire() -> void:
	cooldown = interval()
	if not has_ammo(1):
		empty_feedback()
		return
	var first_r: float = P("long_first_range", 18.0) if sig() == &"long_distance" else P("first_range", 11.0)
	var hop: float = P("amp_hop", 9.0) if amplify else P("hop_range", 6.5)
	var targets: Array[Node3D] = find_chain(arc_origin(), aim(), target_count(), first_r, hop)
	if targets.is_empty():
		fizzle()
		return
	if amplify:
		drain_ammo(P("amp_drain", 1.5))
	else:
		use_ammo(1)
	zap(targets, P("amp_mul", 1.3) if amplify else 1.0)
	_leave_residue(targets[targets.size() - 1])
	var s: Node3D = sprocket()
	if s != null and s.has_method("zap_fired"):
		s.call("zap_fired")
	if amplify and targets.size() >= 3 and not _amp_bragged:
		_amp_bragged = true
		WeaponText.say("bs.weapon.zap.amp.04")
	recoil(float(d.get("recoil", 0.006)))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func on_arc_hit(e: Node3D, i: int, amount: float, point: Vector3) -> void:
	var mul: float = 1.0
	if mgr.has_status(e, &"frozen"):
		mul = P("frozen_mul", 2.0)
	elif mgr.has_status(e, &"conductive"):
		mul = P("conductive_mul", 1.25)
	var st: Dictionary = {"conductive": P("conductive_time", 4.0)} if level() >= 3 else {}
	deal(e, roundf(amount * mul), point, Vector3.ZERO, st)


func _leave_residue(last: Node3D) -> void:
	var r: float = P("residue_r", 1.4)
	var t: float = P("residue_time", 1.6)
	if omega():
		r = P("residue_r_omega", 2.8)
		t = P("residue_time_omega", 2.2)
	elif level() >= 3:
		r = P("residue_r_v3", 2.0)
	var surge: bool = sig() == &"surge_protector"
	if surge:
		t = P("surge_residue_time", 4.0)
	var z: ZapResidue = ZapResidue.new()
	z.weapon = self
	z.radius = r
	z.life = t
	z.tick = P("residue_tick", 0.4)
	z.amount = roundf(dmg(P("residue_dmg", 4.0)))
	z.stacks = surge
	mgr.world().add_child(z)
	z.global_position = Vector3(last.global_position.x, last.global_position.y + 0.05, last.global_position.z)


# ---- AMPLIFY

func _on_alt_pressed() -> void:
	if amplify:
		return
	amplify = true
	pylon_pos = arc_origin()
	amp_t = 0.0
	_amp_nagged = false
	_amp_bragged = false
	var s: Node3D = sprocket()
	if s != null and s.has_method("set_pylon"):
		s.call("set_pylon", true, pylon_pos)
	WeaponText.say("bs.weapon.zap.amp.01")


func _alt_held(dt: float) -> void:
	if not amplify:
		return
	amp_t += dt
	if amp_t >= P("amp_nag_after", 3.0) and not _amp_nagged:
		_amp_nagged = true
		WeaponText.say("bs.weapon.zap.amp.02" if mgr.rng.randf() < 0.5 else "bs.weapon.zap.amp.03")
	if mgr.bolt.global_position.distance_to(pylon_pos) > P("amp_leash", 12.0):
		end_amplify()


func _on_alt_released() -> void:
	end_amplify()


func _on_cancel() -> void:
	end_amplify()


func end_amplify() -> void:
	if not amplify:
		return
	amplify = false
	var s: Node3D = sprocket()
	if s != null and s.has_method("set_pylon"):
		s.call("set_pylon", false, pylon_pos)
	WeaponText.say("bs.weapon.zap.amp.05")


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["amplify"] = amplify
	return s
