class_name BankCard
extends CanvasLayer
## T-136: the teller's window (BankCounter). Stays open for several moves; the player can't move while it is open
## (like Jakub's card). Keys: [interact] deposit a step, [jump] deposit all, [reload] withdraw a step, [melee]
## withdraw all, [crouch] / [pause] leave. Closes on its own when you are hurt or downed, when the match leaves
## play, or after card_idle_close_s without a move.

var player: Player
var branch: BankBranch
var _t: float = 0.0
var _idle: float = 0.0
var _done: bool = false
var _hp0: float = 0.0
var _v: VBoxContainer
var _bal: Label
var _pocket: Label
var _note: Label


func _init() -> void:
	layer = 25


func _ready() -> void:
	GameState.input_blocked = true
	_hp0 = player.hp if player != null else 0.0
	var font: Font = MenuKit.type_font()
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-400, -270)
	panel.custom_minimum_size = Vector2(800, 300)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.06, 0.94)
	sb.border_color = Color(0.85, 0.72, 0.38)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	MenuKit.apply_theme(panel)
	add_child(panel)
	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 7)
	panel.add_child(_v)
	_v.add_child(_label(str(branch.cfgb.get("title", "BANK")) if branch != null else "BANK", font, 26, Color(0.85, 0.72, 0.38)))
	_bal = _label("", font, 22, Color(0.95, 0.9, 0.75))
	_v.add_child(_bal)
	_pocket = _label("", font, 18, Color(0.8, 0.78, 0.7))
	_v.add_child(_pocket)
	_v.add_child(_label("Savings grow 1% every round you play, on any map, and stay in the bank between matches.", font, 15, Color(0.62, 0.62, 0.58)))
	var step: int = _step()
	_v.add_child(_label("[%s]  DEPOSIT %d     [%s]  DEPOSIT ALL" % [GLSettings.action_label(&"interact"), step, GLSettings.action_label(&"jump")], font, 20, Color(1.0, 0.82, 0.45)))
	_v.add_child(_label("[%s]  WITHDRAW %d     [%s]  WITHDRAW ALL" % [GLSettings.action_label(&"reload"), step, GLSettings.action_label(&"melee")], font, 20, Color(1.0, 0.82, 0.45)))
	_v.add_child(_label("[%s / %s]  LEAVE" % [GLSettings.action_label(&"crouch"), GLSettings.action_label(&"pause")], font, 18, Color(0.85, 0.85, 0.8)))
	_note = _label("", font, 16, Color(0.75, 0.85, 0.65))
	_v.add_child(_note)
	_refresh()


func _step() -> int:
	return int(BankAccount.cfg().get("step", 1000))


func _refresh() -> void:
	_bal.text = "In the bank:  ǂ %d" % BankAccount.balance()
	var rec: Dictionary = ProfileSave.profile.get("bank", {})
	_pocket.text = "In your pocket:  ǂ %d     ·     interest earned so far:  ǂ %d" % [Economy.get_scrip(player.player_id), int(rec.get("interest", 0))]


func _label(text: String, font: Font, size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font if size >= 20 else MenuKit.body_font())
	l.add_theme_font_size_override("font_size", MenuKit.px(size))
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	return l


## A move (also tools / tests): "deposit" / "deposit_all" / "withdraw" / "withdraw_all". The amount moved.
func move(kind: String) -> int:
	var pid: int = player.player_id
	var n: int = 0
	match kind:
		"deposit":
			n = BankAccount.deposit(pid, _step())
		"deposit_all":
			n = BankAccount.deposit(pid, Economy.get_scrip(pid))
		"withdraw":
			n = BankAccount.withdraw(pid, _step())
		"withdraw_all":
			n = BankAccount.withdraw(pid, BankAccount.balance())
	_idle = 0.0
	if n > 0:
		AudioDirector.play_2d("bank_till", -2.0)
		_note.text = ("Deposited ǂ %d." if kind.begins_with("deposit") else "Withdrew ǂ %d.") % n
		if branch != null:
			branch.say("BANK_DEPOSIT" if kind.begins_with("deposit") else "BANK_WITHDRAW")
	else:
		AudioDirector.play_2d("deny", -4.0)
		_note.text = "Nothing to deposit." if kind.begins_with("deposit") else "Nothing saved to take out."
		if branch != null:
			branch.say("BANK_BROKE")
	_refresh()
	return n


func _exit_tree() -> void:
	GameState.input_blocked = false


func _input(event: InputEvent) -> void:
	if _done or _t < 0.25:
		return
	var kind: String = ""
	if event.is_action_pressed(&"interact"):
		kind = "deposit"
	elif event.is_action_pressed(&"jump"):
		kind = "deposit_all"
	elif event.is_action_pressed(&"reload"):
		kind = "withdraw"
	elif event.is_action_pressed(&"melee"):
		kind = "withdraw_all"
	elif event.is_action_pressed(&"crouch") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	if kind != "":
		get_viewport().set_input_as_handled()
		move(kind)


func _process(delta: float) -> void:
	_t += delta
	_idle += delta
	if player != null and is_instance_valid(player):
		_hp0 = maxf(_hp0, player.hp)   # (health coming back is no hit)
	if player == null or not is_instance_valid(player) or player.downed or player.hp < _hp0 - 0.5 \
			or GameState.phase != GameState.Phase.PLAYING or _idle >= float(BankAccount.cfg().get("card_idle_close_s", 25.0)):
		close()


func close() -> void:
	if _done:
		return
	_done = true
	queue_free()
