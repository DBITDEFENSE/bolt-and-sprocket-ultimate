class_name GoldBolt
extends Collectible
## A gold bolt (currency, brief §4.3). Found ids persist in SaveProfile.doc["bs"]["gold"][planet] (a list of
## ids) and the running total in doc["bs"]["gold_bolts"]; BS flag "gold.<id>" is set too. Autosaves.

var gold_id: String = ""
var planet: String = ""
var total_on_planet: int = 5


static func found_list(planet_id: String) -> Array:
	var bs: Dictionary = SaveProfile.doc.get("bs", {})
	var g: Dictionary = bs.get("gold", {})
	return g.get(planet_id, [])


static func is_found(id: String) -> bool:
	return BS.flag("gold." + id)


func _on_collect(_bolt: Node) -> void:
	var bs: Dictionary = SaveProfile.doc["bs"]
	if not bs.has("gold"):
		bs["gold"] = {}
	var g: Dictionary = bs["gold"]
	if not g.has(planet):
		g[planet] = []
	if not (gold_id in (g[planet] as Array)):
		(g[planet] as Array).append(gold_id)
		bs["gold_bolts"] = int(bs.get("gold_bolts", 0)) + 1
	BS.set_flag("gold." + gold_id)
	EventBus.gold_bolt_found.emit(gold_id)
	EventBus.banner.emit(LevelKit.text("code.collectPickup.10"),
		LevelKit.text("bs.level.gold_count").format({"n": (g[planet] as Array).size(), "total": total_on_planet}), 2.2)
	BS.save_to_profile()


func _make_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	root.position.y = 0.0
	LevelKit.cylinder(root, Vector3.ZERO, 0.28, 0.5, "#ffd23e", false, "y", -1.0, 1.4)
	LevelKit.cylinder(root, Vector3(0, 0.32, 0), 0.4, 0.16, "#ffd23e", false, "y", -1.0, 1.4)
	return root
