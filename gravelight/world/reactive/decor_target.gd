class_name DecorTarget
extends Area3D
## A "decor" hit volume with a simple reaction (Update 02 section 8, T-053; see DecorHit):
##   lamp   a hanging lantern: shooting it swings it on its chain (and its light with it) through LampSway, plus a
##          tinny knock. Maps without a LampSway just get the knock.
##   hay    a hay bale or a heap of straw: a puff of chaff.
##   cloth  a curtain: its DraftCurtain parent flutters.
## Kept tiny so every lantern can carry one; the volume is on the decor layer only, so nothing walks into it.

@export var kind: StringName = &"lamp"
@export var strength: float = 1.0

var hits: int = 0


## A target under `parent` at local `pos`: a sphere of radius `r`.
static func add(parent: Node3D, pos: Vector3, r: float, kind_: StringName, strength_: float = 1.0) -> DecorTarget:
	var t: DecorTarget = DecorTarget.new()
	t.name = "DecorTarget"
	t.kind = kind_
	t.strength = strength_
	t.position = pos
	var cs: CollisionShape3D = CollisionShape3D.new()
	var s: SphereShape3D = SphereShape3D.new()
	s.radius = r
	cs.shape = s
	t.add_child(cs)
	parent.add_child(t)
	return t


func _init() -> void:
	collision_layer = DecorHit.LAYER
	collision_mask = 0
	monitoring = false


func on_decor_shot(_col: Area3D, at: Vector3, dir: Vector3) -> void:
	hits += 1
	react(self, kind, at, dir, strength)


## The reaction of kind `k` for the hit volume `col` (a DecorTarget, or a plain Area3D with the "decor_kind" meta;
## a lamp's volume hangs under the lantern's swing pivot).
static func react(col: Node3D, k: StringName, at: Vector3, dir: Vector3, strength: float = 1.0) -> void:
	if col == null or not col.is_inside_tree():
		return
	match k:
		&"lamp":
			var sway: LampSway = LampSway.find(col.get_tree())
			if sway != null:
				# the target hangs under the lantern's pivot (Props.lantern): push exactly that lamp
				var piv: Node3D = col.get_parent() as Node3D
				sway.impulse_at(piv.global_position if piv != null else col.global_position, 0.3, dir, 0.35 * strength)
			AudioDirector.play_3d("lamp_knock" if AudioDirector.has_sound("lamp_knock") else "reload_clip_ping", at, -8.0, 0.15)
		&"hay":
			var fx: ReactiveFx = ReactiveFx.get_for(col)
			if fx != null:
				fx.chaff(at)
		&"cloth":
			var p: Node = col.get_parent()
			while p != null and not p.has_method("flutter"):
				p = p.get_parent()
			if p != null:
				p.call("flutter", dir, strength)
