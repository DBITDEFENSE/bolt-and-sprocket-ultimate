class_name WeaponManager
extends Node
## Bolt's arsenal: owns one BSWeapon per owned gun, reads the fire / alt-fire / swap inputs, runs the weapon wheel
## model, aims (Bolt.aim_origin + Bolt.aim_dir bent by AimAssist.bend), routes every hit through deal_damage()
## (use-XP, status application) and drops / grants ammo. Lives as Bolt's child "Weapons".
##
## Level runner:   var wm: WeaponManager = WeaponManager.attach_to(bolt)        (after Bolt + camera exist)
## Tests:          wm.scripted = {"fire": true, "alt": false}; wm.aim_override = Vector3(0, 0, -1)
##
## Inputs: fire, aim, alt_fire (registered here if missing), weapon_prev / weapon_next (cycle; pages while the wheel
## is open), weapon_1..8 (current wheel page), weapon_wheel (Tab: hold > 0.18 s opens the wheel, a tap quick-swaps
## to the last weapon), pad RB (weapon_next on a pad: hold > 0.18 s opens the wheel, a tap cycles), pad LB = alt-fire.

signal hit_landed(target: Node3D, hit: Combat.Hit, killed: bool)
signal weapon_fired(weapon_id: StringName)
signal popup(text_id: String, pos: Vector3)
signal wheel_changed
signal first_equip(weapon_id: StringName, ad_id: String)
signal xp_gained(weapon_id: StringName, amount: float)

const ALT_ACTION: StringName = &"alt_fire"
const HOLD: float = 0.18

var bolt: Bolt
var weapons: Dictionary = {}            # id -> BSWeapon
var current: StringName = &""
var last: StringName = &""
var holstered: bool = false
var locked: Dictionary = {}             # id -> true while repossessed (Repo-Tron)
var xp_enabled: bool = true             # false in the Firing Range (no farming)
var ammo_drops_enabled: bool = true
var scripted: Dictionary = {}           # {"fire": bool, "alt": bool} replaces device input when non-empty
var aim_override: Vector3 = Vector3.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var gun_visual: GunVisual = null
var ui_layer: CanvasLayer = null

# wheel model (ui/bs/weapon_wheel.gd draws it)
var wheel_open: bool = false
var wheel_device: String = "kb"
var wheel_page: int = 0
var wheel_sel: int = -1
var wheel_vec: Vector2 = Vector2.ZERO
var _tab_down: bool = false
var _tab_t: int = 0
var _rb_down: bool = false
var _rb_t: int = 0
var _blocked_by_wheel: bool = false


## The one call the level runner makes. Idempotent: returns the existing manager if Bolt already has one.
static func attach_to(b: Bolt, with_ui: bool = true) -> WeaponManager:
	var existing: Node = b.get_node_or_null("Weapons")
	if existing is WeaponManager:
		return existing as WeaponManager
	var wm: WeaponManager = WeaponManager.new()
	wm.name = "Weapons"
	wm.set_meta(&"with_ui", with_ui)
	b.add_child(wm)
	return wm


func _ready() -> void:
	bolt = get_parent() as Bolt
	if bolt != null and not bolt.is_node_ready():
		await bolt.ready      # attached before Bolt entered the tree: wait for its motor / Visual
	rng.randomize()
	_register_alt_action()
	ensure_start_weapons()
	_sync_weapons()
	current = BS.current_weapon if weapons.has(BS.current_weapon) else (_owned_in_order()[0] if not _owned_in_order().is_empty() else &"")
	if current != &"":
		BS.current_weapon = current
		(weapons[current] as BSWeapon).equip()
	wheel_page = _page_of(current)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.enemy_hit.connect(_on_enemy_hit)
	gun_visual = GunVisual.new()
	gun_visual.name = "GunVisual"
	gun_visual.mgr = self
	add_child(gun_visual)
	if bool(get_meta(&"with_ui", true)):
		ui_layer = CanvasLayer.new()
		ui_layer.name = "WeaponUI"
		ui_layer.layer = 5
		add_child(ui_layer)
		var ret: Control = (load("res://ui/bs/reticle.tscn") as PackedScene).instantiate()
		ret.set("mgr", self)
		ui_layer.add_child(ret)
		var wh: Control = (load("res://ui/bs/weapon_wheel.tscn") as PackedScene).instantiate()
		wh.set("mgr", self)
		ui_layer.add_child(wh)


func _exit_tree() -> void:
	if wheel_open:
		close_wheel(false)


## alt_fire isn't in data/input_defaults.json yet: middle mouse, X, pad LB (BS_WEAPONS §7).
func _register_alt_action() -> void:
	if InputMap.has_action(ALT_ACTION):
		return
	InputMap.add_action(ALT_ACTION, 0.2)
	var mb: InputEventMouseButton = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	InputMap.action_add_event(ALT_ACTION, mb)
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = KEY_X
	InputMap.action_add_event(ALT_ACTION, k)
	var j: InputEventJoypadButton = InputEventJoypadButton.new()
	j.button_index = JOY_BUTTON_LEFT_SHOULDER
	InputMap.action_add_event(ALT_ACTION, j)


## A fresh profile owns the three starting guns (BS_WEAPONS §13).
func ensure_start_weapons() -> void:
	if not BS.weapons.is_empty():
		return
	for s: Variant in WeaponData.doc()["start_weapons"]:
		give(StringName(str(s)))


func give(id: StringName) -> BSWeapon:
	if not WeaponData.has(id):
		push_warning("Unknown weapon: %s" % id)
		return null
	BS.give_weapon(id)
	var w: BSWeapon = _sync_weapons().get(id, null)
	if w != null and int(w.state().get("ammo_now", -1)) < 0:
		w.refill()
	return w


func _sync_weapons() -> Dictionary:
	for k: Variant in BS.weapons.keys():
		var id: StringName = StringName(str(k))
		if weapons.has(id) or not WeaponData.has(id):
			continue
		var path: String = str(WeaponData.def(id).get("script", ""))
		var w: BSWeapon
		if path != "" and ResourceLoader.exists(path):
			w = (load(path) as GDScript).new() as BSWeapon
		else:
			w = _archetype_for(id)
		w.setup(id, self)
		add_child(w)
		w.popup.connect(func(t: String, pos: Vector3) -> void: popup.emit(t, pos))
		weapons[id] = w
	return weapons


func _archetype_for(id: StringName) -> BSWeapon:
	match str(WeaponData.def(id).get("archetype", "projectile")):
		"hitscan": return HitscanWeapon.new()
		"charged": return ChargedWeapon.new()
		"chain": return ChainWeapon.new()
		"lobbed", "deployable": return LobbedWeapon.new()
		"beam": return BeamWeapon.new()
	return ProjectileWeapon.new()


func weapon(id: StringName = &"") -> BSWeapon:
	return weapons.get(current if id == &"" else id, null)


func owns(id: StringName) -> bool:
	return weapons.has(id)


# ------------------------------------------------------------------ frame

func _physics_process(dt: float) -> void:
	BeatClock.advance(dt)
	if weapons.size() != BS.weapons.size():
		_sync_weapons()
	for w: Variant in weapons.values():
		(w as BSWeapon).tick(dt)
	var fire: bool = false
	var alt: bool = false
	if not scripted.is_empty():
		fire = bool(scripted.get("fire", false))
		alt = bool(scripted.get("alt", false))
	elif can_fire():
		fire = Input.is_action_pressed(&"fire")
		alt = Input.is_action_pressed(ALT_ACTION)
	if not can_fire() and scripted.is_empty():
		fire = false
		alt = false
	var w2: BSWeapon = weapon()
	if w2 != null:
		w2.tick_input(dt, fire and _alive(), alt and _alive())


func _process(_delta: float) -> void:
	if bolt == null:
		return
	if AimAssist.player == bolt:
		AimAssist.narrow = current == &"omni_blaster"
		AimAssist.update(bolt.aim_dir())
	var now: int = Time.get_ticks_msec()
	if _tab_down and not wheel_open and float(now - _tab_t) / 1000.0 > HOLD:
		open_wheel("kb")
	if _rb_down and not wheel_open and float(now - _rb_t) / 1000.0 > HOLD:
		open_wheel("pad")
	if wheel_open:
		if not _alive():
			close_wheel(false)
		elif wheel_device == "pad":
			var v: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down", 0.0)
			if v.length() >= 0.4:
				wheel_point(v)


func _alive() -> bool:
	return bolt != null and not bolt.dead


func can_fire() -> bool:
	return _alive() and bolt.input_enabled and not holstered and not wheel_open and not BS.blocked() and current != &"" \
		and not locked.has(current) and not bolt.has_meta(&"fire_blocked")


# ------------------------------------------------------------------ aim

func aim_origin() -> Vector3:
	return bolt.aim_origin() if bolt != null else Vector3.ZERO


func aim_dir() -> Vector3:
	var raw: Vector3 = aim_override.normalized() if aim_override != Vector3.ZERO else bolt.aim_dir()
	return AimAssist.bend(raw, aim_origin())


func muzzle_pos() -> Vector3:
	if gun_visual != null and gun_visual.has_muzzle():
		return gun_visual.muzzle_global()
	return aim_origin() + aim_dir() * float(WeaponData.doc()["aim"]["muzzle_forward"])


func world() -> Node:
	return bolt.get_parent() if bolt != null and bolt.get_parent() != null else self


func add_recoil(rad: float) -> void:
	if bolt != null and bolt.camera != null:
		bolt.camera.add_recoil(rad)
	if gun_visual != null:
		gun_visual.kick(rad)


## First thing hit along a ray (world + solid props), or the end point.
func ray_world(from: Vector3, to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = bolt.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, int(WeaponData.doc()["aim"]["world_mask"]))
	return space.intersect_ray(q)


## Hitscan: living enemies whose sphere (center, radius + pad) the segment passes, nearest first, stopping at the
## first wall. Returns {"hits": [[dist, enemy, point]...], "end": Vector3}.
func hitscan(from: Vector3, dir: Vector3, rng_m: float, pad: float = 0.1) -> Dictionary:
	var to: Vector3 = from + dir * rng_m
	var wall: Dictionary = ray_world(from, to)
	var end: Vector3 = wall["position"] if not wall.is_empty() else to
	var hits: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or not bool(e.call("is_alive")):
			continue
		var c: Vector3 = e.call("get_center")
		var cp: Vector3 = Geometry3D.get_closest_point_to_segment(c, from, end)
		if cp.distance_to(c) < float(e.get("radius")) + pad:
			hits.append([from.distance_to(cp), e, cp])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return {"hits": hits, "end": end}


# ------------------------------------------------------------------ damage + XP

func status_node(target: Node) -> StatusEffects:
	return target.get_node_or_null("Status") as StatusEffects if target != null else null


func has_status(target: Node, s: StringName) -> bool:
	var st: StatusEffects = status_node(target)
	return st != null and st.has(s)


func apply_status(target: Node, s: StringName, seconds: float) -> void:
	var st: StatusEffects = status_node(target)
	if st != null:
		st.apply(s, seconds)


## Every weapon hit goes through here: weak-point query, Status child + hit.status, take_damage, use-XP.
func deal_damage(target: Node3D, hit: Combat.Hit) -> bool:
	if target == null or not is_instance_valid(target) or not bool(target.call("is_alive")):
		return false
	if not hit.weak_point and target.has_method("is_weak_point"):
		hit.weak_point = bool(target.call("is_weak_point", hit.point))
	for s: Variant in hit.status.keys():
		apply_status(target, StringName(str(s)), float(hit.status[s]))
	var before: float = float(target.get("hp")) if "hp" in target else -1.0
	var killed: bool = bool(target.call("take_damage", hit))
	var removed: float = hit.amount
	if before >= 0.0:
		removed = clampf(before - maxf(0.0, float(target.get("hp"))), 0.0, before)
	if hit.weapon_id != &"" and weapons.has(hit.weapon_id):
		var boss: bool = target.is_in_group(&"bosses")
		var P: Dictionary = WeaponData.progression()
		var xp: float = removed * float(P["xp_boss_per_hp"] if boss else P["xp_per_hp"])
		if killed:
			xp += float(P["xp_elite_kill"]) if WeaponData.prop_bool(target, "elite") else float(P["xp_kill"])
		add_xp(hit.weapon_id, xp)
	hit_landed.emit(target, hit, killed)
	return killed


## Use-XP with the catch-up rule (×2 while below the floor of the average of the other owned weapons).
func add_xp(id: StringName, amount: float) -> void:
	if not xp_enabled or amount <= 0.0 or not BS.weapons.has(String(id)):
		return
	var st: Dictionary = BS.weapons[String(id)]
	var lv: int = int(st.get("level", 1))
	var others: Array = []
	for k: Variant in BS.weapons.keys():
		if str(k) != String(id):
			others.append(int((BS.weapons[k] as Dictionary).get("level", 1)))
	if not others.is_empty():
		var sum: int = 0
		for o: Variant in others:
			sum += int(o)
		if lv < int(floor(float(sum) / others.size())):
			amount *= float(WeaponData.progression()["catchup_mul"])
	st["xp"] = float(st.get("xp", 0)) + amount
	xp_gained.emit(id, amount)
	var nl: int = WeaponData.level_for_xp(float(st["xp"]))
	if nl > lv:
		st["level"] = nl
		EventBus.weapon_leveled.emit(id, nl)
		if nl == 3:
			WeaponText.say("bs.weapon.levelup.02")
		elif nl == 5:
			WeaponText.say("bs.weapon.levelup.03")
		else:
			WeaponText.say("bs.weapon.levelup.%02d" % (1 if rng.randf() < 0.5 else 4))


## Assist XP: another source damages a target that carries a status one of our guns applies.
func _on_enemy_hit(enemy: Node, hit: RefCounted, _killed: bool) -> void:
	var h: Combat.Hit = hit as Combat.Hit
	if h == null or enemy == null:
		return
	var owners: Dictionary = WeaponData.doc().get("status_owner", {})
	var st: StatusEffects = status_node(enemy)
	if st == null:
		return
	for s: Variant in owners.keys():
		if str(s).begins_with("_"):
			continue
		var wid: StringName = StringName(str(owners[s]))
		if wid != h.weapon_id and weapons.has(wid) and st.has(StringName(str(s))):
			add_xp(wid, h.amount * float(WeaponData.progression()["assist_frac"]))


# ------------------------------------------------------------------ ammo

## One orb of a family: every owned gun in it gains its listed amount. Returns the total granted.
func add_family_ammo(family: String) -> int:
	var total: int = 0
	for id: Variant in weapons.keys():
		var g: int = WeaponData.family_grant(family, id)
		if g > 0:
			total += (weapons[id] as BSWeapon).add_ammo(g)
	return total


## Ammo Grab-Bag (shop): refill everything.
func refill_all() -> void:
	for w: Variant in weapons.values():
		(w as BSWeapon).refill()


func _on_enemy_killed(enemy: Node, _by: StringName) -> void:
	if not ammo_drops_enabled or enemy == null or not (enemy is Node3D) or enemy.is_in_group(&"props"):
		return
	if rng.randf() >= float(WeaponData.doc()["ammo_families"]["drop_chance"]):
		return
	var fam: String = "charge" if rng.randf() < 0.5 else "void"
	if enemy.is_in_group(&"office") and rng.randf() < 0.5:
		fam = "paper"
	var c: Vector3 = (enemy as Node3D).call("get_center") if enemy.has_method("get_center") else (enemy as Node3D).global_position
	AmmoOrb.spawn(world(), c, fam, Vector3(rng.randf_range(-2, 2), 5, rng.randf_range(-2, 2)))


# ------------------------------------------------------------------ selection

func slots() -> Array[StringName]:
	var out: Array[StringName] = []
	var lo: Variant = (SaveProfile.doc.get("bs", {}) as Dictionary).get("loadout", null) if SaveProfile.doc is Dictionary else null
	if lo is Array and (lo as Array).size() > 0:
		for s: Variant in lo:
			out.append(StringName(str(s)))
		return out
	return WeaponData.ids()


func pages() -> int:
	var ps: int = int(WeaponData.doc()["wheel"]["page_size"])
	return maxi(1, ceili(float(slots().size()) / ps))


func page_ids(page: int) -> Array[StringName]:
	var ps: int = int(WeaponData.doc()["wheel"]["page_size"])
	var all: Array[StringName] = slots()
	var out: Array[StringName] = []
	for i: int in ps:
		var k: int = page * ps + i
		out.append(all[k] if k < all.size() else &"")
	return out


func _page_of(id: StringName) -> int:
	var i: int = slots().find(id)
	return 0 if i < 0 else i / int(WeaponData.doc()["wheel"]["page_size"])


func _owned_in_order() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in slots():
		if weapons.has(id) and not locked.has(id):
			out.append(id)
	return out


func select(id: StringName) -> bool:
	if id == current or not weapons.has(id) or locked.has(id):
		return false
	var old: BSWeapon = weapon()
	if old != null:
		old.holster()
	last = current
	current = id
	BS.current_weapon = id
	(weapons[id] as BSWeapon).equip()
	EventBus.weapon_changed.emit(id)
	if bolt != null and bolt.motor != null:
		bolt.motor.fov_kick = maxf(bolt.motor.fov_kick, 1.6)
	var flag: String = "wad_" + String(id)
	if not BS.flag(flag):
		BS.set_flag(flag)
		first_equip.emit(id, str(WeaponData.def(id).get("ad", "")))
	if gun_visual != null:
		gun_visual.swap_to(id)
	wheel_changed.emit()
	return true


func cycle(dir: int) -> void:
	var owned: Array[StringName] = _owned_in_order()
	if owned.size() < 2:
		return
	var i: int = owned.find(current)
	select(owned[(i + dir + owned.size()) % owned.size()])


func quick_swap() -> void:
	if last != &"" and weapons.has(last) and not locked.has(last):
		select(last)
	else:
		cycle(1)


func select_slot(n: int) -> void:
	var ids: Array[StringName] = page_ids(wheel_page)
	if n >= 0 and n < ids.size() and ids[n] != &"":
		select(ids[n])


func holster(on: bool) -> void:
	holstered = on
	if on and weapon() != null:
		weapon().holster()
	elif not on and weapon() != null:
		weapon().equip()


## Repo-Tron's magnet: the gun leaves the wheel until returned.
func repossess(id: StringName) -> void:
	locked[id] = true
	if current == id:
		var fallback: StringName = last if weapons.has(last) and not locked.has(last) else &""
		if fallback == &"":
			for o: StringName in _owned_in_order():
				fallback = o
				break
		if fallback != &"":
			select(fallback)
	wheel_changed.emit()


func return_weapon(id: StringName) -> void:
	locked.erase(id)
	wheel_changed.emit()


var _stolen: StringName = &""


## Repo-Tron hook (bs/bosses/repo_tron.gd): repossess the equipped gun; returns its id.
func steal_current() -> StringName:
	if current == &"":
		return &""
	_stolen = current
	repossess(current)
	return _stolen


func return_stolen() -> void:
	if _stolen != &"":
		return_weapon(_stolen)
		_stolen = &""


# ------------------------------------------------------------------ wheel

func open_wheel(device: String) -> void:
	if wheel_open or not _alive() or _owned_in_order().size() < 2:
		return
	wheel_open = true
	wheel_device = device
	wheel_page = _page_of(current)
	wheel_sel = page_ids(wheel_page).find(current)
	wheel_vec = Vector2.ZERO
	Game.wheel_open = true
	BS.ui_block += 1
	_blocked_by_wheel = true
	var w: BSWeapon = weapon()
	if w != null:
		w.cancel_input()
	wheel_changed.emit()


func close_wheel(equip: bool) -> void:
	if not wheel_open:
		return
	wheel_open = false
	Game.wheel_open = false
	if _blocked_by_wheel:
		BS.ui_block = maxi(0, BS.ui_block - 1)
		_blocked_by_wheel = false
	_tab_down = false
	_rb_down = false
	if equip and wheel_sel >= 0:
		var ids: Array[StringName] = page_ids(wheel_page)
		if wheel_sel < ids.size() and ids[wheel_sel] != &"":
			select(ids[wheel_sel])
	wheel_changed.emit()


## Direction from the wheel centre (x right, y down); picks one of the 8 segments, slot 0 at the top, clockwise.
func wheel_point(v: Vector2) -> void:
	wheel_vec = v
	if v.length() <= 0.2:
		return
	var a: float = atan2(v.x, -v.y)
	if a < 0.0:
		a += TAU
	var n: int = int(WeaponData.doc()["wheel"]["page_size"])
	var k: int = int(round(a / TAU * n)) % n
	if k != wheel_sel:
		wheel_sel = k
		wheel_changed.emit()


func wheel_page_step(dir: int) -> void:
	wheel_page = (wheel_page + dir + pages()) % pages()
	wheel_changed.emit()


# ------------------------------------------------------------------ device input

func _input(event: InputEvent) -> void:
	if bolt == null or not _alive():
		return
	var pad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
	if wheel_open and wheel_device == "kb" and event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var v: Vector2 = wheel_vec + mm.relative * 0.06
		if v.length() > 1.0:
			v = v.normalized()
		wheel_point(v)
		return
	if event.is_action_pressed(&"weapon_wheel", false):
		_tab_down = true
		_tab_t = Time.get_ticks_msec()
	elif event.is_action_released(&"weapon_wheel"):
		if wheel_open:
			close_wheel(true)
		elif _tab_down and not BS.blocked():
			quick_swap()
		_tab_down = false
	if pad and event.is_action(&"weapon_next"):
		if event.is_action_pressed(&"weapon_next"):
			_rb_down = true
			_rb_t = Time.get_ticks_msec()
		elif event.is_action_released(&"weapon_next"):
			if wheel_open:
				close_wheel(true)
			elif _rb_down and not BS.blocked():
				cycle(1)
			_rb_down = false
		return
	if pad and event.is_action(&"weapon_prev"):
		return   # pad LB is alt-fire now (BS_WEAPONS §7)
	if event.is_action_pressed(&"weapon_next"):
		if wheel_open:
			wheel_page_step(1)
		elif not BS.blocked():
			cycle(1)
	elif event.is_action_pressed(&"weapon_prev"):
		if wheel_open:
			wheel_page_step(-1)
		elif not BS.blocked():
			cycle(-1)
	if BS.blocked() and not wheel_open:
		return
	for n: int in 8:
		if event.is_action_pressed(StringName("weapon_%d" % (n + 1))):
			if wheel_open:
				wheel_sel = n
				close_wheel(true)
			else:
				select_slot(n)
			return


# ------------------------------------------------------------------ Blartz: mods, signature, Omega hook

func buy_mod(id: StringName, slot: String) -> bool:
	if not weapons.has(id) or not WeaponData.MOD_SLOTS.has(slot):
		return false
	var lock: Dictionary = WeaponData.progression().get("mods_locked_until_flag", {})
	if lock.has(String(id)) and not BS.flag(str(lock[String(id)])):
		return false
	var mods: Dictionary = (weapons[id] as BSWeapon).state()["mods"]
	var next: int = int(mods.get(slot, 0)) + 1
	var price: int = WeaponData.mod_price(slot, next)
	if price < 0 or not BS.spend(price):
		return false
	mods[slot] = next
	return true


## choice 0 = A, 1 = B. First install costs 200 bolts at V3+; swapping later is free (§2.3).
func install_signature(id: StringName, choice: int) -> bool:
	if not weapons.has(id) or choice < 0 or choice > 1:
		return false
	var st: Dictionary = (weapons[id] as BSWeapon).state()
	if int(st.get("level", 1)) < int(WeaponData.progression()["sig_unlock_level"]):
		return false
	if int(st.get("sig", -1)) < 0 and not BS.spend(int(WeaponData.progression()["sig_price"])):
		return false
	st["sig"] = choice
	return true


## The Forge (M3) asks first: "" means ready, otherwise the deny line id (bs.forge.deny.01..04).
func can_evolve(id: StringName) -> String:
	if not weapons.has(id):
		return "bs.forge.deny.01"
	var st: Dictionary = (weapons[id] as BSWeapon).state()
	var P: Dictionary = WeaponData.progression()
	if int(st.get("level", 1)) < int(P["omega_level"]):
		return "bs.forge.deny.01"
	for s: String in WeaponData.MOD_SLOTS:
		if int((st["mods"] as Dictionary).get(s, 0)) < int(WeaponData.mods()["max_tier"]):
			return "bs.forge.deny.02"
	if int(st.get("sig", -1)) < 0:
		return "bs.forge.deny.03"
	if BS.bolts < int(P["omega_price"]):
		return "bs.forge.deny.04"
	return ""


## Sets the Omega flag (the Forge plays the cutscene and the evolve line). `free` skips the price (dev console).
func evolve(id: StringName, free: bool = false) -> bool:
	if not free and (can_evolve(id) != "" or not BS.spend(int(WeaponData.progression()["omega_price"]))):
		return false
	if not weapons.has(id):
		return false
	(weapons[id] as BSWeapon).state()["omega"] = true
	wheel_changed.emit()
	return true


## HUD card (ui/bs/hud.gd): -1 = infinite / heat weapon.
func get_ammo(id: StringName) -> int:
	return (weapons[id] as BSWeapon).ammo() if weapons.has(id) else -1


func get_ammo_cap(id: StringName) -> int:
	return (weapons[id] as BSWeapon).max_ammo() if weapons.has(id) else -1


func hud_state() -> Dictionary:
	var w: BSWeapon = weapon()
	return w.hud_state() if w != null else {}
