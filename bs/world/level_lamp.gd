class_name LevelLamp
extends MeshInstance3D
## A status lamp (the POWER and UPLINK lamps on the Compaction Lot gate, the Mast beacon). Dim `off_color`
## until set_lit(true), then glowing `on_color`. Optional blink while lit.

var lamp_id: String = ""
var off_color: Variant = "#5a2a1a"
var on_color: Variant = "#3ee6ff"
var lamp_radius: float = 0.35
var blink: bool = false
var lit: bool = false
var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"lamps")
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = lamp_radius
	sm.height = lamp_radius * 2.0
	mesh = sm
	set_lit(lit)


func set_lit(on: bool) -> void:
	lit = on
	material_override = LevelKit.mat(on_color, 2.0) if on else LevelKit.mat(off_color, 0.2)


func _process(delta: float) -> void:
	if blink and lit:
		_t += delta
		visible = sin(_t * 1000.0 / 260.0) > -0.3
