class_name CipherMachine
extends Interactable
## The SCHLÜSSELGERÄT HAFEN in the signal tower (Letzte Fahrt s2, UPDATE 10 contract C3, design section 2, DECISIONS
## T-153): a fictional rotor cipher machine with three lettered wheels (CipherWheel children: hold [interact] on a
## wheel to turn it a letter on) and a lever (this node: hold [interact] to pull). The pull submits the wheels to the
## quest's `sequence` step (target "cipher", inputs from the seeded `cipher_inputs`: the three radio groups' first
## letters in keying order). Right: the teletype prints the chart's depth mark and the curtain code. Wrong: the
## wheels spin back to A and the teletype prints FEHLER. Bots solve it through `bot_set(letter)` (the bot_task's
## input method) after their think delay. Co-op: the host decides; the wheels and the teletype mirror.

const QUEST: StringName = &"map02_letzte_fahrt"
const STEP: StringName = &"s2_cipher"
const ALPHABET: String = "ABCDEFGHJKLMNPRSTUVWXYZ"

var letters: Array = ["A", "A", "A"]
var solved: bool = false
var wrong_count: int = 0
var _wheels: Array[CipherWheel] = []
var _discs: Array[Label3D] = []
var _lever: Node3D
var _paper: Label3D


func _ready() -> void:
	# the lever's use box is the front panel under the wheels (its offset points the bots' stand point to the front)
	interact_size = Vector3(0.9, 0.25, 0.2)
	interact_offset = Vector3(0, 0.85, -0.42)
	super._ready()
	add_to_group(&"cipher_machines")
	for i: int in 3:
		var w: CipherWheel = CipherWheel.new()
		w.machine = self
		w.index = i
		w.name = "Wheel%d" % i
		w.position = Vector3(-0.3 + float(i) * 0.25, 0.0, 0.0)
		add_child(w)
		_wheels.append(w)
	GLBus.quest_step_completed.connect(func(q: StringName, s: StringName) -> void:
		if q == QUEST and s == STEP:
			_print_solution())


func build_greybox() -> void:
	var body: StandardMaterial3D = greybox_mat(Color(0.16, 0.18, 0.16))
	var brass: StandardMaterial3D = greybox_mat(Color(0.6, 0.47, 0.22))
	add_box(self, Vector3(1.4, 0.85, 0.7), Vector3(0, 0.42, 0), greybox_mat(Color(0.3, 0.24, 0.17)))   # the table
	add_box(self, Vector3(1.0, 0.28, 0.5), Vector3(0, 0.99, 0), body)
	for i: int in 3:
		var d: Label3D = add_label(self, "A", Vector3(-0.3 + float(i) * 0.25, 1.2, -0.05), 40, Color(0.95, 0.9, 0.7))
		d.rotation.x = deg_to_rad(-30.0)
		_discs.append(d)
		var disc: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.09
		cm.bottom_radius = 0.09
		cm.height = 0.05
		disc.mesh = cm
		disc.material_override = brass
		disc.rotation.z = PI * 0.5
		disc.position = Vector3(-0.3 + float(i) * 0.25, 1.17, 0.02)
		add_child(disc)
	_lever = Node3D.new()
	_lever.name = "Lever"
	_lever.position = Vector3(0.45, 0.8, -0.4)
	add_child(_lever)
	add_box(_lever, Vector3(0.04, 0.32, 0.04), Vector3(0, 0.16, 0), brass)
	add_box(_lever, Vector3(0.08, 0.08, 0.08), Vector3(0, 0.34, 0), greybox_mat(Color(0.5, 0.1, 0.08)))
	var plate: Label3D = add_label(self, "SCHLÜSSELGERÄT HAFEN", Vector3(0, 0.88, -0.36), 14, Color(0.9, 0.85, 0.7))
	plate.rotation.y = 0.0
	_paper = add_label(self, "", Vector3(0, 1.35, 0.2), 16, Color(0.1, 0.1, 0.1))
	_paper.modulate = Color(0.12, 0.1, 0.08)
	_paper.outline_modulate = Color(0.95, 0.92, 0.85)


## Pure (tested): the letter after `l` on a wheel (wraps; letters not on the wheel start at A).
static func next_letter(l: String) -> String:
	var i: int = ALPHABET.find(l)
	return ALPHABET[(i + 1) % ALPHABET.length()] if i >= 0 else "A"


## Pure (tested): does a wheel setting solve `inputs`?
static func solves(setting: Array, inputs: Array) -> bool:
	if setting.size() != inputs.size():
		return false
	for i: int in setting.size():
		if str(setting[i]) != str(inputs[i]):
			return false
	return true


## Pure (tested): the bot solver: from the radio groups it heard and the keying order, the wheel setting.
static func solve(roll: Dictionary) -> Array:
	var out: Array = []
	for rid: Variant in roll.get("order", []):
		out.append(str((roll.get("groups", {}) as Dictionary).get(str(rid), "A"))[0])
	return out


func get_prompt(_player: Player) -> String:
	if solved:
		return ""
	if not QuestManager.is_active(QUEST, STEP):
		return "The wheels are stiff with salt. (Listen to the radios first.)"
	return "Hold [%s] to pull the lever (%s)" % [prompt_key(&"interact"), " ".join(letters)]


func can_interact(_player: Player) -> bool:
	return not solved and QuestManager.is_active(QUEST, STEP)


func hold_time(_player: Player) -> float:
	return 0.8


## Turn wheel `i` one letter on (every peer; the host decides).
func turn(i: int) -> void:
	if solved or i < 0 or i > 2:
		return
	set_wheel(i, next_letter(str(letters[i])))
	AudioDirector.play_3d("cipher_wheel", global_position + Vector3.UP * 1.1, -6.0, 0.05)


func set_wheel(i: int, l: String) -> void:
	letters[i] = l
	if i < _discs.size():
		_discs[i].text = l


func interact(_player: Player) -> void:
	if not Net.is_authority() or solved:
		return
	pull()


## The lever: submit what the wheels say from where the step's progress stands (authority).
func pull() -> String:
	_lever_anim()
	Net.mirror(self, &"_lever_anim")
	var res: String = ""
	var start: int = int(QuestManager.progress(QUEST, STEP)) if QuestManager.progress(QUEST, STEP) is int else 0
	for i: int in range(start, 3):
		res = str(QuestManager.submit(&"cipher", str(letters[i])).get("result", ""))
		if res != "ok":
			break
	if res == "wrong":
		_wrong()
		Net.mirror(self, &"_wrong")
	return res


## The bots' input method (bot_task input.method): set the next wheel and submit it alone.
func bot_set(letter: String) -> String:
	if not Net.is_authority():
		return ""
	var idx: int = int(QuestManager.progress(QUEST, STEP)) if QuestManager.progress(QUEST, STEP) is int else 0
	idx = clampi(idx, 0, 2)
	set_wheel(idx, letter)
	Net.mirror(self, &"set_wheel", [idx, letter])
	AudioDirector.play_3d("cipher_wheel", global_position + Vector3.UP * 1.1, -6.0, 0.05)
	var res: String = str(QuestManager.submit(&"cipher", letter).get("result", ""))
	if idx == 2 or res == "done":
		_lever_anim()
		Net.mirror(self, &"_lever_anim")
	if res == "wrong":
		_wrong()
		Net.mirror(self, &"_wrong")
	return res


func _lever_anim() -> void:
	if _lever == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(_lever, "rotation:x", 0.9, 0.18)
	tw.tween_property(_lever, "rotation:x", 0.0, 0.4)
	AudioDirector.play_3d("last_round_click", global_position + Vector3.UP, -2.0, 0.0)


func _wrong() -> void:
	wrong_count += 1
	for i: int in 3:
		set_wheel(i, "A")
	if _paper != null:
		_paper.text = "FEHLER FEHLER FEHLER"
	AudioDirector.play_3d("teletype_print", global_position + Vector3.UP, -4.0, 0.0)


## Every peer: the teletype answers with the depth mark and the curtain code.
func _print_solution() -> void:
	solved = true
	var roll: Variant = QuestManager.random_value(QUEST, "cipher")
	var depth: String = "48 FADEN"
	var code: String = "????"
	if roll is Dictionary:
		depth = str((roll as Dictionary).get("depth", depth))
		code = str((roll as Dictionary).get("curtain", code))
	if _paper != null:
		_paper.text = "TIEFE %s\nVORHANG %s" % [depth, " ".join(code.split(""))]
	AudioDirector.play_3d("teletype_print", global_position + Vector3.UP, 0.0, 0.0)
	var t: Totenhafen = Totenhafen.of(get_tree())
	if t != null:
		t.banner("THE TELETYPE PRINTS\nDEPTH MARK %s   ·   CURTAIN %s" % [depth, " ".join(code.split(""))], 7.0)
	if Net.is_authority():
		GameState.set_flag(&"lf_cipher_done", true)


class CipherWheel:
	extends Interactable
	## One lettered rotor of the SCHLÜSSELGERÄT HAFEN: hold [interact] to turn it on a letter.
	var machine: CipherMachine
	var index: int = 0

	func _ready() -> void:
		interact_size = Vector3(0.2, 0.25, 0.25)
		interact_offset = Vector3(0, 1.17, 0)
		super._ready()

	func build_greybox() -> void:
		pass

	func get_prompt(_player: Player) -> String:
		if machine == null or machine.solved:
			return ""
		return "Hold [%s] to turn wheel %d (%s)" % [prompt_key(&"interact"), index + 1, str(machine.letters[index])]

	func can_interact(_player: Player) -> bool:
		return machine != null and not machine.solved

	func hold_time(_player: Player) -> float:
		return 0.18

	func repeats() -> bool:
		return true

	func interact(_player: Player) -> void:
		if machine == null or not Net.is_authority():
			return
		machine.turn(index)
		Net.mirror(machine, &"turn", [index])
