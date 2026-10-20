class_name MemoPickup
extends Collectible
## An OmniScrap internal memo datapad (makeMemoPad). Found ids go in SaveProfile.doc["bs"]["memos"];
## BS flag "memo.<id>" is set. Banner "INTERNAL MEMO RECOVERED" with the title and count. Autosaves.

var memo_id: String = ""      # "memo.01"
var title: String = ""
var memo_total: int = 35      # the OmniScrap memos (epilogue counts 35; hidden 36-40 are separate)


static func is_found(id: String) -> bool:
	var memos: Array = (SaveProfile.doc.get("bs", {}) as Dictionary).get("memos", [])
	return id in memos


func _on_collect(_bolt: Node) -> void:
	var bs: Dictionary = SaveProfile.doc["bs"]
	if not bs.has("memos"):
		bs["memos"] = []
	var memos: Array = bs["memos"]
	if not (memo_id in memos):
		memos.append(memo_id)
	BS.set_flag("memo." + memo_id)
	EventBus.memo_found.emit(memo_id)
	EventBus.banner.emit(LevelKit.text("code.collectPickup.05"),
		LevelKit.text("bs.level.memo_count").format({"title": title, "n": memos.size(), "total": memo_total}), 2.6)
	BS.save_to_profile()


func _make_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	LevelKit.box(root, Vector3.ZERO, Vector3(0.4, 0.5, 0.06), "#2c3242", false)
	LevelKit.box(root, Vector3(0, 0.02, 0.04), Vector3(0.3, 0.36, 0.02), "#9fecff", false, Vector3.ZERO, 1, 1.6)
	return root
