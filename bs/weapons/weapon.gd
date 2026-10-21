class_name BSWeapon
extends Node
## Base of every B&S gun. One instance per owned weapon lives under the WeaponManager; projectiles and devices it
## spawns call back into it, so it keeps working after a swap. Stats come from WeaponData; the per-weapon
## progression state (xp, level, mods, signature, omega, ammo) lives in BS.weapons[id].
##
## Subclasses override the hooks:
##   _fire()                         primary shot when the trigger is held and the cooldown is ready (default)
##   _on_fire_pressed / _on_fire_released / _on_alt_pressed / _on_alt_released / _alt_held(dt)
##   _tick(dt, equipped)             every physics frame for every owned weapon (heat vent, timers)
##   on_projectile_hit(p, target, point) -> bool   true keeps the projectile alive (pierce)
##   on_projectile_world(p, point, normal) -> bool
##   on_projectile_expire(p) / on_projectile_tick(p, dt)
##   hud_state() -> Dictionary       what the reticle / HUD shows

signal fired(weapon_id: StringName)
signal popup(text_id: String, pos: Vector3)

var id: StringName
var d: Dictionary = {}
var p: Dictionary = {}
var mgr: WeaponManager
var cooldown: float = 0.0
var equipped: bool = false
var fire_held: bool = false
var alt_held: bool = false
var _empty_warned: bool = false
var _ammo_frac: float = 0.0      # fractional ammo drain (beams, Amplify)


func setup(weapon_id: StringName, manager: WeaponManager) -> void:
	id = weapon_id
	mgr = manager
	d = WeaponData.def(id)
	p = d.get("params", {})
	name = String(id)


# ------------------------------------------------------------------ progression state

func state() -> Dictionary:
	if not BS.weapons.has(String(id)):
		BS.give_weapon(id)
	return BS.weapons[String(id)]


func level() -> int:
	return clampi(int(state().get("level", 1)), 1, 5)


func mod_tier(slot: String) -> int:
	return int((state().get("mods", {}) as Dictionary).get(slot, 0))


func sig() -> StringName:
	return WeaponData.signature_id(id, int(state().get("sig", -1)))


func omega() -> bool:
	return bool(state().get("omega", false))


func P(key: String, fallback: float = 0.0) -> float:
	return float(p.get(key, fallback))


# ------------------------------------------------------------------ stats

func dmg(base: float) -> float:
	return base * WeaponData.dmg_mul(mod_tier("dmg"), level())


func interval(base: float = -1.0) -> float:
	var b: float = float(d.get("interval", 0.5)) if base < 0.0 else base
	return b * WeaponData.rate_mul(mod_tier("rate"))


func max_ammo() -> int:
	return WeaponData.max_ammo(id, mod_tier("ammo"), level())


func ammo() -> int:
	var m: int = max_ammo()
	if m < 0:
		return -1
	var a: int = int(state().get("ammo_now", -1))
	return m if a < 0 else mini(a, m)


func set_ammo(n: int) -> void:
	var m: int = max_ammo()
	if m < 0:
		return
	state()["ammo_now"] = clampi(n, 0, m)
	if n > 0:
		_empty_warned = false


func has_ammo(n: int = 1) -> bool:
	var a: int = ammo()
	return a < 0 or a >= n


## Spends ammo; false (and the original "out of ammo" hint, once per trigger pull) when there isn't enough.
func use_ammo(n: int = 1) -> bool:
	if not has_ammo(n):
		empty_feedback()
		return false
	if ammo() >= 0:
		set_ammo(ammo() - n)
	return true


## Fractional drain (beams, Amplify). Spends whole rounds as the fraction accrues.
func drain_ammo(amount: float) -> bool:
	if ammo() < 0:
		return true
	_ammo_frac += amount
	while _ammo_frac >= 1.0:
		if not use_ammo(1):
			_ammo_frac = 0.0
			return false
		_ammo_frac -= 1.0
	return ammo() > 0 or _ammo_frac > 0.0


func add_ammo(n: int) -> int:
	var m: int = max_ammo()
	if m < 0 or n <= 0:
		return 0
	var before: int = ammo()
	set_ammo(before + n)
	return ammo() - before


func refill() -> void:
	if max_ammo() >= 0:
		state()["ammo_now"] = max_ammo()


func empty_feedback() -> void:
	if _empty_warned:
		return
	_empty_warned = true
	WeaponText.hint(str(d.get("empty_hint", "")), str(d.get("empty_key", "")))
	popup.emit("bs.weapon.fx.empty", mgr.muzzle_pos() if mgr != null else Vector3.ZERO)


# ------------------------------------------------------------------ helpers

func make_hit(amount: float, point: Vector3 = Vector3.ZERO, dir: Vector3 = Vector3.ZERO) -> Combat.Hit:
	var h: Combat.Hit = Combat.Hit.make(amount, WeaponData.damage_type(id), mgr.bolt if mgr != null else null)
	h.weapon_id = id
	h.point = point
	h.dir = Vector3(dir.x, 0, dir.z).normalized() if dir != Vector3.ZERO else Vector3.ZERO
	return h


func deal(target: Node3D, amount: float, point: Vector3 = Vector3.ZERO, dir: Vector3 = Vector3.ZERO, status: Dictionary = {}) -> bool:
	var h: Combat.Hit = make_hit(amount, point, dir)
	h.status = status.duplicate()
	return mgr.deal_damage(target, h)


## explodeAt (index.html:5240): everything within r + its radius takes dmg x (1 - 0.5 d / (r + radius)).
func explode(pos: Vector3, r: float, amount: float, status: Dictionary = {}) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e: Node3D in Combat.in_radius(mgr.get_tree(), pos, r):
		var c: Vector3 = e.call("get_center")
		var reach: float = r + float(e.get("radius"))
		var k: float = 1.0 - 0.5 * clampf(c.distance_to(pos) / reach, 0.0, 1.0)
		deal(e, roundf(amount * k), c, c - pos, status)
		out.append(e)
	WeaponFX.blast(mgr.world(), pos, r, WeaponData.color(id))
	if mgr.bolt != null and mgr.bolt.camera != null:
		mgr.bolt.camera.shake(clampf(0.55 * (1.0 - mgr.bolt.global_position.distance_to(pos) / 26.0), 0.15, 0.55))
	return out


func recoil(rad: float) -> void:
	mgr.add_recoil(rad)


func origin() -> Vector3:
	return mgr.aim_origin()


func aim() -> Vector3:
	return mgr.aim_dir()


## Direction from the muzzle to whatever the aim ray hits (world, or the point at max_range): projectiles converge
## on the reticle even when the gun model's muzzle is off the camera ray (hip height, side offset).
func fire_dir(max_range: float = 80.0) -> Vector3:
	var o: Vector3 = origin()
	var a: Vector3 = aim()
	var hit: Dictionary = mgr.ray_world(o, o + a * max_range)
	var p: Vector3 = hit["position"] if not hit.is_empty() else o + a * max_range
	var d: Vector3 = p - mgr.muzzle_pos()
	return d.normalized() if d.length() > 1.5 else a


func spawn_projectile(pos: Vector3, vel: Vector3, opts: Dictionary = {}) -> BSProjectile:
	var pr: BSProjectile = BSProjectile.new()
	pr.weapon = self
	pr.vel = vel
	pr.gravity = float(opts.get("gravity", 0.0))
	pr.life = float(opts.get("life", 2.0))
	pr.radius = float(opts.get("r", float(opts.get("size", 0.15)) + 0.1))
	pr.size = float(opts.get("size", 0.15))
	pr.color = opts.get("color", WeaponData.color(id))
	pr.stretch = float(opts.get("stretch", 0.0))
	pr.data = opts.duplicate()
	mgr.world().add_child(pr)
	pr.global_position = pos
	return pr


# ------------------------------------------------------------------ input (called by the manager)

func tick_input(dt: float, fire: bool, alt: bool) -> void:
	if fire and not fire_held:
		_empty_warned = false
		_on_fire_pressed()
	elif not fire and fire_held:
		_on_fire_released()
	fire_held = fire
	if alt and not alt_held:
		_on_alt_pressed()
	elif not alt and alt_held:
		_on_alt_released()
	alt_held = alt
	if alt_held:
		_alt_held(dt)
	if fire_held and cooldown <= 0.0 and _can_auto_fire():
		_fire()


func tick(dt: float) -> void:
	cooldown -= dt
	_tick(dt, equipped)


func equip() -> void:
	equipped = true
	_on_equip()


## Holstering cancels whatever was held (a charge is dropped, not fired; Amplify ends).
func holster() -> void:
	cancel_input()
	equipped = false
	_on_holster()


func cancel_input() -> void:
	fire_held = false
	alt_held = false
	_on_cancel()


func _can_auto_fire() -> bool:
	return true


func _fire() -> void:
	pass


func _on_fire_pressed() -> void:
	pass


func _on_fire_released() -> void:
	pass


func _on_alt_pressed() -> void:
	pass


func _on_alt_released() -> void:
	pass


func _alt_held(_dt: float) -> void:
	pass


func _tick(_dt: float, _equipped: bool) -> void:
	pass


func _on_equip() -> void:
	pass


func _on_holster() -> void:
	pass


func _on_cancel() -> void:
	pass


func on_projectile_hit(_pr: BSProjectile, _target: Node3D, _point: Vector3) -> bool:
	return false


func on_projectile_world(_pr: BSProjectile, _point: Vector3, _normal: Vector3) -> bool:
	return false


func on_projectile_expire(_pr: BSProjectile) -> void:
	pass


func on_projectile_tick(_pr: BSProjectile, _dt: float) -> void:
	pass


## Called by the manager after every hit this gun dealt (killed = the hit killed it).
func on_hit_dealt(_target: Node3D, _hit: Combat.Hit, _killed: bool) -> void:
	pass


## Called for every EnemyBase hit in the level (EventBus.enemy_hit), from any source.
func on_any_hit(_enemy: Node, _hit: Combat.Hit, _killed: bool) -> void:
	pass


# ------------------------------------------------------------------ shared targeting helpers

static func alive(e: Node) -> bool:
	return e != null and is_instance_valid(e) and e.is_inside_tree() and bool(e.call("is_alive"))


static func center_of(e: Node3D) -> Vector3:
	return e.call("get_center") if e.has_method("get_center") else e.global_position


## Living enemies (group "enemies"), minus `exclude` and (unless allow_subs) our Hostile Takeover subsidiaries.
func enemies(exclude: Array = [], allow_subs: bool = false) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or not alive(e) or exclude.has(e) or (not allow_subs and e.has_meta(&"bs_subsidiary")):
			continue
		out.append(e)
	return out


func nearest_enemy(pos: Vector3, rng_m: float, exclude: Array = [], min_d: float = 0.0) -> Node3D:
	var best: Node3D = null
	var bd: float = rng_m
	for e: Node3D in enemies(exclude):
		var dd: float = center_of(e).distance_to(pos)
		if dd < bd and dd >= min_d:
			bd = dd
			best = e
	return best


## The enemy nearest the aim ray inside a cone (dot > min_dot) within range, with line of sight.
func aimed_enemy(rng_m: float, min_dot: float, allow_subs: bool = false) -> Node3D:
	var best: Node3D = null
	var bs: float = min_dot
	var from: Vector3 = origin()
	var dir: Vector3 = aim()
	for e: Node3D in enemies([], allow_subs):
		var to: Vector3 = center_of(e) - from
		if to.length() > rng_m:
			continue
		var a: float = to.normalized().dot(dir)
		if a > bs and mgr.ray_world(from, center_of(e)).is_empty():
			bs = a
			best = e
	return best


func shake(a: float) -> void:
	if mgr != null and mgr.bolt != null and mgr.bolt.camera != null:
		mgr.bolt.camera.shake(a)


func tier_mul() -> float:
	return WeaponData.visual_mul(mod_tier("dmg"))


func hud_state() -> Dictionary:
	return {"id": id, "name": WeaponData.display_name(id, omega()), "ammo": ammo(), "max": max_ammo(), "level": level(),
		"omega": omega(), "cooldown": maxf(0.0, cooldown)}


## Model-by-level detail count (HUD pips / GunVisual extras).
func model_details() -> int:
	return level() - 1
