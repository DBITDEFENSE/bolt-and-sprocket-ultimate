class_name FinePrintPanel
extends Interactable
## The fine-print panel on the back of a Helvetia machine (T&C section 10.2 / 11.2; docs/JINGLES.md section 0.3):
## Vendelin's real terms of service, riveted where nobody looks. Walk round the cabinet and hold Use to read it.
## The first read files it in the Intel Archive as "panel.<perk_id>". Built by PerkMachine at its back.

var perk_id: StringName = &""
var width: float = 1.0


func _ready() -> void:
	interact_size = Vector3(width + 0.2, 1.3, 0.3)
	interact_offset = Vector3(0, 1.1, 0)
	super._ready()


func build_greybox() -> void:
	var plate: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(minf(0.62, width * 0.7), 0.8, 0.012)
	plate.mesh = bm
	plate.position = Vector3(0, 1.15, 0)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.52, 0.32)
	m.metallic = 0.7
	m.roughness = 0.45
	plate.material_override = m
	add_child(plate)
	var t: Label3D = Label3D.new()
	t.text = "HELVETIA AUTOMATEN AG\nCONDITIONS OF USE\n\n§1 ......................\n§2 ......................\n§3 ......................\n§4 ......................\n§5 ......................\n§6 ......................\n§7 ......................\n\n— V."
	t.font_size = 22
	t.pixel_size = 0.0022
	t.modulate = Color(0.16, 0.12, 0.07)
	t.outline_size = 0
	# the panel node's local -Z faces the reader (PerkMachine turns it round); Label3D faces +Z, so flip it
	t.position = Vector3(0, 1.15, -0.008)
	t.rotation.y = PI
	add_child(t)


func get_prompt(_player: Player) -> String:
	return "Hold [%s] to read the fine print" % prompt_key(&"interact")


func hold_time(_player: Player) -> float:
	return 0.35


func net_local() -> bool:
	return true   # reading is personal


func interact(player: Player) -> void:
	FinePrintReader.open_for(player, perk_id)
