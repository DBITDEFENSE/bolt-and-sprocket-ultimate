class_name WeaponLocker
extends Interactable
## T-263 (the owner: "add a weapon locker"): a steel arms locker on the wall (data/gravelight/weapon_locker.json).
## Hold [interact] with a gun in your hands to lock it away as it is (its Crucible tier, attachments, finish, the
## rounds in the magazine and the reserve, the fire mode); hold again later to take it back. Each player has one
## compartment of their own, for this match: what is in it stays there when its owner goes down, bleeds out and
## comes back with the starting pistol (that is what it is for), and it is gone when the match ends. Nothing is
## written to the profile, so it is open in Classic Rules and online alike.
##
## One hold, by what you carry (plan()):
##   - the compartment empty, two guns or more on you: the gun in your hands goes in (store_cost Scrip);
##   - a gun inside and a free weapon slot (or empty hands): it comes out (withdraw_cost, 0);
##   - a gun inside and your slots full: the gun in your hands goes in and the stored one comes out (store_cost).
## You never lock away your last gun, and a gun you already carry a copy of stays inside until you hold that copy.
##
## Co-op: the host decides. A client's hold runs here on the host with that player's puppet (Player.use_interactable);
## the puppet's holder forwards the two inventory calls to the owner's real one (remove_current, give_net_entry, as
## Jakub's hand-over does). The contents (pid -> one WeaponHolder.net_entry) are the host's, mirrored at once and in
## every state snapshot (NetMatch "wl"), so each machine builds its own prompt. Bots and companions never use it
## (no prompt, not in any errand group). A campaign hop carries the contents to the next map's locker
## (Campaign.snapshot "locker").
##
## Placed at load from the json's "lockers" rows (MapRoot -> attach): at = the floor point on the wall's face under
## the locker's middle, yaw = where its doors face (deg: 0 = +z, 90 = +x, 180 = -z, 270 = -x), like a bank branch.
## It is 0.45 m deep, flush on its wall, inside the strip the navmesh's 0.5 m agent radius already keeps clear: no
## navmesh change. Origin: that floor point; local -Z is the front.

const BODY: Vector3 = Vector3(0.92, 1.9, 0.45)   # width, height, depth (the collider and the art)

## The host's (offline: the only) contents: player id -> one weapon in WeaponHolder.net_entry shape.
static var _stored: Dictionary = {}
static var _inst: Dictionary = {}   # var_to_str(entry) -> WeaponInstance (instance_of's cache)

var _card: Label3D
var _card_sig: String = "?"
var _poll_t: float = 0.0


# ================================================================== data

static func cfg() -> Dictionary:
	return GLData.table("weapon_locker")


## The "lockers" row of a map (matched by map id prefix, like the bank's branches); {} = none on this map.
static func row_for(map_id: String) -> Dictionary:
	var all: Dictionary = cfg().get("lockers", {})
	for k: Variant in all.keys():
		if map_id.begins_with(str(k)):
			return all[k]
	return {}


## The transform a row stands the locker at.
static func row_transform(row: Dictionary) -> Transform3D:
	var a: Array = row.get("at", [0, 0, 0])
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(row.get("yaw", 0.0)) + 180.0)), Vector3(float(a[0]), float(a[1]), float(a[2])))


## MapRoot: a new match forgets the lockers' contents (a campaign arrival brings them along), and the map's locker
## is built when it has a row.
static func attach(m: MapRoot) -> WeaponLocker:
	var arrival: Dictionary = Campaign.arrival_payload(m.map_id)
	if arrival.is_empty():
		reset_match()
	else:
		restore_carry(arrival.get("locker", {}))
	var row: Dictionary = row_for(String(m.map_id))
	if row.is_empty() or not bool(cfg().get("enabled", true)):
		return null
	var l: WeaponLocker = WeaponLocker.new()
	l.name = "WeaponLocker"
	m.add_child(l)
	l.global_transform = row_transform(row)
	l.reset_physics_interpolation()
	return l


# ================================================================== the contents

static func reset_match() -> void:
	_stored.clear()
	_inst.clear()


## What `pid` has in the locker ([] = nothing): one WeaponHolder.net_entry.
static func stored(pid: int) -> Array:
	var e: Variant = _stored.get(pid, [])
	return e if e is Array else []


static func has_stored(pid: int) -> bool:
	return not stored(pid).is_empty()


static func _put(pid: int, entry: Array) -> void:
	if entry.is_empty():
		_stored.erase(pid)
	else:
		_stored[pid] = entry


## The weapon of a stored entry, as it was put away; null when the tables no longer know its id.
## (Cached by the entry: a prompt asks every frame. use() forgets the one it hands out.)
static func instance_of(entry: Array) -> WeaponInstance:
	if entry.is_empty():
		return null
	var key: String = var_to_str(entry)
	if _inst.has(key):
		return _inst[key]
	var probe: WeaponHolder = WeaponHolder.new()
	probe.apply_net({"s": [entry]})
	var w: WeaponInstance = probe.slots[0] if not probe.slots.is_empty() else null
	probe.free()
	if _inst.size() > 32:
		_inst.clear()
	_inst[key] = w
	return w


static func label_of(w: WeaponInstance) -> String:
	return "" if w == null else str(w.data.get("name", w.id)) + str(w.tier_cfg().get("suffix", ""))


## May this gun go in? (weapon_locker.json "no_store": weapon ids or classes the locker refuses.)
static func storable(w: WeaponInstance, c: Dictionary) -> bool:
	if w == null:
		return false
	var no: Array = c.get("no_store", [])
	return not (no.has(String(w.id)) or no.has(String(w.base_id())) or no.has(String(w.weapon_class())))


## Pure: what a hold does for this holder. {action: &"store" | &"take" | &"swap" | &"none", why (for "none":
## "empty", "last_gun", "refused", "duplicate", "busy"), cost, held (the gun in hand or null), inside (the stored
## gun or null)}.
static func plan(holder: WeaponHolder, entry: Array, max_slots: int, c: Dictionary) -> Dictionary:
	var held: WeaponInstance = holder.current() if holder != null else null
	var inside: WeaponInstance = instance_of(entry)
	var out: Dictionary = {"action": &"none", "why": "", "cost": 0, "held": held, "inside": inside}
	if holder == null or holder.in_last_stand() or holder.carry_limited or holder.holstered:
		out["why"] = "busy"
		return out
	if inside == null:
		if held == null:
			out["why"] = "empty"
		elif not storable(held, c):
			out["why"] = "refused"
		elif holder.slots.size() <= int(c.get("keep_on_you", 1)):
			out["why"] = "last_gun"
		else:
			out["action"] = &"store"
			out["cost"] = int(c.get("store_cost", 0))
		return out
	# a copy of the stored gun in another slot: it stays inside until that copy is the gun in hand (no two of a kind)
	for w: WeaponInstance in holder.slots:
		if w != held and w.base_id() == inside.base_id():
			out["why"] = "duplicate"
			return out
	var twin: bool = held != null and held.base_id() == inside.base_id()
	if (held == null or holder.slots.size() < max_slots) and not twin:
		out["action"] = &"take"
		out["cost"] = int(c.get("withdraw_cost", 0))
	elif not storable(held, c):
		out["why"] = "refused"
	else:
		out["action"] = &"swap"
		out["cost"] = int(c.get("store_cost", 0)) + int(c.get("withdraw_cost", 0))
	return out


static func plan_for(player: Player) -> Dictionary:
	if player == null or player.weapons == null or player.is_bot or player.is_companion:
		return {"action": &"none", "why": "busy", "cost": 0, "held": null, "inside": null}
	return plan(player.weapons, stored(player.player_id), player.weapons.max_slots(), cfg())


## Host / offline: does the hold for `player`. &"store", &"take", &"swap", or &"none" (nothing to do), &"no_scrip".
static func use(player: Player) -> StringName:
	if not Net.is_authority() or player == null or player.downed or player.spectating:
		return &"none"
	var pl: Dictionary = plan_for(player)
	var action: StringName = pl["action"]
	if action == &"none":
		return &"none"
	var pid: int = player.player_id
	if int(pl["cost"]) > 0 and not Economy.spend(pid, &"weapon_locker", int(pl["cost"])):
		return &"no_scrip"
	var holder: WeaponHolder = player.weapons
	_inst.erase(var_to_str(stored(pid)))   # the instance handed out below is the player's alone from here on
	match action:
		&"store":
			_put(pid, WeaponHolder.net_entry(holder.remove_current()))
		&"take":
			_put(pid, [])
			holder.give_instance(pl["inside"] as WeaponInstance)
		&"swap":
			_put(pid, WeaponHolder.net_entry(holder.remove_current()))
			holder.give_instance(pl["inside"] as WeaponInstance)
	if player.remote_body != null and is_instance_valid(player.remote_body):
		player.remote_body.refresh_weapon()
	return action


# ================================================================== co-op and the campaign

## The contents for a state snapshot (NetMatch "wl") and a campaign hop (Campaign.snapshot "locker").
static func to_net() -> Dictionary:
	return _stored.duplicate(true)


## Client: the host's contents. (Keys may come back as strings from a saved or relayed payload.)
static func from_net(d: Dictionary) -> void:
	_stored.clear()
	for k: Variant in d.keys():
		if d[k] is Array and not (d[k] as Array).is_empty():
			_stored[int(str(k))] = (d[k] as Array).duplicate(true)


static func carry_snapshot() -> Dictionary:
	return to_net()


static func restore_carry(d: Variant) -> void:
	from_net(d if d is Dictionary else {})


## Client: the host changed `pid`'s compartment.
func _net_state(pid: int, entry: Array) -> void:
	_put(pid, entry)
	_refresh_card()


# ================================================================== Interactable

func _ready() -> void:
	interact_size = Vector3(BODY.x + 0.3, 1.8, 0.3)
	interact_offset = Vector3(0, 1.0, -(BODY.z + 0.1))
	super._ready()
	add_to_group(&"weapon_lockers")
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("no_mantle", true)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = BODY
	cs.shape = bs
	cs.position = Vector3(0, BODY.y * 0.5, -BODY.z * 0.5)
	body.add_child(cs)
	add_child(body)
	_refresh_card()


func get_prompt(player: Player) -> String:
	if player == null or player.is_bot or player.is_companion:
		return ""
	var pl: Dictionary = plan_for(player)
	var t: Dictionary = cfg().get("text", {})
	var key: String = prompt_key(&"interact")
	var held: String = label_of(pl["held"] as WeaponInstance)
	var inside: String = label_of(pl["inside"] as WeaponInstance)
	var price: String = "" if int(pl["cost"]) <= 0 else " [%s]" % price_str(player, int(pl["cost"]))
	match pl["action"]:
		&"store":
			return str(t.get("store", "Hold [%s] to lock away %s%s")) % [key, held, price]
		&"take":
			return str(t.get("take", "Hold [%s] to take %s from the locker%s")) % [key, inside, price]
		&"swap":
			return str(t.get("swap", "Hold [%s] to lock away %s and take %s%s")) % [key, held, inside, price]
	match str(pl["why"]):
		"last_gun":
			return str(t.get("last_gun", "Arms locker: empty (keep one gun on you)"))
		"refused":
			return str(t.get("refused", "Arms locker: %s does not go in")) % held
		"duplicate":
			return str(t.get("duplicate", "Arms locker: %s inside (you carry one already)")) % inside
		"busy":
			return ""
	return str(t.get("empty", "Arms locker: empty"))


func can_interact(player: Player) -> bool:
	return player != null and not player.downed and plan_for(player)["action"] != &"none"


func interact(player: Player) -> void:
	use_by(player)


## The hold, with its sounds and the denied flash. Returns WeaponLocker.use's result.
func use_by(player: Player) -> StringName:
	var res: StringName = use(player)
	if res == &"no_scrip":
		if player.is_local:
			AudioDirector.play_2d("deny", -2.0)
		player.flash_prompt_denied()
		return res
	if res == &"none":
		return res
	var at: Vector3 = global_position + Vector3.UP * 1.1 - global_basis.z * BODY.z
	var s: Dictionary = cfg().get("sounds", {})
	for k: String in ["open", "store" if res == &"store" else "take"]:
		var snd: String = str(s.get(k, ""))
		if snd != "":
			AudioDirector.play_3d(snd, at, float(s.get("db", -4.0)))
			Net.sfx_all(snd, at, float(s.get("db", -4.0)))
	Net.mirror(self, &"_net_state", [player.player_id, stored(player.player_id)])
	_refresh_card()
	return res


## Where a player stands to use it (tools, smokes): `dist` metres out from the doors, on the floor.
func stand_point(dist: float = 0.6) -> Vector3:
	return global_position - global_basis.z * (BODY.z + dist)


# ================================================================== the card in the door's holder

func _process(delta: float) -> void:
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 0.5
		_refresh_card()


## The paper card on the right door: what the local player has inside (each machine shows its own player's).
func _refresh_card() -> void:
	if _card == null:
		return
	var w: WeaponInstance = instance_of(stored(Net.local_player_id()))
	var txt: String = label_of(w).to_upper() if w != null else str((cfg().get("text", {}) as Dictionary).get("card_empty", "EMPTY"))
	if txt != _card_sig:
		_card_sig = txt
		_card.text = txt


# ================================================================== art

func build_greybox() -> void:
	InteractableArt.place(self, "weapon_locker", func(r: Node3D) -> void: WeaponLocker.locker_art(r))
	var t: Dictionary = cfg().get("text", {})
	add_label(self, str(t.get("stencil", "ARMS LOCKER")), Vector3(0, 1.66, -(BODY.z + 0.012)), 26, Color(0.82, 0.8, 0.68, 0.62))
	_card = add_label(self, "", Vector3(0.23, 1.2, -(BODY.z + 0.022)), 13, Color(0.16, 0.14, 0.11, 0.9), SurfaceText.PRINT)
	_card.width = 150.0
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# a small caged lamp on the wall over it (no shadows: T-258), so it reads in a dark corner
	var lc: Dictionary = cfg().get("lamp", {})
	if float(lc.get("energy", 0.0)) > 0.0:
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.name = "LockerLamp"
		lamp.light_color = Color(1.0, 0.78, 0.5)
		lamp.light_energy = float(lc.get("energy", 0.9))
		lamp.omni_range = float(lc.get("range", 3.2))
		lamp.omni_attenuation = 1.3
		lamp.shadow_enabled = false
		lamp.position = Vector3(0, BODY.y + 0.34, -0.3)
		add_child(lamp)
		var glass: MeshInstance3D = MeshInstance3D.new()
		glass.name = "LampGlass"
		var gm: CylinderMesh = CylinderMesh.new()
		gm.top_radius = 0.045
		gm.bottom_radius = 0.045
		gm.height = 0.11
		gm.radial_segments = 10
		glass.mesh = gm
		glass.material_override = Mats.get_mat("lantern_glass")
		glass.rotation_degrees = Vector3(90, 0, 0)
		glass.position = Vector3(0, BODY.y + 0.34, -0.1)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glass)


## A 1940s steel arms locker, two doors: a plinth, the carcass, a cornice, the doors proud of it with a pressed
## panel each, three louvres top and bottom, a lever handle and a hasp with a brass padlock, hinge barrels, a brass
## card holder with its paper card on the right door, a steel cartridge tin on top and the wall plate and cage of
## the little lamp over it. Built in the locker's frame (origin on the floor at the wall, -Z the front).
static func locker_art(r: Node3D) -> void:
	var w: float = BODY.x
	var h: float = BODY.y
	var d: float = BODY.z
	var body: Material = Mats.get_mat("olive_steel")
	var dark: Material = Mats.get_mat("loco_black")
	var steel: Material = Mats.get_mat("steel")
	var brass: Material = Mats.get_mat("brass")
	add_box(r, Vector3(w - 0.04, 0.1, d - 0.05), Vector3(0, 0.05, -(d - 0.05) * 0.5), dark)                 # the plinth
	add_box(r, Vector3(w, h - 0.14, d - 0.03), Vector3(0, 0.1 + (h - 0.14) * 0.5, -(d - 0.03) * 0.5), body)   # the carcass
	add_box(r, Vector3(w + 0.03, 0.04, d + 0.01), Vector3(0, h - 0.02, -(d + 0.01) * 0.5), body)             # the cornice
	var dw: float = w * 0.5 - 0.035
	var dh: float = h - 0.26
	var dy: float = 0.14 + dh * 0.5
	for sx: float in [-1.0, 1.0]:
		var cx: float = sx * (dw * 0.5 + 0.012)
		add_box(r, Vector3(dw, dh, 0.022), Vector3(cx, dy, -(d - 0.03) - 0.011), body)                         # a door
		add_box(r, Vector3(dw - 0.1, dh - 0.62, 0.008), Vector3(cx, dy - 0.02, -(d - 0.03) - 0.026), body)     # its pressed panel
		for i: int in 3:                                                                                      # louvres, top and bottom
			add_box(r, Vector3(dw - 0.14, 0.014, 0.012), Vector3(cx, 0.14 + dh - 0.1 - i * 0.045, -(d - 0.03) - 0.027), dark)
			add_box(r, Vector3(dw - 0.14, 0.014, 0.012), Vector3(cx, 0.14 + 0.1 + i * 0.045, -(d - 0.03) - 0.027), dark)
		for hy: float in [0.34, h * 0.5, h - 0.3]:                                                             # hinge barrels on the outer edges
			add_box(r, Vector3(0.022, 0.09, 0.022), Vector3(sx * (w * 0.5 - 0.008), hy, -(d - 0.03) - 0.012), steel)
	# the lever handle on the right door's inner edge, the hasp across the meeting stiles, the padlock
	add_box(r, Vector3(0.03, 0.16, 0.03), Vector3(0.06, 1.0, -(d - 0.03) - 0.04), steel)
	add_box(r, Vector3(0.05, 0.05, 0.016), Vector3(0.06, 1.0, -(d - 0.03) - 0.028), steel)
	add_box(r, Vector3(0.13, 0.034, 0.008), Vector3(0.0, 0.84, -(d - 0.03) - 0.027), steel)
	add_box(r, Vector3(0.045, 0.05, 0.02), Vector3(0.0, 0.795, -(d - 0.03) - 0.036), brass)
	add_box(r, Vector3(0.008, 0.03, 0.008), Vector3(-0.014, 0.832, -(d - 0.03) - 0.036), steel)
	add_box(r, Vector3(0.008, 0.03, 0.008), Vector3(0.014, 0.832, -(d - 0.03) - 0.036), steel)
	# the card holder on the right door (the card's text is the script's label)
	add_box(r, Vector3(0.2, 0.09, 0.006), Vector3(0.23, 1.2, -(d - 0.03) - 0.025), brass)
	add_box(r, Vector3(0.18, 0.07, 0.004), Vector3(0.23, 1.2, -(d - 0.03) - 0.03), Mats.get_mat("paper_old"))
	# the lamp's wall plate and cage ring over the locker (the glass and the light are the script's)
	add_box(r, Vector3(0.14, 0.14, 0.02), Vector3(0, h + 0.34, -0.01), dark)
	add_box(r, Vector3(0.012, 0.13, 0.012), Vector3(0, h + 0.34, -0.165), steel)
	add_box(r, Vector3(0.13, 0.012, 0.012), Vector3(0, h + 0.34, -0.165), steel)
	# a cartridge tin on top, pushed back against the wall
	add_box(r, Vector3(0.3, 0.16, 0.18), Vector3(-0.2, h + 0.08, -0.14), steel)
	add_box(r, Vector3(0.31, 0.02, 0.19), Vector3(-0.2, h + 0.17, -0.14), dark)
