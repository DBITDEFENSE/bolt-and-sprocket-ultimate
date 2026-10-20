class_name ShopKiosk
extends Node3D
## Blartz's kiosk for a landing pad (landingZone / updateInteract / doInteract, index.html:7991, 4319, 4345).
## The level builder instances it (ShopKiosk.new(), position it, add_child). Walk up and press interact:
##   - near the tip jar (1.7 m): drop 1 bolt in ("Tip Jar (1 bolt)", Blartz's tip lines in order)
##   - near the counter (3.4 m): opens the shop screen
##   - with `arrested` set (Core Foundry until the rescue): "BACK IN 5 MIN (ARRESTED)" + Sprocket's hint
## The interactable volume is on physics layer 5 (interactables) so the level's triggers can see it.

signal opened

const SHOP_RADIUS: float = 3.4
const JAR_RADIUS: float = 1.7

@export var arrested: bool = false:
	set(v):
		arrested = v
		var s: Label3D = get_node_or_null("Sign") as Label3D
		if s != null:
			s.text = _sign_text()
@export var jar_offset: Vector3 = Vector3(1.25, 1.05, 0.55)

var target: String = ""            # "", "shop", "tip"
var logic: ShopLogic
var _ui: Node = null


func _ready() -> void:
	add_to_group(&"interactables")
	add_to_group(&"shop_kiosk")
	logic = ShopLogic.new(get_tree())
	_build_visual()
	var area: Area3D = Area3D.new()
	area.collision_layer = 1 << 4
	area.collision_mask = 0
	area.monitoring = false
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: SphereShape3D = SphereShape3D.new()
	sh.radius = SHOP_RADIUS
	cs.shape = sh
	area.add_child(cs)
	add_child(area)


func _exit_tree() -> void:
	if target != "":
		EventBus.interact_prompt.emit("")


func jar_position() -> Vector3:
	return global_transform * jar_offset


## What interact would do from `p` right now.
func target_for(p: Vector3) -> String:
	if p.distance_to(jar_position()) < JAR_RADIUS and not arrested:
		return "tip"
	if p.distance_to(global_position) < SHOP_RADIUS:
		return "shop"
	return ""


func _process(_dt: float) -> void:
	var b: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var t: String = "" if b == null or BS.blocked() else target_for(b.global_position)
	if t != target:
		target = t
		EventBus.interact_prompt.emit(prompt_text(t))
	if t != "" and not BS.blocked() and Input.is_action_just_pressed(&"interact"):
		interact()


func prompt_text(t: String) -> String:
	if t == "":
		return ""
	var key: String = "Y" if AimAssist.last_device == "pad" else "E"
	var label: String = BSText.text("misc.updateInteract.01") if t == "tip" else BSText.text("html.btnSmShop.001")
	return "[%s] %s" % [key, label]


## Runs the current interaction (also called by tests / scripted sequences).
func interact() -> String:
	if target == "tip":
		logic.tip()
		return "tip"
	if target == "shop":
		if arrested:
			EventBus.banner.emit(BSText.text("code.doInteract.01"), BSText.text("code.doInteract.02"), 2.2)
			BSText.say("code.doInteract.03")
			return "arrested"
		open_shop()
		return "shop"
	return ""


func open_shop() -> Node:
	if _ui != null and is_instance_valid(_ui):
		return _ui
	_ui = ShopUI.open(get_tree(), logic)
	opened.emit()
	return _ui


func _build_visual() -> void:
	var green: StandardMaterial3D = StandardMaterial3D.new()
	green.albedo_color = Color("#3fae5f")
	var gold: StandardMaterial3D = StandardMaterial3D.new()
	gold.albedo_color = Color("#ffd23e")
	gold.metallic = 0.6
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color("#2a2f3a")
	_box(Vector3(2.6, 1.0, 1.0), Vector3(0, 0.5, 0), green)        # counter
	_box(Vector3(2.8, 0.08, 1.2), Vector3(0, 1.04, 0), gold)       # counter top trim
	_box(Vector3(0.12, 2.2, 0.12), Vector3(-1.3, 1.1, -0.45), dark)
	_box(Vector3(0.12, 2.2, 0.12), Vector3(1.3, 1.1, -0.45), dark)
	_box(Vector3(3.0, 0.14, 1.5), Vector3(0, 2.25, -0.1), green)   # awning
	var jar: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.14
	cyl.height = 0.3
	jar.mesh = cyl
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.95, 1.0, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jar.material_override = glass
	jar.position = jar_offset - Vector3(0, 0.0, 0)
	add_child(jar)
	var sign: Label3D = Label3D.new()
	sign.text = _sign_text()
	sign.font_size = 48
	sign.pixel_size = 0.006
	sign.modulate = Color("#7dff9a")
	sign.outline_size = 10
	sign.position = Vector3(0, 2.6, 0.1)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.name = "Sign"
	add_child(sign)


func _sign_text() -> String:
	if arrested:
		return BSText.text("code.doInteract.01") + "\n" + BSText.text("code.doInteract.02")
	return BSText.text("html.shopTitle.001")


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	add_child(m)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.position = pos
	if size.y > 0.5:   # only the counter and posts are solid; the awning is decoration
		add_child(body)
	else:
		body.free()
