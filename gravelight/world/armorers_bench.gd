class_name ArmorersBench
extends Interactable
## The Armorer's Bench (UPDATE_04 section 6, DECISIONS T-068): a gunsmith's workbench with a vise, a pegboard of
## tools and a gooseneck lamp, where the gun in your hands takes attachments (WeaponKit: any gun with a table in
## data/gravelight/weapons/attachments.json, DECISIONS T-074; wonder weapons are refused in character). Placed by
## the map generators near each map's spawn (Crossroads Inn: the stable's tack corner; Kaltenbrunn: the gatehouse;
## Totenhafen: the harbourmaster's hut). A future map only needs a node with this script.
##
## Frame: the node sits on the floor against a wall, local -Z facing the room (like the ammo boxes); the bench runs
## from the wall (z 0) out to z -0.72, 1.5 m wide, its top at TOP.
##
## Players hold Use to open the bench UI (ArmorersBenchUI: the gun in the vise or cradle, its slots, the stat bars).
## Bots and the map-mark orders use the static API (no UI): ArmorersBench.buy(player, slot, option) and
## ArmorersBench.options_for(player); the caller brings the bot here first (nearest() / in_reach()). Co-op: the UI
## runs on the buyer's machine and a client's purchase goes to the host (buy_for, net_callable).

const GROUP: StringName = &"armorers_bench"
const TOP: float = 0.9
const REACH_M: float = 3.0

var _ui: CanvasLayer = null
static var _vo_done: Dictionary = {}   # pid -> true once they've said their first Gunsmith line this match


func _ready() -> void:
	interact_size = Vector3(1.6, 1.3, 0.9)
	interact_offset = Vector3(0, 1.0, -0.4)
	super._ready()
	add_to_group(GROUP)
	# a solid bench (the generators also cut its footprint out of the navmesh: NavBlock_ArmorersBench)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "BenchBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(1.5, TOP, 0.72)
	cs.shape = bs
	cs.position = Vector3(0, TOP * 0.5, -0.36)
	body.add_child(cs)
	add_child(body)
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "kit", _cmd_kit, "kit [list | <slot> <option> | free <slot> <option> | clear [slot] | finish <id>]: attachments on the gun in hand (UPDATE_04 section 6)")
	ArmorersBench.reset_match()


func build_greybox() -> void:
	InteractableArt.place(self, "armorers_bench", func(r: Node3D) -> void: bench_art(r))
	# the display pistol clamped in the vise, slide in the jaws
	var gun: Node3D = WeaponModels.build(&"m1911")
	gun.name = "VisePistol"
	gun.position = Vector3(-0.5, TOP + 0.2, -0.43)
	gun.rotation_degrees = Vector3(0, 90, 90)
	add_child(gun)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "BenchLamp"
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 1.1
	lamp.omni_range = 2.8
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.38, TOP + 0.42, -0.42)
	add_child(lamp)
	add_label(self, "ARMORER", Vector3(0, TOP + 0.78, -0.045), 18, Color(0.95, 0.82, 0.55))   # on the sign board


## The bench, built once into a cached mesh (InteractableArt): oak top and legs, a shelf, the pegboard with its
## tools, the vise, files and punches, an oil can, a box of .45, the parts tray, the gooseneck lamp.
static func bench_art(g: Node3D) -> void:
	# top, apron, legs, shelf
	InteractableArt.B(g, Vector3(-0.75, TOP - 0.06, -0.72), Vector3(0.75, TOP, -0.02), "furniture")
	InteractableArt.B(g, Vector3(-0.72, TOP - 0.16, -0.7), Vector3(0.72, TOP - 0.06, -0.66), "furniture")
	for lx: float in [-0.68, 0.68]:
		for lz: float in [-0.66, -0.08]:
			InteractableArt.B(g, Vector3(lx - 0.035, 0, lz - 0.035), Vector3(lx + 0.035, TOP - 0.06, lz + 0.035), "furniture")
	InteractableArt.B(g, Vector3(-0.7, 0.18, -0.64), Vector3(0.7, 0.21, -0.06), "planks")
	InteractableArt.OB(g, Vector3(-0.35, 0.3, -0.35), Vector3(0.36, 0.18, 0.26), "cardboard", Vector3(0, 8, 0))   # a carton under the bench
	InteractableArt.OB(g, Vector3(0.32, 0.27, -0.33), Vector3(0.22, 0.12, 0.3), "iron", Vector3(0, -12, 0))        # a steel ammo can
	# the pegboard on the wall with its tools
	InteractableArt.B(g, Vector3(-0.74, TOP, -0.035), Vector3(0.74, TOP + 0.85, -0.005), "planks")
	for k: int in 6:
		InteractableArt.OB(g, Vector3(-0.6 + k * 0.08, TOP + 0.5, -0.045), Vector3(0.012, 0.26, 0.006), "steel")       # files and drifts
	InteractableArt.OB(g, Vector3(0.05, TOP + 0.55, -0.045), Vector3(0.05, 0.24, 0.008), "steel", Vector3(0, 0, 18))  # a wrench
	InteractableArt.OB(g, Vector3(0.22, TOP + 0.6, -0.05), Vector3(0.03, 0.22, 0.025), "furniture")                 # hammer handle
	InteractableArt.OB(g, Vector3(0.22, TOP + 0.71, -0.05), Vector3(0.09, 0.03, 0.03), "iron")                      # hammer head
	InteractableArt.OB(g, Vector3(0.45, TOP + 0.45, -0.045), Vector3(0.16, 0.012, 0.006), "brass")                  # a cleaning rod
	InteractableArt.ring(g, Vector3(0.58, TOP + 0.62, -0.04), 0.07, 0.008, "steel", Vector3(90, 0, 0))   # a coil of spring wire
	InteractableArt.OB(g, Vector3(0.0, TOP + 0.78, -0.03), Vector3(0.62, 0.11, 0.012), "paint:#2c2a26")            # the sign board
	# the vise at the left end: base, fixed and moving jaws, screw and tommy bar
	InteractableArt.B(g, Vector3(-0.66, TOP, -0.58), Vector3(-0.36, TOP + 0.06, -0.3), "machine_green")
	InteractableArt.B(g, Vector3(-0.64, TOP + 0.06, -0.47), Vector3(-0.38, TOP + 0.2, -0.445), "machine_green")
	InteractableArt.B(g, Vector3(-0.64, TOP + 0.06, -0.415), Vector3(-0.38, TOP + 0.2, -0.39), "machine_green")
	InteractableArt.B(g, Vector3(-0.63, TOP + 0.185, -0.452), Vector3(-0.39, TOP + 0.2, -0.445), "leather")          # jaw pads
	InteractableArt.B(g, Vector3(-0.63, TOP + 0.185, -0.415), Vector3(-0.39, TOP + 0.2, -0.408), "leather")
	InteractableArt.S(g, Vector3(-0.51, TOP + 0.12, -0.39), Vector3(-0.51, TOP + 0.12, -0.18), 0.022, "steel")
	InteractableArt.S(g, Vector3(-0.6, TOP + 0.12, -0.19), Vector3(-0.42, TOP + 0.12, -0.19), 0.016, "steel")
	# files, punches, a screwdriver, a rag, an oil can, a box of .45 and the parts tray
	for k2: int in 4:
		InteractableArt.OB(g, Vector3(-0.18 + k2 * 0.03, TOP + 0.006, -0.6), Vector3(0.008, 0.008, 0.12), "brass" if k2 % 2 == 0 else "steel", Vector3(0, 10 - k2 * 6, 0))
	InteractableArt.OB(g, Vector3(0.05, TOP + 0.012, -0.55), Vector3(0.025, 0.025, 0.1), "red_paint", Vector3(0, -35, 0))
	InteractableArt.OB(g, Vector3(0.1, TOP + 0.006, -0.6), Vector3(0.006, 0.006, 0.08), "steel", Vector3(0, -35, 0))
	InteractableArt.OB(g, Vector3(-0.12, TOP + 0.01, -0.28), Vector3(0.2, 0.02, 0.16), "cloth_red", Vector3(0, 22, 0))
	InteractableArt.C(g, Vector3(0.58, TOP + 0.06, -0.18), 0.045, 0.12, "red_paint")
	InteractableArt.S(g, Vector3(0.58, TOP + 0.12, -0.18), Vector3(0.66, TOP + 0.17, -0.24), 0.008, "brass")
	InteractableArt.OB(g, Vector3(0.18, TOP + 0.035, -0.22), Vector3(0.11, 0.07, 0.08), "cardboard", Vector3(0, -8, 0))
	InteractableArt.OB(g, Vector3(0.18, TOP + 0.072, -0.22), Vector3(0.112, 0.004, 0.082), "paint:#7a2a1e", Vector3(0, -8, 0))
	InteractableArt.B(g, Vector3(0.28, TOP, -0.62), Vector3(0.52, TOP + 0.02, -0.46), "iron")
	for k3: int in 5:
		InteractableArt.dot(g, Vector3(0.31 + k3 * 0.045, TOP + 0.03, -0.54 + (k3 % 2) * 0.03), 0.008, "brass")
	# the gooseneck lamp on the right
	InteractableArt.B(g, Vector3(0.5, TOP, -0.12), Vector3(0.66, TOP + 0.03, -0.04), "iron")
	InteractableArt.S(g, Vector3(0.58, TOP + 0.03, -0.08), Vector3(0.5, TOP + 0.48, -0.3), 0.02, "iron")
	InteractableArt.S(g, Vector3(0.5, TOP + 0.48, -0.3), Vector3(0.4, TOP + 0.47, -0.4), 0.02, "iron")
	Props.cone(g, Vector3(0.38, TOP + 0.44, -0.42), 0.085, 0.1, "enamel_green")
	InteractableArt.dot(g, Vector3(0.38, TOP + 0.41, -0.42), 0.03, "bulb_warm")


func get_prompt(player: Player) -> String:
	if player == null or player.is_bot:
		return ""
	var w: WeaponInstance = WeaponKit.held(player)
	if w == null:
		return "Armorer's Bench: bring a gun"
	if not WeaponKit.accepts(w):
		return "Armorer's Bench: %s" % WeaponKit.refusal(w)
	return "Hold [%s] for the Armorer's Bench (%s attachments)" % [prompt_key(&"interact"), str(w.data.get("name", w.id))]


func can_interact(player: Player) -> bool:
	return player != null and not player.is_bot and WeaponKit.accepts(WeaponKit.held(player))


func hold_time(_player: Player) -> float:
	return 0.25


## The UI opens on the user's own machine; purchases go to the host (buy_for).
func net_local() -> bool:
	return true


func net_callable() -> Array:
	return ["buy_for"]


func interact(player: Player) -> void:
	if player == null or player.is_bot or not player.is_local:
		return
	if _ui != null and is_instance_valid(_ui):
		return
	AudioDirector.play_3d(WeaponKit.sound("open", "bench_open"), global_position + Vector3.UP, -4.0)
	if DisplayServer.get_name() == "headless":
		return   # tools and smokes use buy() directly
	_ui = ArmorersBenchUI.new()
	_ui.bench = self
	_ui.player = player
	get_tree().current_scene.add_child(_ui)


## Host side of a client's purchase (net_callable).
func buy_for(pid: int, slot: String, option: String) -> void:
	if not is_inside_tree():
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid:
			buy(p, slot, option)
			return


# ================================================================== the public API

## Buys `option` for `slot` on `player`'s gun (the one in their hands, else the first gun in their slots that
## offers that option: WeaponKit.gun_of) and fits it: {"ok": bool, "reason": "" or a code (WeaponKit.REASONS:
## no_gun, wrong_weapon (the gun in hand takes nothing: WeaponKit.refusal), unknown (not for this gun), installed,
## needs_power, refused, no_scrip), "price": int, "weapon": id}. Doesn't check distance: bring the buyer to a bench
## first (nearest / in_reach). A different option in a slot replaces the fitted one (one choice per slot).
static func buy(player: Player, slot: String, option: String) -> Dictionary:
	var w: WeaponInstance = WeaponKit.gun_of(player, slot, option)
	if w == null:
		w = WeaponKit.held(player)
	var res: Dictionary = {"ok": false, "reason": "", "price": WeaponKit.price(w, slot, option), "weapon": String(w.id) if w != null else ""}
	var code: String = WeaponKit.check(w, slot, option, GameState.power_on, player != null and player.is_companion)
	if code != "":
		res["reason"] = code
		if code == "refused" and player != null:
			GLVO.say_as(player.player_id, str((WeaponKit.cfg().get("vo", {}) as Dictionary).get("refuse", "GUNSMITH_REFUSE")), 1.0)
		return res
	if Net.is_client() and player.is_local and player.is_inside_tree():
		var bench: ArmorersBench = nearest(player.get_tree(), player.global_position)
		if bench != null and Net.session != null:
			Net.session.request_call(bench, &"buy_for", [player.player_id, slot, option])
		res["ok"] = true
		res["reason"] = "pending"
		return res
	if not Economy.spend(player.player_id, StringName("%s_%s_%s" % [w.base_id(), slot, option]), int(res["price"])):
		res["reason"] = "no_scrip"
		if player.is_local and not player.is_bot:
			AudioDirector.play_2d("deny", -2.0)
		return res
	player.weapons.fit_attachment(w.id, slot, option)
	if player.is_inside_tree():
		var at: Vector3 = player.global_position + Vector3.UP
		var b2: ArmorersBench = nearest(player.get_tree(), player.global_position)
		if b2 != null:
			at = b2.global_position + Vector3(0, TOP + 0.2, 0)
		AudioDirector.play_3d(WeaponKit.slot_sound(w, slot), at, -2.0)
		Net.sfx_all(WeaponKit.slot_sound(w, slot), at, -2.0)
	_gunsmith_line(player)
	res["ok"] = true
	return res


## Everything the bench offers for `player`'s gun (WeaponKit.gun_of: the one in hand if it takes attachments),
## one row per option: {slot, slot_name, option, name, desc, price, installed, reason ("" = can buy now;
## WeaponKit codes, "no_scrip" when short), short (Scrip missing), weapon (its id)}. [] when no gun takes any.
static func options_for(player: Player) -> Array:
	var out: Array = []
	var w: WeaponInstance = WeaponKit.gun_of(player)
	if w == null:
		return out
	var up: bool = w.upgraded
	var pid: int = player.player_id if player != null else 0
	for slot: String in WeaponKit.slot_order(w):
		for opt: Variant in WeaponKit.options(w, slot):
			var o: String = str(opt)
			var p: int = WeaponKit.price(w, slot, o)
			var code: String = WeaponKit.check(w, slot, o, GameState.power_on, player != null and player.is_companion)
			var short: int = maxi(0, p - Economy.get_scrip(pid))
			if code == "" and short > 0:
				code = "no_scrip"
			out.append({"slot": slot, "slot_name": WeaponKit.slot_name(w, slot), "option": o, "name": WeaponKit.option_name(w, slot, o, up),
				"desc": str(WeaponKit.variant(w, slot, o, up).get("desc", "")), "price": p, "installed": WeaponKit.has_option(w, slot, o),
				"reason": code, "short": short, "weapon": String(w.id)})
	return out


## Dev console: `kit` lists the bench, `kit mag drum` buys like the bench, `kit free mag drum` fits without paying,
## `kit clear [slot]` takes parts off, `kit finish nickel` sets the finish on the held pistol (M1911 only).
func _cmd_kit(a: PackedStringArray) -> String:
	var p: Player = null
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Player = n as Player
		if pl != null and pl.is_local and not pl.is_bot:
			p = pl
	var w: WeaponInstance = WeaponKit.gun_of(p)
	if p == null or w == null:
		return "kit: %s" % WeaponKit.refusal(WeaponKit.held(p))
	if a.is_empty() or a[0] == "list":
		var lines: PackedStringArray = []
		for r: Dictionary in options_for(p):
			lines.append("%s %s  %d  %s%s" % [r["slot"], r["option"], int(r["price"]), "FITTED " if bool(r["installed"]) else "", str(r["reason"])])
		return "\n".join(lines)
	match a[0]:
		"clear":
			for slot: Variant in (WeaponKit.slot_order(w) if a.size() < 2 else [a[1]]):
				p.weapons.fit_attachment(w.id, str(slot), "")
			return "kit: cleared"
		"free":
			if a.size() < 3 or not WeaponKit.is_known(w, a[1], a[2]):
				return "usage: kit free <slot> <option> (for the %s)" % str(w.data.get("name", w.id))
			p.weapons.fit_attachment(w.id, a[1], a[2])
			return "kit: fitted %s" % WeaponKit.option_name(w, a[1], a[2], w.upgraded)
		"finish":
			w.finish = StringName(a[1] if a.size() > 1 else "")
			w.refresh_kit()
			p.weapons.set_kit(w.id, WeaponKit.encode(w.kit), String(w.finish))
			return "kit: finish %s" % String(w.finish)
	if a.size() < 2:
		return "usage: kit <slot> <option>"
	return "kit: %s" % str(buy(p, a[0], a[1]))


## The closest bench to `pos` (null on a map without one).
static func nearest(tree: SceneTree, pos: Vector3) -> ArmorersBench:
	if tree == null:
		return null
	var best: ArmorersBench = null
	var best_d: float = INF
	for n: Node in tree.get_nodes_in_group(GROUP):
		var b: ArmorersBench = n as ArmorersBench
		if b == null:
			continue
		var d: float = b.global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = b
	return best


## True when `player` stands within reach of a bench (bots: walk here before buy()).
static func in_reach(player: Player) -> bool:
	if player == null or not player.is_inside_tree():
		return false
	var b: ArmorersBench = nearest(player.get_tree(), player.global_position)
	return b != null and b.stand_point().distance_to(player.global_position) <= REACH_M


## Where a buyer stands: a metre in front of the bench.
func stand_point() -> Vector3:
	return global_transform * Vector3(0, 0, -1.3)


static func _gunsmith_line(player: Player) -> void:
	var vo: Dictionary = WeaponKit.cfg().get("vo", {})
	var first: bool = not _vo_done.has(player.player_id)
	_vo_done[player.player_id] = true
	GLVO.say_as(player.player_id, str(vo.get("category", "GUNSMITH")), float(vo.get("first_chance", 1.0)) if first else float(vo.get("chance", 0.45)))


## A new match: everyone gets their first Gunsmith line again.
static func reset_match() -> void:
	_vo_done.clear()
