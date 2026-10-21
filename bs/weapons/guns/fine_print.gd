extends HitscanWeapon
## THE FINE PRINT (BS_WEAPONS §9.2, new). A scoped bolt-action rifle: 42 per hitscan shot, effective to 70 m, every
## 0.9 s. Every hit MARKS the target for 6 s: its weak-point radius doubles and crits on it deal 3.0x (WeaponRules);
## cloaked / disguised enemies read the status "marked" to reveal themselves. Frozen statues crit anywhere.
## Scope: 2.5x zoom while aiming (camera FOV, applied after the camera each frame). Ammo 8 (+3 per tier).
## Alt-fire READ CAREFULLY: while scoped, hold to slow time (Game.slowmo) for as long as the 3 s meter lasts; it
## refills 0.5 per second after a 1.5 s delay.
## V3: rounds pierce one non-heavy enemy (both marked). V5: marked weak points glow for Sprocket (meta
## "bs_glow_weak" on the target; Sprocket / the HUD may read it).
## Ω TERMS APPLY: marked enemies take +25% from every gun (WeaponRules), and a marked weak point explodes when it is
## crit (60, r4, once per mark). Signatures: footnote (each mark spreads to the nearest enemy within 6 m),
## asterisk (a kill on a marked target refunds 1 ammo and 1 s of Read Carefully).

var read: float = 3.0
var read_delay: float = 0.0
var reading: bool = false
var zoom_k: float = 0.0
var _scope_hinted: bool = false


func _ready() -> void:
	process_priority = 100        # after BoltCamera, so the scope FOV sticks for the frame
	read = P("read_max", 3.0)


func scoped() -> bool:
	return equipped and mgr != null and mgr.bolt != null and mgr.bolt.is_aiming()


func mark(e: Node3D) -> void:
	if not alive(e):
		return
	if not mgr.has_status(e, &"marked") and e.has_meta(&"bs_terms_done"):
		e.remove_meta(&"bs_terms_done")      # a fresh mark re-arms the TERMS APPLY blast
	mgr.apply_status(e, &"marked", P("mark_time", 6.0))
	if level() >= 5:
		e.set_meta(&"bs_glow_weak", true)


func _fire() -> void:
	cooldown = interval()
	if not use_ammo(1):
		return
	var from: Vector3 = origin()
	var dir: Vector3 = aim()
	var res: Dictionary = mgr.hitscan(from, dir, P("range", 70.0), 0.05)
	var end: Vector3 = res["end"]
	var pierce: int = int(P("pierce_v3", 1)) if level() >= 3 else 0
	var n: int = 0
	for h: Array in res["hits"]:
		var e: Node3D = h[1]
		if n > 0 and WeaponData.prop_bool(e, "heavy"):
			end = h[2]
			break
		mark(e)
		deal(e, roundf(dmg(float(d.get("damage", 42)))), h[2], dir, {"marked": P("mark_time", 6.0)})
		popup.emit("bs.weapon.fx.marked", h[2])
		if sig() == &"footnote":
			var nb: Node3D = nearest_enemy(center_of(e), P("footnote_r", 6.0), [e])
			if nb != null:
				mark(nb)
				WeaponFX.tracer(mgr.world(), center_of(e), center_of(nb), WeaponData.color(id), 0.02, 0.3)
		end = h[2]
		n += 1
		if n > pierce:
			break
	var col: Color = Color("#ffd23e") if omega() else WeaponData.color(id)
	WeaponFX.tracer(mgr.world(), mgr.muzzle_pos(), end, col, 0.03, 0.12)
	WeaponFX.tracer(mgr.world(), mgr.muzzle_pos(), end, Color.WHITE, 0.012, 0.18)
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), col, 0.25 * tier_mul())
	recoil(float(d.get("recoil", 0.03)))
	shake(P("shake", 0.12))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


## Asterisk refunds / Ω TERMS APPLY blasts for this gun's own hits.
func on_hit_dealt(target: Node3D, hit: Combat.Hit, killed: bool) -> void:
	_after_hit(target, hit, killed)


## ... and for everybody else's (EnemyBase hits; this gun's own are handled above).
func on_any_hit(enemy: Node, hit: Combat.Hit, killed: bool) -> void:
	if hit.weapon_id != id and enemy is Node3D:
		_after_hit(enemy as Node3D, hit, killed)


func _after_hit(target: Node3D, hit: Combat.Hit, killed: bool) -> void:
	if not mgr.has_status(target, &"marked"):
		return
	if killed and sig() == &"asterisk":
		add_ammo(int(P("asterisk_ammo", 1)))
		read = minf(P("read_max", 3.0), read + P("asterisk_read", 1.0))
	if omega() and hit.weak_point and not target.has_meta(&"bs_terms_done"):
		target.set_meta(&"bs_terms_done", true)
		var pos: Vector3 = hit.point if hit.point != Vector3.ZERO else center_of(target)
		popup.emit("bs.weapon.fx.terms", pos)
		explode.call_deferred(pos, P("terms_r", 4.0), dmg(P("terms_blast", 60.0)))


func _tick(dt: float, is_equipped: bool) -> void:
	var real: float = dt / maxf(0.05, Engine.time_scale)
	if reading:
		read = maxf(0.0, read - real)
		read_delay = P("read_delay", 1.5)
		if read <= 0.0:
			reading = false
	else:
		read_delay = maxf(0.0, read_delay - real)
		if read_delay <= 0.0:
			read = minf(P("read_max", 3.0), read + P("read_refill", 0.5) * real)
	if not is_equipped:
		reading = false


func _alt_held(_dt: float) -> void:
	if not scoped():
		if not _scope_hinted:
			_scope_hinted = true
			WeaponText.hint("bs.weapon.hint.read_scope", "readscope")
		reading = false
		return
	if read > 0.0:
		if not reading:
			popup.emit("bs.weapon.fx.read", mgr.muzzle_pos() + aim() * 2.0)
		reading = true
		Game.slowmo(0.05)


func _on_alt_released() -> void:
	reading = false


func _on_cancel() -> void:
	reading = false


func _process(delta: float) -> void:
	if mgr == null or mgr.bolt == null or mgr.bolt.camera == null:
		return
	var want: float = 1.0 if scoped() else 0.0
	zoom_k = move_toward(zoom_k, want, delta / maxf(0.01, Engine.time_scale) * 6.0)
	if zoom_k > 0.001 and mgr.bolt.camera.cam != null:
		var base: float = float(Settings.get_value("fov", 70))
		mgr.bolt.camera.cam.fov = base / lerpf(1.0, P("zoom", 2.5), zoom_k)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["scope"] = zoom_k
	s["read"] = read / maxf(0.01, P("read_max", 3.0))
	s["reading"] = reading
	return s
