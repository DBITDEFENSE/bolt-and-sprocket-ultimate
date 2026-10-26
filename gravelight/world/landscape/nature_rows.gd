class_name NatureRows
extends Node3D
## Trees, bushes and boulders a map generator places (UPDATE_05 section 5, DECISIONS T-093): Map 0's tree line just
## beyond the grounds' edge. The generator stores only the transforms; at load time this node builds one MultiMesh per
## model from the scripted nature meshes (Landscape.tree_mesh, near-fog materials shared with the Landscape's own
## forest), so the .tscn never carries mesh copies. Nothing collides (the edge wall is inside the trees).

## The model per list: nature.glb node names.
const MODELS: Dictionary = {"spruces": "Spruce_LOD0", "birches": "Birch_LOD0", "bushes": "Bush_A", "rocks": "Rock_B"}

@export var spruces: Array[Transform3D] = []
@export var birches: Array[Transform3D] = []
@export var bushes: Array[Transform3D] = []
@export var rocks: Array[Transform3D] = []
## The tree line casts the moon's shadow onto the snow at the edge (the forest beyond does not).
@export var tree_shadows: bool = true

var built: bool = false


func _ready() -> void:
	build()


func build() -> void:
	if built:
		return
	built = true
	for list: String in MODELS.keys():
		var xfs: Array[Transform3D] = get(list)
		if xfs.is_empty():
			continue
		var mesh: Mesh = Landscape.tree_mesh(str(MODELS[list]), true)
		if mesh == null:
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i: int in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = list.capitalize()
		mmi.multimesh = mm
		var trees: bool = list == "spruces" or list == "birches"
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (trees and tree_shadows) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
