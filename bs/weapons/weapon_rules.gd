class_name WeaponRules
extends RefCounted
## Cross-weapon damage rules applied to every gun hit inside WeaponManager.deal_damage (BS_WEAPONS §1, §4, §5):
##   - Super Sprocket: amount x Sprocket.damage_mult_for(tree) (x2 while the protocol runs; the M1 gap)
##   - your own subsidiaries (Hostile Takeover) are not shot; only Cease & Desist may stamp them (handled by that gun)
##   - MARKED (The Fine Print): the weak-point radius doubles (0.75 -> 1.5) and marked crits deal 3.0x, not 2.5x
##   - FROZEN statues: Fine Print shots crit anywhere on them
##   - SERVED variants: EnemyBase applies the standard x1.4 itself; Ω INJUNCTION (x1.7) and Desist (x1.3) are
##     corrected here from the meta "bs_served_mult" the Cease & Desist stamps on the target
##   - Ω TERMS APPLY: marked enemies take +25%
##   - Braces (Root Canal Signature A): rooted targets take +20%
##   - MARKED DOWN (Clearance Rack) on bosses: armour 0.45 -> +0.02 per stack (cap 0.65); Ω EVERYTHING MUST GO at
##     20 stacks: no armour for 4 s (meta "bs_bare_until")
## Everything is duck-typed so TestDummy, EnemyBase and bosses all work. Non-gun damage (mallet, Sprocket) doesn't
## pass through here; EnemyBase would need the same rules for those (see the M3 report).

const DEFAULT_CRIT: float = 2.5
const DEFAULT_SERVED: float = 1.4


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func has_status(target: Node, s: StringName) -> bool:
	var st: StatusEffects = target.get_node_or_null("Status") as StatusEffects if target != null else null
	return st != null and st.has(s)


## Weak-point position / radius of an EnemyBase-style target, or null when it has none exposed.
static func weak_info(target: Node) -> Array:
	if target == null or not target.has_method("_weak_point_pos") or not target.has_method("weak_radius"):
		return []
	if target.has_method("weak_point_exposed") and not bool(target.call("weak_point_exposed")):
		return []
	return [target.call("_weak_point_pos"), float(target.call("weak_radius"))]


static func crit_mult_of(target: Node) -> float:
	return float(target.call("crit_mult")) if target != null and target.has_method("crit_mult") else DEFAULT_CRIT


static func omega_owned(mgr: WeaponManager, id: StringName) -> bool:
	var w: BSWeapon = mgr.weapons.get(id, null) as BSWeapon if mgr != null else null
	return w != null and w.omega()


## false = the hit is blocked (don't deal it).
static func pre_hit(mgr: WeaponManager, target: Node3D, hit: Combat.Hit) -> bool:
	if target.has_meta(&"bs_subsidiary"):
		if target.is_in_group(&"subsidiaries"):
			return false
		target.remove_meta(&"bs_subsidiary")      # stale (a pooled enemy reused after a contract)
	var marked: bool = has_status(target, &"marked")
	var fp: Dictionary = WeaponData.params(&"fine_print")
	if not hit.weak_point and hit.weapon_id == &"fine_print" and has_status(target, &"frozen"):
		hit.weak_point = true
	if not hit.weak_point and marked and hit.point != Vector3.ZERO:
		var wi: Array = weak_info(target)
		if not wi.is_empty() and hit.point.distance_to(wi[0]) < float(wi[1]) * float(fp.get("marked_radius_mul", 2.0)):
			hit.weak_point = true
	var mult: float = Sprocket.damage_mult_for(mgr.get_tree())
	if hit.weak_point and marked:
		mult *= float(fp.get("marked_crit", 3.0)) / crit_mult_of(target)
	if marked and omega_owned(mgr, &"fine_print"):
		mult *= float(fp.get("terms_mul", 1.25))
	if (has_status(target, &"served") or hit.status.has("served")) and target is EnemyBase and target.has_meta(&"bs_served_mult"):
		mult *= float(target.get_meta(&"bs_served_mult")) / DEFAULT_SERVED
	if has_status(target, &"rooted") and target.has_meta(&"bs_braces"):
		mult *= float(WeaponData.param(&"root_canal", "braces_mul", 1.2))
	if target.is_in_group(&"bosses") and not hit.weak_point:
		mult *= boss_armor_mul(target)
	hit.amount *= mult
	return true


## Extra multiplier on a boss's non-weak-point damage from MARKED DOWN (relative to its 0.45 armour).
static func boss_armor_mul(target: Node) -> float:
	var cr: Dictionary = WeaponData.params(&"clearance_rack")
	var base: float = float(cr.get("boss_armor", 0.45))
	if float(target.get_meta(&"bs_bare_until", -1.0)) > now():
		return 1.0 / base
	var stacks: int = markdown_stacks(target)
	if stacks <= 0:
		return 1.0
	var a: float = minf(float(cr.get("boss_armor_cap", 0.65)), base + float(cr.get("boss_armor_per_stack", 0.02)) * stacks)
	return a / base


static func markdown_stacks(target: Node) -> int:
	if target == null or not has_status(target, &"marked_down"):
		return 0
	return int(target.get_meta(&"bs_markdown", 0))


## SERVED multiplier a target is currently stamped with (for tests / HUD): 1.0 when not served.
static func served_mult(target: Node) -> float:
	if not has_status(target, &"served"):
		return 1.0
	return float(target.get_meta(&"bs_served_mult", DEFAULT_SERVED))
