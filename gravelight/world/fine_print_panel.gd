class_name FinePrintPanel
extends Interactable
## The fine-print panel on the back of a Helvetia machine (T&C section 10.2 / 11.2; docs/JINGLES.md section 0.3):
## Vendelin's real terms of service, riveted where nobody looks. Walk round the cabinet and hold Use to read it.
## The first read files it in the Intel Archive as "panel.<perk_id>". Built by PerkMachine at its back.

var perk_id: StringName = &""
var width: float = 1.0
## The read area's width when the drawn plate is narrower (a barrel's): the hold-to-read box stays the machine's.
var read_width: float = -1.0


func _ready() -> void:
	interact_size = Vector3((read_width if read_width > 0.0 else width) + 0.2, 1.3, 0.3)
	interact_offset = Vector3(0, 1.1, 0)
	super._ready()


func build_greybox() -> void:
	# 2026-11-12 (the owner's screenshot of the Inn vault: a plain beige slab standing beside Ironhide Stout): the plate
	# was one flat-coloured box held off the machine's back with nothing holding it. It is a riveted brass plate now
	# (the library's brass), a raised border, a rule under the heading, and two iron straps back to the cabinet; the
	# terms and the hold to read them are unchanged.
	var w: float = minf(0.62, width * 0.7)
	var h: float = 0.8
	var cy: float = 1.15
	var g: Node3D = Node3D.new()
	g.name = "Plate"
	add_child(g)
	Props.block(g, Vector3(-w * 0.5, cy - h * 0.5, -0.006), Vector3(w * 0.5, cy + h * 0.5, 0.006), "brass")
	var b: float = 0.022
	for fy: float in [cy - h * 0.5 + b * 0.5, cy + h * 0.5 - b * 0.5]:
		Props.block(g, Vector3(-w * 0.5, fy - b * 0.5, -0.011), Vector3(w * 0.5, fy + b * 0.5, -0.006), "brass")
	for fx: float in [-w * 0.5 + b * 0.5, w * 0.5 - b * 0.5]:
		Props.block(g, Vector3(fx - b * 0.5, cy - h * 0.5, -0.011), Vector3(fx + b * 0.5, cy + h * 0.5, -0.006), "brass")
	Props.block(g, Vector3(-w * 0.5 + 0.05, cy + h * 0.5 - 0.135, -0.0075), Vector3(w * 0.5 - 0.05, cy + h * 0.5 - 0.128, -0.006), "black_paint")
	for rv: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		Props.cyl(g, Vector3(rv.x * (w * 0.5 - 0.04), cy + rv.y * (h * 0.5 - 0.04), -0.012), 0.011, 0.006, "iron", Vector3(90, 0, 0))
	for sy: float in [cy - h * 0.5 + 0.1, cy + h * 0.5 - 0.1]:
		Props.block(g, Vector3(-w * 0.5 + 0.06, sy - 0.018, 0.006), Vector3(-w * 0.5 + 0.1, sy + 0.018, 0.1), "iron")
		Props.block(g, Vector3(w * 0.5 - 0.1, sy - 0.018, 0.006), Vector3(w * 0.5 - 0.06, sy + 0.018, 0.1), "iron")
	var t: Label3D = Label3D.new()
	t.text = "HELVETIA AUTOMATEN AG\nCONDITIONS OF USE\n\n§1 ......................\n§2 ......................\n§3 ......................\n§4 ......................\n§5 ......................\n§6 ......................\n§7 ......................\n\n— V."
	t.font_size = 22
	t.pixel_size = 0.0022 * w / 0.62   # (the terms fill a narrower plate too)
	t.modulate = Color(0.16, 0.12, 0.07)
	t.outline_size = 0
	# the panel node's local -Z faces the reader (PerkMachine turns it round); Label3D faces +Z, so flip it
	t.position = Vector3(0, 1.15, -0.0135)   # (in front of the plate's border)
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
