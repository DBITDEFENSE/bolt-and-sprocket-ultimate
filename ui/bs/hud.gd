class_name BSHud
extends CanvasLayer
## Bolt & Sprocket HUD (updateHUD / updateUITimers / showBanner / showHint / comboHit / dlgSetLine,
## index.html:17098-17220, 4851, 11199), bright B&S style:
##   top-left   NANOTECH bar + "hp / max", JETPACK (hover) bar, SUPER meter (once owned; time left while running)
##   top-right  bolt counter with +delta pops, combo "N HITS" (2+ hits, fades with the combo)
##   top-centre boss name + health + BREAK meter (EventBus.boss_*)
##   centre     banners (title + sub); hints under them; low-HP / damage vignette
##   bottom     subtitles with speaker name in their colour (typewriter); interact prompt; weapon + ammo card
##   objective  label (set_objective(text, world_pos) shows "TEXT · 40m")
##   debug      FPS / enemy counters (console or the fps setting)
## Everything is event-driven through EventBus except the per-frame bars, read from `bolt`.

const TYPE_CPS: float = 46.0

var bolt: Bolt = null
var show_fps: bool = false
var show_enemies: bool = false
var objective_text: String = ""
var objective_pos: Vector3 = Vector3.INF
var last_subtitle: String = ""
var last_banner: String = ""
var last_hint: String = ""
var last_prompt: String = ""

var _root: Control
var _stats: Control
var _hp: ProgressBar
var _hp_text: Label
var _hover: ProgressBar
var _super_lbl: Label
var _super: ProgressBar
var _bolts: Label
var _pops: Control
var _combo: Label
var _combo_t: float = 0.0
var _boss: VBoxContainer
var _boss_name: Label
var _boss_hp: ProgressBar
var _boss_break: ProgressBar
var _banner: Label
var _banner_sub: Label
var _banner_t: float = 0.0
var _hint: Label
var _hint_t: float = 0.0
var _sub_box: PanelContainer
var _sub_name: Label
var _sub_text: Label
var _sub_t: float = 0.0
var _sub_shown: float = 0.0
var _prompt: Label
var _weapon: Label
var _ammo: Label
var _obj: Label
var _debug: Label
var _vignette: ColorRect
var _flash: float = 0.0
var _summary: PanelContainer = null


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS     # subtitles/banners keep animating while cutscenes pause the world
	_build()
	EventBus.bolts_changed.connect(_on_bolts)
	EventBus.combo_changed.connect(_on_combo)
	EventBus.player_damaged.connect(func(_a: float, _hp: float) -> void: _flash = 1.0)
	EventBus.boss_started.connect(_on_boss_started)
	EventBus.boss_health.connect(_on_boss_health)
	EventBus.boss_defeated.connect(func(_id: StringName) -> void: _boss.visible = false)
	EventBus.interact_prompt.connect(_on_prompt)
	EventBus.hint.connect(func(t: String, _k: String) -> void: show_hint(t))
	EventBus.banner.connect(show_banner)
	EventBus.subtitle.connect(show_subtitle)
	EventBus.weapon_changed.connect(_on_weapon)
	show_fps = bool(Settings.get_value("fps", false))
	_bolts.text = str(BS.bolts)
	_on_weapon(BS.current_weapon)


# ------------------------------------------------------------------ build

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_vignette = ColorRect.new()
	_vignette.color = Color(1, 0.1, 0.15, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)
	_stats = Control.new()
	_stats.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stats)
	# top-left vitals
	var vit: PanelContainer = _panel(BSStyle.CYAN)
	vit.position = Vector2(26, 22)
	_stats.add_child(vit)
	var vv: VBoxContainer = VBoxContainer.new()
	vit.add_child(vv)
	var hr: HBoxContainer = HBoxContainer.new()
	vv.add_child(hr)
	hr.add_child(BSStyle.label(BSText.text("html.hpLabel.001"), 18, BSStyle.GREEN, 4))
	_hp_text = BSStyle.label("100 / 100", 18, Color.WHITE, 4)
	_hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hr.add_child(_hp_text)
	_hp = BSStyle.bar(Color("#5eff8a"), 320, 20)
	vv.add_child(_hp)
	vv.add_child(BSStyle.label(BSText.text("html.hoverLabel.001"), 14, BSStyle.CYAN, 4))
	_hover = BSStyle.bar(BSStyle.CYAN, 320, 10)
	vv.add_child(_hover)
	_super_lbl = BSStyle.label(BSText.text("html.superLabel.001"), 14, BSStyle.ORANGE, 4)
	vv.add_child(_super_lbl)
	_super = BSStyle.bar(BSStyle.ORANGE, 320, 12)
	vv.add_child(_super)
	# top-right bolts + combo
	var bp: PanelContainer = _panel(BSStyle.YELLOW)
	bp.anchor_left = 1.0
	bp.anchor_right = 1.0
	bp.position = Vector2(1920 - 290, 22)
	bp.custom_minimum_size = Vector2(260, 0)
	_stats.add_child(bp)
	var bh: HBoxContainer = HBoxContainer.new()
	bp.add_child(bh)
	bh.add_child(BSStyle.label(BSText.text("bs.ui.hud.bolts"), 18, BSStyle.DIM, 4))
	_bolts = BSStyle.label("0", 34, BSStyle.YELLOW, 8)
	_bolts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bolts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bh.add_child(_bolts)
	_pops = Control.new()
	_pops.position = Vector2(1920 - 120, 80)
	_pops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_child(_pops)
	_combo = BSStyle.label("", 46, BSStyle.PINK, 10)
	_combo.position = Vector2(1920 - 290, 130)
	_combo.custom_minimum_size = Vector2(264, 0)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo.modulate.a = 0.0
	_stats.add_child(_combo)
	# boss bar
	_boss = VBoxContainer.new()
	_boss.position = Vector2(560, 24)
	_boss.custom_minimum_size = Vector2(800, 0)
	_boss.visible = false
	_stats.add_child(_boss)
	_boss_name = BSStyle.label(BSText.text("html.bossName.001"), 28, BSStyle.RED, 8)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss.add_child(_boss_name)
	_boss_hp = BSStyle.bar(BSStyle.RED, 800, 22)
	_boss.add_child(_boss_hp)
	var brk: HBoxContainer = HBoxContainer.new()
	_boss.add_child(brk)
	brk.add_child(BSStyle.label(BSText.text("html.bossBreakLbl.001"), 16, BSStyle.YELLOW, 4))
	_boss_break = BSStyle.bar(BSStyle.YELLOW, 700, 10)
	_boss_break.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_break.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brk.add_child(_boss_break)
	# objective
	_obj = BSStyle.label("", 20, BSStyle.CYAN, 5)
	_obj.position = Vector2(26, 250)
	_stats.add_child(_obj)
	# banners + hints (always visible, even in cutscenes)
	_banner = BSStyle.label("", 72, BSStyle.YELLOW, 14)
	_banner.position = Vector2(0, 300)
	_banner.size = Vector2(1920, 90)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_banner)
	_banner_sub = BSStyle.label("", 30, Color.WHITE, 8)
	_banner_sub.position = Vector2(0, 392)
	_banner_sub.size = Vector2(1920, 40)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_banner_sub)
	_hint = BSStyle.label("", 26, BSStyle.CYAN, 7)
	_hint.position = Vector2(260, 470)
	_hint.size = Vector2(1400, 40)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)
	# subtitles
	_sub_box = _panel(BSStyle.CYAN)
	_sub_box.position = Vector2(360, 1080 - 230)
	_sub_box.custom_minimum_size = Vector2(1200, 0)
	_sub_box.visible = false
	_root.add_child(_sub_box)
	var sv: VBoxContainer = VBoxContainer.new()
	_sub_box.add_child(sv)
	_sub_name = BSStyle.label("", 22, Color.WHITE, 6)
	sv.add_child(_sub_name)
	_sub_text = BSStyle.label("", 24, Color.WHITE, 4)
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_text.custom_minimum_size = Vector2(1170, 0)
	sv.add_child(_sub_text)
	# interact prompt
	_prompt = BSStyle.label("", 26, Color.WHITE, 8)
	_prompt.position = Vector2(0, 1080 - 330)
	_prompt.size = Vector2(1920, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_child(_prompt)
	# weapon card
	var wp: PanelContainer = _panel(BSStyle.YELLOW)
	wp.position = Vector2(1920 - 360, 1080 - 130)
	wp.custom_minimum_size = Vector2(330, 0)
	_stats.add_child(wp)
	var wv: VBoxContainer = VBoxContainer.new()
	wp.add_child(wv)
	_weapon = BSStyle.label("", 22, BSStyle.YELLOW, 5)
	wv.add_child(_weapon)
	_ammo = BSStyle.label("", 30, Color.WHITE, 6)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wv.add_child(_ammo)
	_debug = BSStyle.label("", 16, Color(0.7, 1, 0.7), 4)
	_debug.position = Vector2(1920 - 200, 1080 - 30)
	_root.add_child(_debug)


func _panel(rim: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", BSStyle.panel(rim))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# ------------------------------------------------------------------ events

func _on_bolts(total: int, delta: int) -> void:
	_bolts.text = str(total)
	if delta == 0:
		return
	var l: Label = BSStyle.label(("+%d" if delta > 0 else "%d") % delta, 26, BSStyle.YELLOW if delta > 0 else BSStyle.RED, 6)
	l.position = Vector2(0, _pops.get_child_count() * 6.0)
	_pops.add_child(l)
	var tw: Tween = l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 46.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _on_combo(hits: int) -> void:
	if hits >= 2:
		_combo.text = "%d %s" % [hits, BSText.text("html.comboLabel.001")]
		_combo.modulate.a = 1.0
		_combo_t = 1.4
		_combo.scale = Vector2(1.15, 1.15)
	elif hits == 0:
		_combo_t = minf(_combo_t, 0.2)


func _on_boss_started(_id: StringName, display_name: String) -> void:
	_boss_name.text = display_name
	_boss_hp.value = 1.0
	_boss_break.value = 0.0
	_boss.visible = true


func _on_boss_health(_id: StringName, frac: float, break_frac: float) -> void:
	_boss.visible = true
	_boss_hp.value = frac
	_boss_break.value = break_frac


func _on_prompt(text: String) -> void:
	last_prompt = text
	_prompt.text = text


func _on_weapon(id: StringName) -> void:
	_weapon.text = weapon_display_name(id)


func weapon_display_name(id: StringName) -> String:
	if id == &"":
		return ""
	if Data.has_table("bs/weapons"):
		var w: Dictionary = ((Data.table("bs/weapons") as Dictionary).get("weapons", {}) as Dictionary).get(String(id), {})
		if w.has("name"):
			return str(w["name"])
	return String(id).replace("_", " ").to_upper()


func show_banner(title: String, sub: String = "", seconds: float = 2.2) -> void:
	last_banner = title
	_banner.text = title
	_banner_sub.text = sub
	_banner_t = seconds
	_banner.modulate.a = 1.0
	_banner_sub.modulate.a = 1.0
	_banner.scale = Vector2(1.1, 1.1)


func show_hint(text: String) -> void:
	last_hint = text
	_hint.text = text
	_hint_t = 4.0
	_hint.modulate.a = 1.0


func show_subtitle(speaker: String, text: String, color: Color, seconds: float) -> void:
	last_subtitle = text
	if not bool(Settings.get_value("subtitles", true)):
		return
	_sub_name.text = speaker
	_sub_name.add_theme_color_override("font_color", color)
	_sub_text.text = text
	_sub_text.visible_characters = 0
	_sub_shown = 0.0
	_sub_t = seconds + 0.6
	_sub_box.add_theme_stylebox_override("panel", BSStyle.panel(color))
	_sub_box.visible = true


func set_objective(text: String, world_pos: Vector3 = Vector3.INF) -> void:
	objective_text = text
	objective_pos = world_pos


## Level-complete summary (completeLevel 17599): PLANET CLEAR! / bolts / gold / time + a menu button.
func show_summary(level_name: String, bolts: int, gold: String, time_s: float, on_continue: Callable) -> void:
	if _summary != null:
		_summary.queue_free()
	_summary = _panel(BSStyle.YELLOW)
	_summary.mouse_filter = Control.MOUSE_FILTER_STOP
	_summary.position = Vector2(660, 300)
	_summary.custom_minimum_size = Vector2(600, 0)
	_root.add_child(_summary)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_summary.add_child(v)
	v.add_child(BSStyle.label(BSText.text("html.complete.001"), 52, BSStyle.YELLOW, 10))
	v.add_child(BSStyle.label(level_name, 26, BSStyle.CYAN, 6))
	v.add_child(BSStyle.label("%s   %d" % [BSText.text("html.complete.002"), bolts], 24))
	v.add_child(BSStyle.label("%s   %s" % [BSText.text("html.complete.003"), gold], 24))
	v.add_child(BSStyle.label("%s   %d:%02d" % [BSText.text("html.complete.004"), int(time_s) / 60, int(time_s) % 60], 24))
	var b: Button = BSStyle.button(BSText.text("html.btnMap.001"))
	b.pressed.connect(on_continue)
	v.add_child(b)
	b.grab_focus.call_deferred()


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.1)
	_stats.visible = not BS.blocked() or _summary != null
	if bolt != null and is_instance_valid(bolt):
		_hp.value = clampf(bolt.hp / maxf(1.0, bolt.max_hp), 0.0, 1.0)
		_hp_text.text = "%d / %d" % [maxi(0, ceili(bolt.hp)), int(bolt.max_hp)]
		_hover.value = clampf(bolt.motor.hover, 0.0, 1.0)
		var low: float = 0.25 + sin(Time.get_ticks_msec() / 200.0) * 0.1 if (not BS.blocked() and bolt.hp < bolt.max_hp * 0.25 and not bolt.dead) else 0.0
		_flash = maxf(0.0, _flash - dt * 1.4)
		_vignette.color.a = maxf(_flash, low) * 0.35
		_update_ammo()
		_update_objective()
	_update_super()
	if _combo_t > 0.0:
		_combo_t -= dt
		_combo.scale = _combo.scale.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
		if _combo_t <= 0.0:
			_combo.modulate.a = 0.0
	if _banner_t > 0.0:
		_banner_t -= dt
		_banner.scale = _banner.scale.lerp(Vector2.ONE, minf(1.0, dt * 8.0))
		if _banner_t <= 0.0:
			_banner.modulate.a = 0.0
			_banner_sub.modulate.a = 0.0
	if _hint_t > 0.0:
		_hint_t -= dt
		if _hint_t <= 0.0:
			_hint.modulate.a = 0.0
	if _sub_t > 0.0:
		_sub_t -= dt
		_sub_shown = minf(float(_sub_text.text.length()), _sub_shown + dt * TYPE_CPS)
		_sub_text.visible_characters = int(_sub_shown)
		if _sub_t <= 0.0:
			_sub_box.visible = false
	var dbg: PackedStringArray = []
	if show_fps:
		dbg.append("%d FPS" % Engine.get_frames_per_second())
	if show_enemies:
		dbg.append("ENEMIES %d" % get_tree().get_nodes_in_group(&"enemies").filter(
			func(e: Node) -> bool: return not e.is_in_group(&"props") and e.has_method("is_alive") and e.call("is_alive")).size())
	_debug.text = "  ".join(dbg)


func _update_super() -> void:
	_super.visible = BS.super_owned
	_super_lbl.visible = BS.super_owned
	if not BS.super_owned:
		return
	var sp: Sprocket = get_tree().get_first_node_in_group(&"sprocket") as Sprocket
	var sup: SuperProtocol = sp.super_protocol if sp != null else null
	if sup != null and sup.active:
		_super_lbl.text = "SUPER %ds" % ceili(sup.t)
		_super.value = sup.t / float(sup.C["duration"])
	else:
		var ready: bool = BS.super_meter >= 1.0
		_super_lbl.text = ("SUPER (D-UP)!" if AimAssist.last_device == "pad" else "SUPER (T)!") if ready else "SUPER"
		_super.value = BS.super_meter
		_super.modulate = Color(1.3, 1.3, 1.3) if ready and int(Time.get_ticks_msec() / 150) % 2 == 0 else Color.WHITE


## Ammo readout: asks Bolt's "Weapons" node (weapons builder) for get_ammo(id) / get_ammo_cap(id) when it
## has them; otherwise falls back to BS.weapons[id].ammo_now. Infinite / heat weapons show nothing.
func _update_ammo() -> void:
	var id: StringName = BS.current_weapon
	if id == &"":
		_ammo.text = ""
		return
	var wm: Node = bolt.get_node_or_null("Weapons")
	var a: int = -1
	var cap: int = -1
	if wm != null and wm.has_method("get_ammo"):
		a = int(wm.call("get_ammo", id))
		cap = int(wm.call("get_ammo_cap", id)) if wm.has_method("get_ammo_cap") else -1
	else:
		a = int((BS.weapons.get(String(id), {}) as Dictionary).get("ammo_now", -1))
	if a < 0:
		_ammo.text = ""
		return
	_ammo.text = "%d / %d" % [a, cap] if cap > 0 else str(a)
	_ammo.add_theme_color_override("font_color", BSStyle.RED if a <= 2 and int(Time.get_ticks_msec() / 350) % 2 == 1 else Color.WHITE)


func _update_objective() -> void:
	if objective_text == "":
		_obj.text = ""
		return
	if objective_pos == Vector3.INF:
		_obj.text = "▸ " + objective_text
	else:
		_obj.text = "▸ %s · %dm" % [objective_text, roundi(bolt.global_position.distance_to(objective_pos))]
