class_name ArmorersBenchUI
extends CanvasLayer
## The Armorer's Bench screen (UPDATE_04 section 6, DECISIONS T-068 / T-074). Left: a close-up of the gun in your
## hands under the bench lamp (a pistol in the vise, a long gun laid in a padded cradle), the camera slowly orbiting
## it, rebuilt with whatever option you are looking at. Right: that gun's slots (WeaponKit.slot_order), the options
## of the chosen one (price, fitted, locked), its description, six stat bars (damage, range, recoil, ADS speed,
## mobility, capacity) showing the change the option would make, and BUY.
## Mouse, keyboard or controller (focus moves through the buttons; Q / E or LB / RB switch slots). Esc, B or
## crouch leaves; so does taking a hit. The world keeps running: the bench is diegetic.

const BARS: Array = [["damage", "DAMAGE", false], ["range", "RANGE", false], ["recoil", "RECOIL", true],
	["ads", "ADS SPEED", false], ["mobility", "MOBILITY", false], ["capacity", "CAPACITY", false]]

var bench: ArmorersBench
var player: Player
## Tools: start on this slot / previewing this option (bench_shots).
var start_slot: String = ""
var start_option: String = ""

var _slot: String = "mag"
var _preview: String = ""
var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _gun: Node3D
var _gun_len: float = 0.3
var _orbit: float = 0.6
var _slots_box: HBoxContainer
var _opts_box: VBoxContainer
var _desc: Label
var _title_opt: Label
var _scrip: Label
var _msg: Label
var _fitted: Label
var _buy: Button
var _bars: Dictionary = {}    # stat -> [StatBar, Label]
var _built_sig: String = "-"
var _vise: Node3D            # the pistol vise (hidden for a long gun)
var _cradle: Node3D          # a long gun's padded rests (rebuilt per gun)
var _benchtop: Node3D        # the oak top and its tools (lowered under a long gun)
var _key: SpotLight3D
var _opt_buttons: Dictionary = {}   # option -> [Button, its text without the marker]


func _init() -> void:
	layer = 25


func _ready() -> void:
	GameState.input_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var order: Array = WeaponKit.slot_order(_pistol())
	_slot = start_slot if start_slot != "" else (str(order[0]) if not order.is_empty() else "mag")
	_preview = start_option
	_build()
	_refresh()
	GLBus.player_damaged.connect(_on_damaged)
	GLBus.scrip_changed.connect(func(_p: int, _t: int, _d: int) -> void: _refresh_scrip())


func _exit_tree() -> void:
	GameState.input_blocked = false
	if player != null and is_instance_valid(player) and player.is_local and DisplayServer.get_name() != "headless" \
			and GameState.phase == GameState.Phase.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The gun on the bench: the one in the player's hands (WeaponKit.gun_of). Named for the T-068 pistol bench.
func _pistol() -> WeaponInstance:
	return WeaponKit.gun_of(player)


# ================================================================== layout

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel: PanelContainer = MenuKit.panel(Vector2(1180, 640))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-590, -320)
	panel.size = Vector2(1180, 640)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -590
	panel.offset_top = -320
	panel.offset_right = 590
	panel.offset_bottom = 320
	add_child(panel)
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	panel.add_child(h)
	# ---- left: the vise close-up and what's fitted
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	left.add_child(MenuKit.label("ARMORER'S BENCH", 30, MenuKit.GOLD, true))
	var svc: SubViewportContainer = SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(600, 430)
	svc.stretch = true
	left.add_child(svc)
	_vp = SubViewport.new()
	_vp.size = Vector2i(600, 430)
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_vp)
	_build_scene()
	_fitted = MenuKit.para("", 15, MenuKit.PAPER)
	_fitted.custom_minimum_size = Vector2(600, 0)
	left.add_child(_fitted)
	# ---- right: slots, options, stats, buy
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_scrip = MenuKit.label("", 20, MenuKit.GOLD)
	right.add_child(_scrip)
	_slots_box = HBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 4)
	right.add_child(_slots_box)
	_opts_box = VBoxContainer.new()
	_opts_box.add_theme_constant_override("separation", 2)
	_opts_box.custom_minimum_size = Vector2(0, 118)
	right.add_child(_opts_box)
	_title_opt = MenuKit.label("", 22, MenuKit.PAPER, true)
	right.add_child(_title_opt)
	_desc = MenuKit.para("", 15, MenuKit.DIM)
	_desc.custom_minimum_size = Vector2(0, 58)
	right.add_child(_desc)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)
	right.add_child(grid)
	for b: Array in BARS:
		grid.add_child(MenuKit.label(str(b[1]), 15, MenuKit.PAPER))
		var sb: StatBar = StatBar.new()
		sb.lower_better = bool(b[2])
		sb.custom_minimum_size = Vector2(250, 14)
		sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(sb)
		var val: Label = MenuKit.label("", 15, MenuKit.PAPER)
		val.custom_minimum_size = Vector2(120, 0)
		grid.add_child(val)
		_bars[str(b[0])] = [sb, val]
	_buy = MenuKit.button("BUY", _on_buy, 24, "")
	_buy.custom_minimum_size = Vector2(0, 50)
	right.add_child(_buy)
	_msg = MenuKit.label("", 16, MenuKit.GOLD)
	right.add_child(_msg)
	right.add_child(MenuKit.label("[Q/E or LB/RB] slot   [click / %s] choose   [Esc / B] leave" % GLSettings.action_label(&"interact"), 13, MenuKit.DIM))


## The vise close-up: a dim workshop, a slab of the oak top, the vise, the pistol clamped by its dust cover,
## the lamp's warm pool, and the orbiting camera.
func _build_scene() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.03, 0.028)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.32, 0.3, 0.3)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.5
	env.environment = e
	_vp.add_child(env)
	var root: Node3D = Node3D.new()
	_vp.add_child(root)
	# the bench top and the vise: a column on the bench, two leather-faced jaws gripping the pistol's dust cover
	# (model z -0.145..-0.065, y below 0.012); the grip and anything under it hang free behind the column
	_benchtop = Node3D.new()
	root.add_child(_benchtop)
	_vise = Node3D.new()
	root.add_child(_vise)
	Props.block(_benchtop, Vector3(-1.2, -0.36, -1.0), Vector3(1.2, -0.31, 1.0), "furniture")
	Props.block(_vise, Vector3(-0.05, -0.31, -0.26), Vector3(0.05, -0.27, -0.03), "machine_green")
	Props.block(_vise, Vector3(-0.032, -0.27, -0.2), Vector3(0.032, -0.075, -0.07), "machine_green")
	for s2: float in [-1.0, 1.0]:
		var x0: float = 0.0125 * s2
		var x1: float = 0.034 * s2
		Props.block(_vise, Vector3(minf(x0, x1), -0.075, -0.15), Vector3(maxf(x0, x1), 0.012, -0.06), "machine_green")
		Props.block(_vise, Vector3(minf(x0, x0 + 0.004 * s2), -0.03, -0.148), Vector3(maxf(x0, x0 + 0.004 * s2), 0.013, -0.062), "leather")
	Props.strut(_vise, Vector3(0.034, -0.03, -0.105), Vector3(0.16, -0.03, -0.105), 0.01, "steel", true)
	Props.strut(_vise, Vector3(0.16, -0.09, -0.105), Vector3(0.16, 0.03, -0.105), 0.008, "steel", true)
	for k: int in 3:
		Props.obox(_benchtop, Vector3(-0.25 + k * 0.03, -0.305, 0.22), Vector3(0.008, 0.008, 0.14), "steel", Vector3(0, 12 - k * 9, 0))
	Props.cyl(_benchtop, Vector3(0.3, -0.26, 0.28), 0.04, 0.1, "red_paint")
	_cradle = Node3D.new()
	root.add_child(_cradle)
	_pivot = Node3D.new()
	root.add_child(_pivot)
	var key: SpotLight3D = SpotLight3D.new()
	_key = key
	key.light_color = Color(1.0, 0.78, 0.5)
	key.light_energy = 6.0
	key.spot_range = 3.0
	key.spot_angle = 38.0
	key.shadow_enabled = true
	key.position = Vector3(0.3, 0.6, 0.25)
	root.add_child(key)
	key.look_at(Vector3(0, 0, 0.05), Vector3.UP)
	var rim: OmniLight3D = OmniLight3D.new()
	rim.light_color = Color(0.55, 0.62, 0.8)
	rim.light_energy = 0.5
	rim.omni_range = 2.5
	rim.position = Vector3(-0.5, 0.25, -0.4)
	root.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_cam.near = 0.02
	root.add_child(_cam)
	_cam.current = true


func _rebuild_gun() -> void:
	var w: WeaponInstance = _pistol()
	if w == null:
		return
	var t: WeaponInstance = WeaponInstance.create(w.id)
	t.tier = w.tier
	t.kit = w.kit.duplicate()
	t.finish = w.finish
	if _preview != "":
		t.kit[_slot] = _preview
	t.refresh_kit()
	var sig: String = String(t.id) + t.kit_sig()
	if sig == _built_sig and _gun != null:
		return
	_built_sig = sig
	if _gun != null:
		_gun.queue_free()
	var camo: StringName = &"" if t.upgraded else ProfileSave.camo_for(t.base_id())
	_gun = WeaponModels.build(t.base_id(), t.upgraded, camo, WeaponKitModels.look_of(t))
	_pivot.add_child(_gun)
	for n: Node in _gun.find_children("*", "OmniLight3D", true, false):
		(n as OmniLight3D).omni_range = 0.5
	var kf: Node3D = _gun.get_node_or_null("KitFlash") as Node3D
	if kf != null:
		kf.hide()
	if t.weapon_class() != &"pistol":
		_frame_long_gun()
		return
	_vise.show()
	_benchtop.position = Vector3.ZERO
	for c: Node in _cradle.get_children():
		c.queue_free()
	_key.position = Vector3(0.3, 0.6, 0.25)
	_key.spot_angle = 38.0
	_key.look_at(Vector3(0, 0, 0.05), Vector3.UP)
	# frame the whole gun: from the muzzle to the end of the stock / the bottom of the drum
	var front: float = absf((_gun.get_node("Muzzle") as Node3D).position.z)
	var back: float = 0.43 if t.kit.get("grip", "") == "stock" else 0.1
	_gun_len = front + back
	_pivot.position = Vector3(0, 0, (back - front) * 0.5 + 0.0)
	_gun.position = -_pivot.position
	_orbit = clampf(0.3 + _gun_len * 0.8, 0.42, 1.0)


## A long gun lies level in two padded rests on the bench (no vise): the top is lowered under its lowest part (a
## drum, a bipod's feet), each rest reaches up to the gun's underside where it stands (one under the fore-end, one
## under the butt or receiver), and the camera and lamp pull back to take in the whole length.
func _frame_long_gun() -> void:
	_vise.hide()
	for c: Node in _cradle.get_children():
		c.queue_free()
	var a: AABB = WeaponKitModels.bounds(_gun)
	_gun_len = a.size.z
	var mid: float = a.get_center().z
	_pivot.position = Vector3(0, 0, mid)
	_gun.position = -_pivot.position
	var top_y: float = a.position.y - 0.015
	_benchtop.position = Vector3(0, top_y + 0.31, 0)   # its top face sits at -0.31 in its own frame
	for f: float in [0.28, 0.78]:
		var z: float = lerpf(a.position.z, a.end.z, f)
		var under: float = WeaponKitModels.underside(_gun, z - 0.025, z + 0.025)
		if under == INF:
			continue
		var y1: float = under - 0.002
		Props.block(_cradle, Vector3(-0.035, top_y, z - mid - 0.03), Vector3(0.035, y1 - 0.012, z - mid + 0.03), "furniture")
		for s: float in [-1.0, 1.0]:
			Props.block(_cradle, Vector3(minf(s * 0.012, s * 0.04), y1 - 0.014, z - mid - 0.03), Vector3(maxf(s * 0.012, s * 0.04), y1 + 0.012, z - mid + 0.03), "leather")
	_orbit = clampf(0.3 + _gun_len * 0.75, 0.42, 1.9)
	_key.position = Vector3(0.45, 0.95, 0.35)
	_key.spot_angle = 55.0
	_key.spot_range = 4.0
	_key.look_at(Vector3(0, a.get_center().y, 0), Vector3.UP)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.downed or _pistol() == null \
			or GameState.phase != GameState.Phase.PLAYING:
		queue_free()
		return
	_orbit_t += delta
	var a: float = orbit_phase + _orbit_t * 0.32
	var c: Vector3 = _pivot.position + Vector3(0, -0.035, 0)
	_cam.position = c + Vector3(sin(a) * _orbit, 0.1 + 0.04 * sin(a * 0.7), cos(a) * _orbit)
	_cam.look_at(c, Vector3.UP)


var _orbit_t: float = 0.0
## Where the orbit starts (radians; -PI/2 = the pistol's left side, the side the viewmodel shows).
var orbit_phase: float = -1.75


# ================================================================== refresh

func _refresh() -> void:
	var w: WeaponInstance = _pistol()
	if w == null:
		return
	_refresh_scrip()
	for c: Node in _slots_box.get_children():
		c.queue_free()
	for slot: Variant in WeaponKit.slot_order(w):
		var s: String = str(slot)
		var b: Button = MenuKit.button(("> " if s == _slot else "") + WeaponKit.slot_name(w, s), _pick_slot.bind(s), 15)
		b.custom_minimum_size = Vector2(104, 34)
		_slots_box.add_child(b)
	for c2: Node in _opts_box.get_children():
		c2.queue_free()
	_opt_buttons.clear()
	var first: Button = null
	for row: Dictionary in ArmorersBench.options_for(player):
		if str(row["slot"]) != _slot:
			continue
		var opt: String = str(row["option"])
		var code: String = str(row["reason"])
		var tag: String = "FITTED" if bool(row["installed"]) else ("%d" % int(row["price"]))
		var name: String = str(row["name"])
		if code == "needs_power":
			name = "Under the counter..."
			tag = "LOCKED"
		var txt: String = "%-30s %8s" % [name, tag]
		var b2: Button = MenuKit.button(("> " if opt == _preview else "  ") + txt, _pick_option.bind(opt), 18)
		_opt_buttons[opt] = [b2, txt]
		b2.custom_minimum_size = Vector2(0, 34)
		if code == "needs_power" or code == "refused":
			b2.modulate = Color(0.6, 0.6, 0.6)
		elif code == "no_scrip":
			b2.modulate = Color(1.0, 0.75, 0.7)
		b2.focus_entered.connect(_pick_option.bind(opt, false))
		b2.mouse_entered.connect(_pick_option.bind(opt, false))
		_opts_box.add_child(b2)
		if first == null or opt == _preview:
			first = b2
	if _preview == "":
		_preview = _first_option()
	_refresh_option()
	if first != null and not first.has_focus():
		first.grab_focus.call_deferred()


func _refresh_scrip() -> void:
	if _scrip != null and player != null:
		_scrip.text = "SCRIP  %d" % Economy.get_scrip(player.player_id)


func _first_option() -> String:
	var opts: Array = WeaponKit.options(_pistol(), _slot)
	return str(opts[0]) if not opts.is_empty() else ""


func _refresh_option() -> void:
	var w: WeaponInstance = _pistol()
	if w == null:
		return
	var row: Dictionary = {}
	for r: Dictionary in ArmorersBench.options_for(player):
		if str(r["slot"]) == _slot and str(r["option"]) == _preview:
			row = r
	var code: String = str(row.get("reason", ""))
	if code == "needs_power":
		_title_opt.text = "UNDER THE COUNTER"
		_desc.text = str(WeaponKit.option_def(w, _slot, _preview).get("locked_text", WeaponKit.reason_text(code)))
	else:
		_title_opt.text = str(row.get("name", "")).to_upper()
		_desc.text = str(row.get("desc", ""))
	var now: Dictionary = WeaponKit.stats(w)
	var then: Dictionary = WeaponKit.stats(w, _slot, _preview) if code != "needs_power" else now
	for k: String in _bars.keys():
		var sb: StatBar = _bars[k][0]
		var val: Label = _bars[k][1]
		sb.cur = float((now[k] as Dictionary)["value"])
		sb.prev = float((then[k] as Dictionary)["value"])
		sb.queue_redraw()
		var a: String = str((now[k] as Dictionary)["text"])
		var b: String = str((then[k] as Dictionary)["text"])
		val.text = a if a == b else "%s > %s" % [a, b]
	if bool(row.get("installed", false)):
		_buy.text = "FITTED"
		_buy.disabled = true
	elif code == "needs_power" or code == "refused":
		_buy.text = WeaponKit.reason_text(code).to_upper()
		_buy.disabled = true
	else:
		var replacing: String = str(w.kit.get(_slot, ""))
		_buy.text = "BUY  %d%s" % [int(row.get("price", 0)), ("   (replaces %s)" % WeaponKit.option_name(w, _slot, replacing, w.upgraded)) if replacing != "" else ""]
		_buy.disabled = false
	var lines: PackedStringArray = []
	for d: Dictionary in WeaponKit.describe(w):
		lines.append("%-16s %s" % [str(d["slot_name"]).to_upper(), str(d["name"])])
	_fitted.text = "%s    %s\n%s" % [w.display_name(), "FINISH: " + str(M1911Kit.finish_def(w.finish).get("name", "Service")) if w.finish != &"" else "", "\n".join(lines)]
	_rebuild_gun()


func _pick_slot(slot: String) -> void:
	if slot == _slot:
		return
	_slot = slot
	_preview = ""
	AudioDirector.play_2d("ui_click", -4.0, 0.0)
	_refresh()


func _pick_option(option: String, sound: bool = true) -> void:
	if option == _preview:
		return
	_preview = option
	if sound:
		AudioDirector.play_2d("ui_click", -6.0, 0.0)
	for o: Variant in _opt_buttons.keys():
		var e: Array = _opt_buttons[o]
		(e[0] as Button).text = ("> " if str(o) == option else "  ") + str(e[1])
	_refresh_option()


func _up() -> bool:
	var w: WeaponInstance = _pistol()
	return w != null and w.upgraded


func _on_buy() -> void:
	if _preview == "":
		return
	var res: Dictionary = ArmorersBench.buy(player, _slot, _preview)
	if bool(res["ok"]):
		_msg.text = "Fitted: %s  (-%d)" % [WeaponKit.option_name(_pistol(), _slot, _preview, _up()), int(res["price"])]
		_built_sig = "-"
	else:
		_msg.text = WeaponKit.reason_text(str(res["reason"]), _pistol())
	_refresh()


func _on_damaged(pid: int, _amount: float) -> void:
	if player != null and is_instance_valid(player) and pid == player.player_id:
		queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"crouch") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
		return
	var order: Array = WeaponKit.slot_order(_pistol())
	if order.is_empty():
		return
	var i: int = order.find(_slot)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var kc: Key = (event as InputEventKey).keycode
		if kc == KEY_Q:
			_pick_slot(str(order[posmod(i - 1, order.size())]))
		elif kc == KEY_E:
			_pick_slot(str(order[posmod(i + 1, order.size())]))
	elif event is InputEventJoypadButton and event.is_pressed():
		var jb: JoyButton = (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_LEFT_SHOULDER:
			_pick_slot(str(order[posmod(i - 1, order.size())]))
		elif jb == JOY_BUTTON_RIGHT_SHOULDER:
			_pick_slot(str(order[posmod(i + 1, order.size())]))
		elif jb == JOY_BUTTON_X:
			_on_buy()


## A stat bar: the current value in paper, the previewed change in green (better) or red (worse) on top.
class StatBar extends Control:
	var cur: float = 0.0
	var prev: float = 0.0
	var lower_better: bool = false

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
		var lo: float = minf(cur, prev)
		draw_rect(Rect2(0, 1, w * lo, h - 2), Color(0.86, 0.82, 0.72))
		if absf(prev - cur) > 0.0005:
			var better: bool = (prev < cur) == lower_better
			var col: Color = Color(0.45, 0.85, 0.4) if better else Color(0.9, 0.3, 0.25)
			draw_rect(Rect2(w * lo, 1, w * absf(prev - cur), h - 2), col)
		for k: int in range(1, 10):
			draw_line(Vector2(w * k / 10.0, 0), Vector2(w * k / 10.0, h), Color(0, 0, 0, 0.35), 1.0)
