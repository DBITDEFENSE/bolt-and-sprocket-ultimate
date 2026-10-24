class_name LorePlaque
extends Interactable
## A small brass plate you can read (DECISIONS T-075): a perk machine's maker's plate at its base, the Crucible's
## "MOD. R-E · PAT. PEND. BLZ-40417" plate on its feed door. Hold Use: a reader opens with the map's entry from
## MachineLore (why this machine is here, who made it, what is in it) and the first read files it in the Intel
## Archive. Built at runtime by PerkMachine and Crucible as a child, its thin interact box standing just in front of
## the owner's own, low down, so looking at the plate selects it and looking at the machine still buys.
## Free, works without power, personal (net_local), humans only (bots never read).

## MachineLore entry key: "perk.<perk_id>" or "crucible".
var lore_key: String = ""
## What the prompt calls it.
var noun: String = "the maker's plate"
## Optional visible plate (the Crucible's): text drawn on a brass plate at this node's origin.
var plate_text: String = ""
var plate_size: Vector2 = Vector2(0.5, 0.16)


func _ready() -> void:
	super._ready()
	add_to_group(&"lore_plaques")


func build_greybox() -> void:
	if plate_text == "":
		return
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.66, 0.53, 0.28)
	m.metallic = 0.75
	m.roughness = 0.4
	var plate: MeshInstance3D = add_box(self, Vector3(plate_size.x, plate_size.y, 0.012), Vector3.ZERO, m)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l: Label3D = add_label(self, plate_text, Vector3(0, 0, -0.008), 18, Color(0.18, 0.12, 0.05, 1.0))
	l.pixel_size = 0.0016
	l.outline_size = 0


func has_entry() -> bool:
	return not MachineLore.row(MachineLore.here(), lore_key).is_empty()


func get_prompt(player: Player) -> String:
	if player == null or player.is_bot or not has_entry():
		return ""
	var line: String = MachineLore.plate(MachineLore.here(), lore_key)
	return "Hold [%s] to read %s%s" % [prompt_key(&"interact"), noun, ("\n" + line) if line != "" else ""]


func can_interact(player: Player) -> bool:
	return player != null and not player.is_bot and has_entry()


func hold_time(_player: Player) -> float:
	return 0.35


func net_local() -> bool:
	return true   # reading is personal


func interact(player: Player) -> void:
	if can_interact(player) and player.is_local:
		MachineLore.open_for(player, lore_key)
