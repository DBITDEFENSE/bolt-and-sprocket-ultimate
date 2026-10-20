class_name ShopLogic
extends RefCounted
## Blartz's shop v2 rules, without any UI (shopStock / openShop / buyItem / sellWeapon / toggleWish /
## updateWishPin / tip jar, index.html:11949-12260 and 4345). The shop screen (ui/bs/shop.gd) and the
## tests drive it. Prices and stock: data/bs/shop.json, with data/bs/weapons.json (when present) as the
## source for weapon names, prices, trade-in values, unlocks and mod tracks.
## Every Blartz line is played by id through BSText.say().
##
## Item dictionary: {id, kind, cat, name, price, was, deal, maxed, tier, max_tier, weapon, track,
##                   desc, available, locked_reason}
##   kind: weapon | upg | mallet | ammo | nano | super | karen     cat: weapon | upg | gear | cosmetic

signal purchased(item: Dictionary)
signal denied(item: Dictionary, reason: String)
signal sold(weapon_id: String, value: int)
signal pitched(line_id: String)
signal tipped(count: int)

var S: Dictionary = {}          # shop.json
var W: Dictionary = {}          # weapons.json (may be empty)
var deal_id: String = ""
var tree: SceneTree = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var implemented_override: Dictionary = {}   # weapon id -> bool (tests, previews)


func _init(tree_: SceneTree = null) -> void:
	tree = tree_
	S = Data.table("bs/shop") as Dictionary
	if Data.has_table("bs/weapons"):
		var w: Variant = Data.table("bs/weapons")
		W = w as Dictionary if w is Dictionary else {}
	rng.randomize()


# ------------------------------------------------------------------ stock

func _weapon_defs() -> Dictionary:
	return W.get("weapons", {}) as Dictionary


func weapon_name(id: String) -> String:
	var d: Dictionary = _weapon_defs().get(id, {})
	if d.has("name"):
		return str(d["name"])
	for e: Dictionary in S["weapons"]:
		if str(e["id"]) == id:
			return str(e["name_text"]) if e.has("name_text") else BSText.text(str(e["name"]), id.to_upper())
	return id.replace("_", " ").to_upper()


func _fallback(id: String) -> Dictionary:
	for e: Dictionary in S["weapons"]:
		if str(e["id"]) == id:
			return e
	return {}


## Is the gun built yet? weapons.json: its script exists on disk (or "implemented" says so).
## Without weapons.json: shop.json "m1".
func implemented(id: String) -> bool:
	if implemented_override.has(id):
		return bool(implemented_override[id])
	var d: Dictionary = _weapon_defs().get(id, {})
	if not d.is_empty():
		if d.has("implemented"):
			return bool(d["implemented"])
		return d.has("script") and ResourceLoader.exists(str(d["script"]))
	return bool(_fallback(id).get("m1", false))


func _unlocked(flag_id: String) -> bool:
	return flag_id == "" or BS.flag(flag_id)


## Guns Blartz sells, in shop order: [{id, price, unlock_flag}]
func _gun_stock() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var defs: Dictionary = _weapon_defs()
	if defs.is_empty():
		for e: Dictionary in S["weapons"]:
			out.append({"id": str(e["id"]), "price": int(e["price"]), "unlock_flag": str(e.get("unlock", ""))})
		return out
	var map: Dictionary = S.get("unlock_flags", {})
	var order: Array = W.get("order", defs.keys())
	for id: Variant in order:
		var d: Dictionary = defs.get(str(id), {})
		var u: String = str(d.get("unlock", "start"))
		if u == "start" or u == "blartz_gift" or int(d.get("price", 0)) <= 0 or not map.has(u):
			continue
		out.append({"id": str(id), "price": int(d["price"]), "unlock_flag": str(map[u])})
	return out


func mod_tracks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m: Dictionary = W.get("mods", {})
	if m.has("dmg"):
		for k: String in ["dmg", "rate", "ammo"]:
			var t: Dictionary = m[k]
			out.append({"k": k, "label": str(t.get("label", k)), "prices": t["prices"], "flavor_text": str(t.get("flavor", ""))})
		return out
	for t: Dictionary in S["mod_tracks"]:
		out.append({"k": str(t["k"]), "label": str(t["label"]), "prices": t["prices"], "flavor_text": BSText.text(str(t["flavor"]))})
	return out


func _mods_lock_flag(id: String) -> String:
	var p: Dictionary = W.get("progression", {})
	return str((p.get("mods_locked_until_flag", {"patent_pending": "blartzRescue"}) as Dictionary).get(id, ""))


func nano_bought() -> int:
	return clampi(roundi(float(BS.max_hp - BS.START_HP) / float(S["nano"]["hp"])), 0, 99)


## Everything Blartz has on the counter right now (deal price applied).
func stock() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for g: Dictionary in _gun_stock():
		var id: String = g["id"]
		if BS.owns(StringName(id)) or not _unlocked(g["unlock_flag"]):
			continue
		var fb: Dictionary = _fallback(id)
		var ok: bool = implemented(id)
		items.append(_item("w." + id, "weapon", weapon_name(id), g["price"], {
			"weapon": id, "available": ok, "desc": str(fb.get("desc", "")) if ok else "bs.ui.shop.coming_soon_desc",
			"locked_reason": "" if ok else "coming_soon"}))
	for wid: Variant in BS.weapon_order:
		var id2: String = str(wid)
		var lock: String = _mods_lock_flag(id2)
		if lock != "" and not BS.flag(lock):
			continue
		var mods: Dictionary = (BS.weapons.get(id2, {}) as Dictionary).get("mods", {})
		for tr: Dictionary in mod_tracks():
			var tier: int = int(mods.get(tr["k"], 0))
			var prices: Array = tr["prices"]
			var maxed: bool = tier >= prices.size()
			items.append(_item("u.%s.%s" % [id2, tr["k"]], "upg", "%s: %s" % [weapon_name(id2), tr["label"]],
				0 if maxed else int(prices[tier]), {"weapon": id2, "track": tr["k"], "tier": tier, "max_tier": prices.size(),
				"maxed": maxed, "desc_text": "%s (%s, tier %d of %d.)" % [tr["flavor_text"], weapon_name(id2), mini(tier + 1, prices.size()), prices.size()]}))
	if BS.flag(str(S["karen"]["unlock"])) and not BS.flag("karen_owned"):
		items.append(_item("karen", "karen", "K.A.R.E.N.", int(S["karen"]["price"]), {"desc": str(S["karen"]["desc"])}))
	if not BS.super_owned:
		items.append(_item("super", "super", "SUPER SPROCKET PROTOCOL", int(S["super"]["price"]), {"desc": str(S["super"]["desc"])}))
	var mallets: Array = S["mallet"]
	if BS.mallet_tier < mallets.size():
		var m: Dictionary = mallets[BS.mallet_tier]
		items.append(_item("mallet", "mallet", "Mallet: " + str(m["name_text"]), int(m["price"]),
			{"tier": BS.mallet_tier + 1, "max_tier": mallets.size() + 1, "desc": str(m["desc"])}))
	else:
		items.append(_item("mallet", "mallet", "Mallet: " + str((mallets[mallets.size() - 1] as Dictionary)["name_text"]), 0,
			{"tier": mallets.size() + 1, "max_tier": mallets.size() + 1, "maxed": true, "desc": str(S["mallet_maxed_desc"])}))
	items.append(_item("ammo", "ammo", "Ammo Grab-Bag", int(S["ammo"]["price"]), {"desc": str(S["ammo"]["desc"])}))
	items.append(_item("nano", "nano", "Nanotech Boost (+%d HP)" % int(S["nano"]["hp"]),
		int(S["nano"]["base"]) + nano_bought() * int(S["nano"]["step"]), {"desc": str(S["nano"]["desc"])}))
	if deal_id != "":
		for it: Dictionary in items:
			if it["id"] == deal_id and not it["maxed"] and it["available"]:
				it["was"] = it["price"]
				it["price"] = roundi(float(it["price"]) * (1.0 - float(S["deal_pct"])))
				it["deal"] = true
	return items


func _item(id: String, kind: String, name_: String, price: int, extra: Dictionary) -> Dictionary:
	var it: Dictionary = {"id": id, "kind": kind, "cat": category(kind), "name": name_, "price": price, "was": 0, "deal": false,
		"maxed": false, "tier": 0, "max_tier": 0, "weapon": "", "track": "", "desc": "", "desc_text": "", "available": true, "locked_reason": ""}
	it.merge(extra, true)
	return it


static func category(kind: String) -> String:
	if kind == "weapon" or kind == "upg" or kind == "cosmetic":
		return kind
	return "gear"


func items_for_tab(tab: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in stock():
		if tab == "all" or it["cat"] == tab:
			out.append(it)
	return out


func find(item_id: String) -> Dictionary:
	for it: Dictionary in stock():
		if it["id"] == item_id:
			return it
	return {}


## Description text for an item (its line, or the built-in text for mod rows).
func describe(it: Dictionary) -> String:
	if str(it.get("desc_text", "")) != "":
		return str(it["desc_text"])
	if str(it.get("desc", "")) != "":
		return BSText.text(str(it["desc"]))
	return ""


static func item_line(kind: String) -> String:
	return "blartz.item." + kind if kind in ["weapon", "upg", "mallet", "ammo", "nano", "super"] else ""


# ------------------------------------------------------------------ visit

## A new visit: picks the deal of the day (one buyable at 25% off) and Blartz's opening pitch.
func open_visit() -> String:
	deal_id = ""
	var buyables: Array[Dictionary] = []
	for it: Dictionary in stock():
		if not it["maxed"] and it["price"] > 0 and it["available"]:
			buyables.append(it)
	if not buyables.is_empty():
		deal_id = buyables[rng.randi_range(0, buyables.size() - 1)]["id"]
	return pitch(true)


## Plays a random pitch (grateful ones after the rescue, 40% of the time on opening).
func pitch(opening: bool = false) -> String:
	var pool_id: String = "blartz.pitches"
	if opening and BS.flag("blartzRescue") and rng.randf() < float(S["grateful_chance"]):
		pool_id = "blartz.gratefulPitches"
	return _say_random(pool_id)


func _say_random(pool_id: String) -> String:
	var p: PackedStringArray = BSText.pool(pool_id)
	if p.is_empty():
		return ""
	var id: String = p[rng.randi_range(0, p.size() - 1)]
	_say(id)
	return id


func _say(id: String) -> void:
	BSText.say(id)
	pitched.emit(id)


# ------------------------------------------------------------------ buy / sell

## Buys an item by id. Returns {ok, reason, line}. reason: maxed | broke | unavailable | missing.
func buy(item_id: String) -> Dictionary:
	var it: Dictionary = find(item_id)
	if it.is_empty():
		return {"ok": false, "reason": "missing", "line": ""}
	if not it["available"]:
		denied.emit(it, "unavailable")
		return {"ok": false, "reason": "unavailable", "line": ""}
	if it["maxed"]:
		_say("code.buyItem.01")
		denied.emit(it, "maxed")
		return {"ok": false, "reason": "maxed", "line": "code.buyItem.01"}
	if not BS.spend(int(it["price"])):
		var l: String = _say_random("blartz.deny")
		denied.emit(it, "broke")
		return {"ok": false, "reason": "broke", "line": l}
	_apply(it)
	if it["deal"]:
		deal_id = ""
	var line: String = _say_random("blartz.buy")
	BS.save_to_profile()
	purchased.emit(it)
	return {"ok": true, "reason": "", "line": line}


func _apply(it: Dictionary) -> void:
	match str(it["kind"]):
		"weapon":
			if not _weapons_call("give", [StringName(it["weapon"])]):     # WeaponManager.give refills too
				BS.give_weapon(StringName(it["weapon"]))
				(BS.weapons[it["weapon"]] as Dictionary)["ammo_now"] = -1
			EventBus.banner.emit(str(it["name"]) + BSText.text("code.buyItem.03"), BSText.text("code.buyItem.04"), 2.0)
		"upg":
			var mods: Dictionary = (BS.weapons[it["weapon"]] as Dictionary)["mods"]
			mods[it["track"]] = int(mods.get(it["track"], 0)) + 1
			if it["track"] == "ammo":
				(BS.weapons[it["weapon"]] as Dictionary)["ammo_now"] = -1
			_weapons_call("on_mods_changed", [StringName(it["weapon"])])
		"mallet":
			BS.mallet_tier += 1
			var nm: String = str((S["mallet"][BS.mallet_tier - 1] as Dictionary)["name_text"])
			EventBus.banner.emit(nm.to_upper() + "!", BSText.text("code.buyItem.11"), 2.2)
		"ammo":
			if not _weapons_call("refill_all", []):
				for id: Variant in BS.weapons.keys():
					(BS.weapons[id] as Dictionary)["ammo_now"] = -1
		"nano":
			BS.max_hp += int(S["nano"]["hp"])
			var p: Node = _player()
			if p != null:
				p.set("max_hp", float(BS.max_hp))
				p.set("hp", float(BS.max_hp))
		"super":
			BS.super_owned = true
			BS.super_meter = 1.0      # comes charged: Blartz believes in instant gratification
			EventBus.super_meter_changed.emit(1.0)
			EventBus.banner.emit(BSText.text("code.buyItem.09"), BSText.text("code.buyItem.10"), 2.6)
		"karen":
			BS.set_flag("karen_owned")
			EventBus.banner.emit(BSText.text("code.buyItem.07"), BSText.text("code.buyItem.08"), 2.6)


func _player() -> Node:
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"player")


## Calls a method on Bolt's "Weapons" node (the weapons builder's manager) if it exists.
func _weapons_call(method: String, args: Array) -> bool:
	var p: Node = _player()
	var wm: Node = p.get_node_or_null("Weapons") if p != null else null
	if wm != null and wm.has_method(method):
		wm.callv(method, args)
		return true
	return false


## Tells Bolt's WeaponManager the gun is gone: its on_weapon_sold(id) if it has one, else drops the
## BSWeapon from its public `weapons` dict and re-selects.
func _drop_from_manager(id: StringName) -> void:
	if _weapons_call("on_weapon_sold", [id]):
		return
	var p: Node = _player()
	var wm: Node = p.get_node_or_null("Weapons") if p != null else null
	if wm == null or not ("weapons" in wm):
		return
	var ws: Dictionary = wm.get("weapons")
	var w: Node = ws.get(id, null) as Node
	ws.erase(id)
	if w != null:
		w.queue_free()
	if wm.get("current") == id:
		wm.set("current", &"")
		if BS.current_weapon != &"" and wm.has_method("select"):
			wm.call("select", BS.current_weapon)


## Trade-in value of an owned gun (60% of price; weapons.json trade_in wins when present).
func trade_value(id: String) -> int:
	var d: Dictionary = _weapon_defs().get(id, {})
	if d.has("trade_in"):
		return int(d["trade_in"])
	if (S.get("trade_only", {}) as Dictionary).has(id):
		return int(S["trade_only"][id])
	var fb: Dictionary = _fallback(id)
	return roundi(float(fb.get("price", 0)) * float(S["trade_pct"]))


func trade_in_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for wid: Variant in BS.weapon_order:
		var id: String = str(wid)
		var v: int = trade_value(id)
		if v > 0:
			out.append({"id": id, "name": weapon_name(id), "value": v})
	return out


## Sells a gun back: bolts in, gun and its mods gone (upgrades don't come back).
func sell(id: String) -> Dictionary:
	var v: int = trade_value(id)
	if not BS.owns(StringName(id)) or v <= 0:
		return {"ok": false, "value": 0}
	BS.weapons.erase(id)
	BS.weapon_order.erase(id)
	if String(BS.current_weapon) == id:
		BS.current_weapon = StringName(str(BS.weapon_order[0])) if not BS.weapon_order.is_empty() else &""
		EventBus.weapon_changed.emit(BS.current_weapon)
	_drop_from_manager(StringName(id))
	BS.add_bolts(v)
	_say("code.sellWeapon.01")
	BS.save_to_profile()
	sold.emit(id, v)
	return {"ok": true, "value": v}


# ------------------------------------------------------------------ wishlist, tip jar

func wishlist() -> Array:
	if not (BS.flags.get("shop.wishlist") is Array):
		BS.flags["shop.wishlist"] = []
	return BS.flags["shop.wishlist"]


func toggle_wish(item_id: String) -> bool:
	var wl: Array = wishlist()
	if item_id in wl:
		wl.erase(item_id)
		return false
	wl.append(item_id)
	return true


func is_wished(item_id: String) -> bool:
	return item_id in wishlist()


## The HUD wish pin: the cheapest wished item you can't afford yet, else the first wished one.
func wish_pin() -> Dictionary:
	var wished: Array[Dictionary] = []
	for it: Dictionary in stock():
		if is_wished(it["id"]) and not it["maxed"]:
			wished.append(it)
	if wished.is_empty():
		return {}
	var poor: Array[Dictionary] = wished.filter(func(x: Dictionary) -> bool: return int(x["price"]) > BS.bolts)
	poor.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["price"]) < int(b["price"]))
	return poor[0] if not poor.is_empty() else wished[0]


func tip_count() -> int:
	return int(BS.flags.get("shop.tips", 0))


## One bolt in the jar. Blartz says tips.01..04 in order, then repeats the last.
func tip() -> Dictionary:
	if not BS.spend(1):
		return {"ok": false, "line": ""}
	var n: int = tip_count() + 1
	BS.flags["shop.tips"] = n
	var p: PackedStringArray = BSText.pool("blartz.tips")
	var id: String = p[mini(n - 1, p.size() - 1)] if not p.is_empty() else ""
	if id != "":
		_say(id)
	BS.save_to_profile()
	tipped.emit(n)
	return {"ok": true, "line": id}
