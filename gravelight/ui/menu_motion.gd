class_name MenuMotion
extends RefCounted
## T-267: every menu animation in one place (the owner: "it needs to have like better animations"). Screens and
## widgets call these; nothing else in gravelight/ui builds a menu tween of its own.
##   slide_in / slide_out   a screen or a column arrives / leaves: a cross-fade with a short slide
##   stagger                the rows of a list fade in one after another
##   feedback               hover / focus / press on any button: a soft highlight, an underline that grows from the
##                          left, a flash on the press, a quiet tick when the focus moves
##   zoom                   a picture inside a clipped frame leans in while its card has the focus (map cards)
##   pulse                  one short swell of a value just chosen
##   glide                  a mark moves to another spot (the ring on the war map, T-270)
##   finish                 ends whatever is still running on a control at once (a second press skips the motion)
## Rules: nothing here ever blocks input (a control is usable from its first frame, faded or not); the longest path
## from a press to a settled screen is SCREEN_S + STAGGER_MAX_S, under a quarter of a second; and with the
## "Reduce motion" setting (Settings > Accessibility, GLSettings.values["reduce_motion"]) slides, zooms, pulses and
## staggers are off and only a REDUCED_FADE_S fade is left.
## Everything works on Controls inside containers: only modulate, and children that sit in no container, are moved
## (a Container resets its children's scale and position whenever it sorts).

const SCREEN_S: float = 0.2
const OUT_S: float = 0.12
const SLIDE_PX: float = 24.0
const STAGGER_STEP_S: float = 0.022
const STAGGER_MAX_S: float = 0.14
const ITEM_S: float = 0.1
const HOVER_S: float = 0.11
const REDUCED_FADE_S: float = 0.06
const META_TWEEN: StringName = &"_menu_motion_tween"
const META_FX: StringName = &"_menu_motion_fx"

## Tests: 1 = reduced, 0 = full, -1 = the setting.
static var force_reduced: int = -1


static func reduced() -> bool:
	if force_reduced >= 0:
		return force_reduced == 1
	return bool(GLSettings.values.get("reduce_motion", false))


## How long a motion of `secs` takes with the setting applied (pure given `is_reduced`).
static func duration(secs: float, is_reduced: bool) -> float:
	return minf(secs, REDUCED_FADE_S) if is_reduced else secs


## How far a slide of `px` goes (0 with reduced motion).
static func distance(px: float, is_reduced: bool) -> float:
	return 0.0 if is_reduced else px


## When row `i` of `n` starts fading in: STAGGER_STEP_S apart, the whole list inside STAGGER_MAX_S (pure).
static func stagger_delay(i: int, n: int, is_reduced: bool = false) -> float:
	if is_reduced or n <= 1 or i <= 0:
		return 0.0
	var step: float = minf(STAGGER_STEP_S, STAGGER_MAX_S / float(n - 1))
	return step * float(mini(i, n - 1))


## The longest a screen change can take from the press until everything has settled (pure; test_menu_rework holds it
## under 0.25 s).
static func worst_case_s(rows: int) -> float:
	return maxf(SCREEN_S, stagger_delay(rows - 1, rows) + ITEM_S)


static func _tween(c: Node, key: StringName = META_TWEEN) -> Tween:
	_kill(c, key)
	var tw: Tween = c.create_tween()
	c.set_meta(key, tw)
	return tw


static func _kill(c: Node, key: StringName = META_TWEEN) -> void:
	if c.has_meta(key):
		var old: Variant = c.get_meta(key)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		c.remove_meta(key)


## A screen or column comes in from `dir` (1 = from the right, -1 = from the left). The control must not sit in a
## container (the container would put it back).
static func slide_in(c: Control, dir: float = 1.0, secs: float = SCREEN_S, px_off: float = SLIDE_PX) -> void:
	if c == null or not c.is_inside_tree():
		return
	var r: bool = reduced()
	var home: Vector2 = c.get_meta(&"_menu_motion_home", c.position)
	c.set_meta(&"_menu_motion_home", home)
	c.modulate.a = 0.0
	c.position = home + Vector2(distance(px_off, r) * dir, 0.0)
	var tw: Tween = _tween(c).set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration(secs, r))
	tw.tween_property(c, "position", home, duration(secs, r))


## The reverse; `done` runs when it has gone.
static func slide_out(c: Control, done: Callable = Callable(), dir: float = -1.0, secs: float = OUT_S, px_off: float = SLIDE_PX) -> void:
	if c == null or not c.is_inside_tree():
		if done.is_valid():
			done.call()
		return
	var r: bool = reduced()
	var tw: Tween = _tween(c).set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 0.0, duration(secs, r))
	tw.tween_property(c, "position", c.position + Vector2(distance(px_off, r) * dir, 0.0), duration(secs, r))
	if done.is_valid():
		tw.chain().tween_callback(done)


## A plain fade to `alpha`.
static func fade(c: CanvasItem, alpha: float, secs: float = SCREEN_S, done: Callable = Callable()) -> void:
	if c == null or not c.is_inside_tree():
		if done.is_valid():
			done.call()
		return
	var tw: Tween = _tween(c, &"_menu_motion_fade")
	tw.tween_property(c, "modulate:a", alpha, duration(secs, reduced()))
	if done.is_valid():
		tw.tween_callback(done)


## The direct children of `parent` fade in one after another (the first `limit`; the rest are simply there).
static func stagger(parent: Node, limit: int = 16) -> void:
	if parent == null or not parent.is_inside_tree() or reduced():
		return
	var rows: Array[CanvasItem] = []
	for ch: Node in parent.get_children():
		var ci: CanvasItem = ch as CanvasItem
		if ci != null and ci.visible:
			rows.append(ci)
		if rows.size() >= limit:
			break
	for i: int in rows.size():
		var row: CanvasItem = rows[i]
		row.modulate.a = 0.0
		var tw: Tween = _tween(row, &"_menu_motion_stagger")
		tw.tween_interval(stagger_delay(i, rows.size()))
		tw.tween_property(row, "modulate:a", 1.0, ITEM_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Ends every motion still running on `c` and its children at once, at its end state (a second press).
static func finish(c: Node) -> void:
	if c == null:
		return
	for key: StringName in [META_TWEEN, &"_menu_motion_fade", &"_menu_motion_stagger"]:
		if c.has_meta(key):
			var tw: Variant = c.get_meta(key)
			if tw is Tween and (tw as Tween).is_valid():
				(tw as Tween).custom_step(10.0)
				(tw as Tween).kill()
			c.remove_meta(key)
	for ch: Node in c.get_children():
		if ch.has_meta(&"_menu_motion_stagger"):
			var tw2: Variant = ch.get_meta(&"_menu_motion_stagger")
			if tw2 is Tween and (tw2 as Tween).is_valid():
				(tw2 as Tween).kill()
			ch.remove_meta(&"_menu_motion_stagger")
			(ch as CanvasItem).modulate.a = 1.0


## Hover / focus / press feedback on a button: a highlight over it, an underline growing from the left and a flash on
## the press, with a quiet tick when the focus arrives (`tick` false for widgets that play their own). Safe to call
## twice. The two rects are children of the button that take no input; a Button lays out no children, so nothing
## moves them.
static func feedback(b: BaseButton, accent: Color = Color(0.95, 0.86, 0.55), tick: bool = true) -> void:
	if b == null or b.has_meta(META_FX):
		return
	var hl: ColorRect = ColorRect.new()
	hl.name = "FxHighlight"
	hl.color = Color(accent.r, accent.g, accent.b, 1.0)
	hl.modulate.a = 0.0
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(hl, false, Node.INTERNAL_MODE_BACK)
	var ul: ColorRect = ColorRect.new()
	ul.name = "FxUnderline"
	ul.color = accent
	ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ul.anchor_left = 0.0
	ul.anchor_right = 1.0
	ul.anchor_top = 1.0
	ul.anchor_bottom = 1.0
	ul.offset_top = -2.0
	ul.offset_bottom = 0.0
	ul.scale = Vector2(0.0, 1.0)
	b.add_child(ul, false, Node.INTERNAL_MODE_BACK)
	b.set_meta(META_FX, [hl, ul])
	var lit: Callable = func(on: bool) -> void:
		if not b.is_inside_tree():
			return
		var want: bool = on and not b.disabled
		var r: bool = reduced()
		var tw: Tween = _tween(b, &"_menu_motion_hover").set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(hl, "modulate:a", 0.09 if want else 0.0, duration(HOVER_S, r))
		tw.tween_property(ul, "scale:x", 1.0 if want else 0.0, duration(HOVER_S, r))
	b.focus_entered.connect(func() -> void:
		lit.call(true)
		if tick and not MenuKit.is_quiet():
			AudioDirector.play_2d("ui_tick", -9.0, 0.05))
	b.focus_exited.connect(func() -> void: lit.call(b.is_hovered()))
	b.mouse_entered.connect(func() -> void: lit.call(true))
	b.mouse_exited.connect(func() -> void: lit.call(b.has_focus()))
	b.button_down.connect(func() -> void:
		if not b.is_inside_tree():
			return
		hl.modulate.a = 0.3
		var tw: Tween = _tween(b, &"_menu_motion_hover")
		tw.tween_property(hl, "modulate:a", 0.09 if (b.has_focus() or b.is_hovered()) else 0.0, duration(0.16, reduced())))


## A picture in a clipped frame leans in (`on`) or settles back: the map cards' preview. `pic` must sit in a plain
## Control, not a container.
static func zoom(pic: Control, on: bool, amount: float = 1.07) -> void:
	if pic == null or not pic.is_inside_tree():
		return
	var r: bool = reduced()
	pic.pivot_offset = pic.size * 0.5
	var to: float = amount if (on and not r) else 1.0
	var tw: Tween = _tween(pic, &"_menu_motion_zoom").set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(pic, "scale", Vector2(to, to), duration(0.22, r))


## A mark moves to `to` (T-270: the ring on the war map travels to the place under the focus); with Reduce motion it
## is simply there. `c` must sit in no container.
static func glide(c: Control, to: Vector2, secs: float = 0.18) -> void:
	if c == null:
		return
	if not c.is_inside_tree() or reduced():
		_kill(c)
		c.position = to
		return
	var tw: Tween = _tween(c).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", to, secs)


## One short swell (a value just changed, a card just chosen). `c` must sit in no container, or be a label whose
## container does not sort during the swell.
static func pulse(c: Control, amount: float = 1.08) -> void:
	if c == null or not c.is_inside_tree() or reduced():
		return
	c.pivot_offset = c.size * 0.5
	var tw: Tween = _tween(c, &"_menu_motion_pulse").set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2(amount, amount), 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN)
