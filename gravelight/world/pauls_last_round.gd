class_name PaulsLastRound
extends Interactable
## PAUL'S LAST ROUND (HB2, docs/HOMAGE_BOSSES.md section 5.7; WEAPONS.md section 23.3; DECISIONS T-159): a battered
## Ironhide bottle left at his body, one per player (section 13 D7: Paul wouldn't leave anybody out). Only its own
## player can drink it. Drinking gives Ironhide Stout free, without using a perk slot, until you're downed
## (PerkManager.grant_slotless); if you already have Ironhide you get a one-time +100 overshield instead
## (PerkManager.add_overshield).

var for_player: int = 1
var overshield: float = 100.0
var drunk: bool = false
var effect_given: String = ""


func build_greybox() -> void:
	interact_size = Vector3(0.8, 1.0, 0.8)
	var v: Node3D = Node3D.new()
	v.name = "Greybox"
	add_child(v)
	var glass: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.06
	cm.height = 0.24
	glass.mesh = cm
	glass.material_override = HomageBoss.mat(Color(0.3, 0.16, 0.08), 0.0, 0.25)
	glass.position = Vector3(0, 0.12, 0)
	glass.rotation.z = 0.25   # battered, leaning
	v.add_child(glass)
	var label: MeshInstance3D = MeshInstance3D.new()
	var lm: CylinderMesh = CylinderMesh.new()
	lm.top_radius = 0.061
	lm.bottom_radius = 0.061
	lm.height = 0.08
	label.mesh = lm
	label.material_override = HomageBoss.mat(Color(0.65, 0.15, 0.1), 0.6)
	label.position = Vector3(0, 0.12, 0)
	label.rotation.z = 0.25
	v.add_child(label)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.25)
	glow.omni_range = 1.6
	glow.light_energy = 0.8
	glow.shadow_enabled = false
	glow.position = Vector3(0, 0.3, 0)
	v.add_child(glow)


func get_prompt(player: Player) -> String:
	if drunk or player == null:
		return ""
	if player.player_id != for_player:
		return "PAUL'S LAST ROUND (not yours)"
	return "Hold [%s] to drink PAUL'S LAST ROUND" % prompt_key(&"interact")


func can_interact(player: Player) -> bool:
	return not drunk and player != null and player.player_id == for_player


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	drink(player.player_id)


## Free Ironhide (no slot, until downed) or the +100 overshield. Returns which.
func drink(pid: int) -> String:
	if drunk:
		return effect_given
	drunk = true
	effect_given = Paul.last_round_effect(PerkManager.has_perk(pid, &"ironhide_stout"))
	if effect_given == "ironhide":
		PerkManager.grant_slotless(pid, &"ironhide_stout")
	else:
		PerkManager.add_overshield(pid, overshield)
	AudioDirector.play_3d("perk_drink" if AudioDirector.has_sound("perk_drink") else "door_open", global_position + Vector3.UP, 0.0)
	print("[paul] player %d drinks PAUL'S LAST ROUND: %s" % [pid, effect_given])
	queue_free()
	return effect_given
