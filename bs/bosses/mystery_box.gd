class_name MysteryBox
extends Node3D
## The Content Creator's UNBOXING box (BS_ENEMIES §4.3, phase 1). Falls onto the deck over `fall_time`
## (its shadow decal is the telegraph), sits for `open_delay` (1.5 s), then opens on its contents:
##   &"sentries"  2 Selfie Sentries   &"lifeguard"  a Lifeguard Bot   &"bomb"  a SPONSORED bomb
## A SPONSORED box is a hittable target while it falls ("SPONSORED" on its side): shooting it detonates it on
## the Content Creator instead (the boss gets `sponsored_shot`). Landed, the bomb arms: a 1.0 s fuse with a
## jingle and an r4 ring, then 20 damage.

signal opened(contents: StringName)
signal shot_down

var boss: Node = null
var contents: StringName = &"bomb"
var fall_time: float = 0.8
var open_delay: float = 1.5
var land_at: Vector3 = Vector3.ZERO
var start_at: Vector3 = Vector3.ZERO
var B: Dictionary = {}
var radius: float = 0.9
var landed: bool = false
var opened_: bool = false
var _t: float = 0.0
var _body: MeshInstance3D


static func drop(parent: Node, boss_: Node, at: Vector3, contents_: StringName, cfg: Dictionary) -> MysteryBox:
	var b: MysteryBox = MysteryBox.new()
	b.boss = boss_
	b.contents = contents_
	b.B = cfg
	b.fall_time = float(cfg["fall_time"])
	b.open_delay = float(cfg["open_delay"])
	parent.add_child(b)
	var gy: float = EnemyFx.floor_y(b, at, at.y)
	b.land_at = Vector3(at.x, gy, at.z)
	b.start_at = b.land_at + Vector3(0, float(cfg["drop_height"]), 0)
	b.global_position = b.start_at
	EnemyFx.ring(parent, b.land_at, 1.4, b.fall_time, Color("#1c1c24"))                 # the falling shadow
	if contents_ == &"bomb":
		b.add_to_group(&"enemies")
		b.add_to_group(&"damageable")
	return b


func _ready() -> void:
	var c: Color = Color("#ff4d9d") if contents == &"bomb" else Color("#c8a040")
	_body = EnemyFx.box(self, Vector3(1.4, 1.2, 1.4), Vector3(0, 0.6, 0), EnemyFx.mat(c))
	EnemyFx.box(self, Vector3(1.5, 0.2, 0.3), Vector3(0, 1.1, 0), EnemyFx.mat(Color("#f2ebe0")))            # ribbon
	EnemyFx.box(self, Vector3(0.3, 0.2, 1.5), Vector3(0, 1.1, 0), EnemyFx.mat(Color("#f2ebe0")))
	var lbl: Label3D = Label3D.new()
	lbl.text = "SPONSORED" if contents == &"bomb" else "?"
	lbl.font_size = 56
	lbl.pixel_size = 0.005
	lbl.modulate = Color.WHITE
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 0.6, 0)
	add_child(lbl)


func is_alive() -> bool:
	return contents == &"bomb" and not landed and is_inside_tree()


func get_center() -> Vector3:
	return global_position + Vector3(0, 0.6, 0)


## Only a falling SPONSORED box can be hit: it blows up on the Content Creator.
func take_damage(_hit: Combat.Hit) -> bool:
	if not is_alive():
		return false
	landed = true
	remove_from_group(&"enemies")
	remove_from_group(&"damageable")
	shot_down.emit()
	if boss != null and is_instance_valid(boss) and boss.has_method("sponsored_shot"):
		boss.call("sponsored_shot", self)
	queue_free()
	return true


func _physics_process(delta: float) -> void:
	_t += delta
	if not landed:
		var k: float = clampf(_t / maxf(fall_time, 0.01), 0.0, 1.0)
		global_position = start_at.lerp(land_at, k * k)
		if k >= 1.0:
			landed = true
			_t = 0.0
			remove_from_group(&"enemies")
			remove_from_group(&"damageable")
		return
	if opened_:
		return
	if _t >= open_delay:
		opened_ = true
		_open()


func _open() -> void:
	var parent: Node = get_parent()
	opened.emit(contents)
	match contents:
		&"bomb":
			DelayedBlast.spawn(parent, land_at, float(B["bomb_r"]), float(B["bomb_fuse"]), float(B["bomb_dmg"]), Color("#ff4d9d"), boss,
				{"kind": &"sponsored_bomb"})
		&"sentries":
			for i: int in int(B["sentries"]):
				_add(&"selfie_sentry", land_at + Vector3((i * 2 - 1) * 1.5, 2.0, 0))
		&"lifeguard":
			_add(&"lifeguard_bot", land_at + Vector3(0, 0.2, 0))
	EnemyFx.chunks(parent, land_at + Vector3(0, 0.6, 0), Color("#c8a040"), 1.0, 3, 5)
	queue_free()


func _add(add_id: StringName, at: Vector3) -> void:
	if boss != null and is_instance_valid(boss) and boss.has_method("spawn_add"):
		boss.call("spawn_add", add_id, at)
	else:
		EnemySpawner.spawn(add_id, at, get_parent(), {"is_add": true, "aggro": true, "leash": 30.0})
