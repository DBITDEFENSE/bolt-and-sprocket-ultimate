class_name TrialOffer
extends Interactable
## The Account Manager's trial (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.7, T-113): in her RENEWAL phase a
## violet tray appears by the console: hold Use and every tonic is yours for `offer_seconds`, after which "the trial
## has ended" and the taker's perks are all stripped (what you had too: that is the trial). Taking it is faster now
## and worse later; bots never take it; refusing costs nothing.

var manager: Node3D = null
var taken: Array[int] = []


func _ready() -> void:
	interact_size = Vector3(1.6, 1.6, 1.2)
	interact_offset = Vector3(0, 0.8, 0)
	super._ready()
	add_to_group(&"trial_offer")


func build_greybox() -> void:
	Props.cyl(self, Vector3(0, 0.5, 0), 0.45, 1.0, "machine_grey")
	Props.cyl(self, Vector3(0, 1.02, 0), 0.6, 0.04, "nachtglas")
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		Props.cyl(self, Vector3(cos(a) * 0.38, 1.16, sin(a) * 0.38), 0.05, 0.22, "glass")
	var l: OmniLight3D = OmniLight3D.new()
	l.position = Vector3(0, 1.4, 0)
	l.light_color = Color(0.62, 0.3, 1.0)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.shadow_enabled = false
	add_child(l)
	var lb: Label3D = add_label(self, "A TRIAL OF EVERYTHING\nno obligation", Vector3(0, 1.6, 0), 18, Color(0.85, 0.6, 1.0, 0.95))
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func get_prompt(player: Player) -> String:
	if player == null or player.is_bot:
		return ""
	if taken.has(player.player_id):
		return "The trial runs. There's never any obligation."
	return "Hold [%s] to accept the trial: every tonic, for a minute. It ends." % prompt_key(&"interact")


func can_interact(player: Player) -> bool:
	return player != null and not player.is_bot and not taken.has(player.player_id)


func hold_time(_player: Player) -> float:
	return 1.0


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	taken.append(player.player_id)
	if manager != null and is_instance_valid(manager) and manager.has_method("accept_trial"):
		manager.call("accept_trial", player.player_id)
