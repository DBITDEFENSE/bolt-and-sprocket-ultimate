extends LobbedWeapon
## GRAV GRENADE (BS_WEAPONS §8.9). fireGrav (index.html:5635): lobbed at 15 m/s + 5 up (gravity 16, life 2), 0 direct
## damage. spawnSingularity / updateSingularities (5648-5687): a micro-singularity for 3 s, r6.5, that drags non-heavy,
## non-boss enemies to the centre (min(d, 7) x 1.6 m/s), keeps them GRAVITY-CLUMPED (0.4 s), vacuums bolt pickups
## within 8 m, then collapses and launches everything at 11 m/s. Ammo 5 (+2 per tier).
## Alt-fire HOLD: keep the newest singularity open while held; each extra 2 s costs 1 ammo, up to +4 s; it collapses
## on release. Black Hole Sun: a Void Rift overlapping the singularity doubles crush damage.
## V3: 5 s, crush 6 every 0.5 s from 1 s after opening. V5: the collapse deals 20 to everything launched; bolt pull
## 12 m. Ω EVENT HORIZON: 6.5 s, crush from the moment it opens, heavies (not bosses) inside are SLOWED.
## Signatures: tidy_up (r9, no crush), compactor (r4.5, crush x2).

var last_sing: GravSingularity = null
var hold_spent: float = 0.0
var hold_acc: float = 0.0


func radius() -> float:
	match sig():
		&"tidy_up": return P("tidy_radius", 9.0)
		&"compactor": return P("compact_radius", 4.5)
	return P("radius", 6.5)


func duration() -> float:
	if omega():
		return P("duration_omega", 6.5)
	return P("duration_v3", 5.0) if level() >= 3 else P("duration", 3.0)


func on_land(pos: Vector3, _direct: Node3D, _data: Dictionary) -> void:
	var s: GravSingularity = GravSingularity.new()
	s.weapon = self
	s.life = duration()
	s.radius = radius()
	s.pull_k = P("pull_k", 1.6)
	s.pull_cap = P("pull_cap", 7.0)
	s.clump_time = P("clump_time", 0.4)
	s.crush = (level() >= 3 or omega()) and sig() != &"tidy_up"
	s.crush_amount = dmg(P("crush_dmg", 6.0)) * (P("compact_crush_mul", 2.0) if sig() == &"compactor" else 1.0)
	s.crush_tick = P("crush_tick", 0.5)
	s.crush_from = 0.0 if omega() else P("crush_delay", 1.0)
	s.rift_mul = P("rift_crush_mul", 2.0)
	s.launch = P("collapse_launch", 11.0)
	s.collapse_amount = dmg(P("collapse_dmg_v5", 20.0)) if level() >= 5 else 0.0
	s.bolt_r = P("bolt_pull_v5", 12.0) if level() >= 5 else P("bolt_pull", 8.0)
	s.bolt_rate = P("bolt_pull_rate", 2.0)
	s.slow_heavies = omega()
	s.slow_time = P("omega_slow", 0.5)
	mgr.world().add_child(s)
	s.global_position = pos + Vector3.UP * 0.6
	last_sing = s
	hold_spent = 0.0
	hold_acc = 0.0
	shake(0.2)


## HOLD: the newest singularity stays open while alt is held (1 ammo per extra 2 s, up to +4 s).
func _on_alt_pressed() -> void:
	if last_sing == null or not is_instance_valid(last_sing) or last_sing.collapsed:
		return
	last_sing.held = true
	hold_acc = P("hold_step", 2.0)        # the first 2 s block is charged on the first frame held
	popup.emit("bs.weapon.fx.hold", last_sing.global_position)


func _alt_held(dt: float) -> void:
	if last_sing == null or not is_instance_valid(last_sing) or not last_sing.held:
		return
	if hold_spent >= P("hold_max", 4.0):
		last_sing.held = false
		return
	hold_acc += dt
	if hold_acc >= P("hold_step", 2.0):
		hold_acc -= P("hold_step", 2.0)
		if not use_ammo(1):
			_release_hold()
			return
	hold_spent += dt


func _on_alt_released() -> void:
	_release_hold()


func _release_hold() -> void:
	if last_sing != null and is_instance_valid(last_sing) and last_sing.held:
		last_sing.held = false
		last_sing.collapse()


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	if last_sing != null and is_instance_valid(last_sing) and not last_sing.collapsed:
		s["sing_left"] = last_sing.life
		s["holding"] = last_sing.held
	return s
