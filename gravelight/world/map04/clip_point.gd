class_name ClipPoint
extends Interactable
## UPDATE 10 §3 (contract C6 `clip_points`, T-156): a tether post on the wing walk's catwalk. Hold 1 s to clip your
## harness's runner onto the rail: CLIPPED until you climb back in, fall or go down (WingWalk's state machine; the
## hold runs on the host, which owns the state and mirrors it). Group "clip_points".

@export var clip_hold: float = 1.0


func _ready() -> void:
	interact_size = Vector3(1.4, 1.8, 1.4)
	interact_offset = Vector3(0, 0.9, 0)
	super._ready()
	add_to_group(&"clip_points")


func build_greybox() -> void:
	Props.cyl(self, Vector3(0, 0.55, 0), 0.05, 1.1, "iron")
	Props.cyl(self, Vector3(0, 1.12, 0), 0.09, 0.03, "brass")
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = Vector3(0, 1.25, 0)
	lamp.light_color = Color(1.0, 0.75, 0.3)
	lamp.light_energy = 0.35
	lamp.omni_range = 2.2
	lamp.shadow_enabled = false
	add_child(lamp)
	var l: Label3D = add_label(self, "EINHAKEN", Vector3(0, 1.4, 0), 12, Color(1.0, 0.85, 0.5))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func _ww() -> WingWalk:
	return get_tree().get_first_node_in_group(&"wing_walks") as WingWalk


func get_prompt(player: Player) -> String:
	var ww: WingWalk = _ww()
	if ww == null or not ww.is_open or player == null:
		return ""
	if ww.is_clipped(player.player_id):
		return "Clipped to the tether rail"
	return "Hold [%s] to clip in" % prompt_key(&"interact")


func can_interact(player: Player) -> bool:
	var ww: WingWalk = _ww()
	return ww != null and ww.is_open and player != null and player.is_alive() and not ww.is_clipped(player.player_id)


func hold_time(_player: Player) -> float:
	return clip_hold


func interact(player: Player) -> void:
	var ww: WingWalk = _ww()
	if ww != null and Net.is_authority() and can_interact(player):
		ww.clip(player)
