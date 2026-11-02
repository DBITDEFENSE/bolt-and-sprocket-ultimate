class_name MarkTargets
extends RefCounted
## What a map mark or the ping key points at (Update 04 section 3, DECISIONS T-069), shared by the pause map, the
## ping key and the bots' order handler. classify(node) walks up from whatever was hit (an Area3D, a door's body)
## to the thing that matters and says what marking it means:
##   {kind: "buy" | "collect" | "activate" | "go", sub, label, price, node}
##   buy:      perk (a perk machine), gun (a wall weapon), ammo_box, door (closed BuyDoor), crate (the Requisition
##             Crate where it is now), crucible, trap (a trap lever), bench (the Armorer's Bench)
##   collect:  quest (an easter-egg object, part, radio...: BotSquad.ee_assign_node), powerup (a power-up on the floor)
##   activate: power (the power switch while the power is off)
##   go:       anything else (a floor, a wall: "Go here")
## A future map's buyables are covered by their classes; a new class adds a branch here.

const UP_LEVELS: int = 5


## The classification of `n` (or of the first parent that is something), {"kind": "go"} for nothing.
static func classify(n: Node) -> Dictionary:
	var probe: Node = n
	for _i: int in UP_LEVELS:
		if probe == null:
			break
		var c: Dictionary = _one(probe)
		if not c.is_empty():
			c["node"] = probe
			return c
		probe = probe.get_parent()
	return {"kind": "go", "sub": "", "label": "", "price": 0, "node": null}


static func _one(n: Node) -> Dictionary:
	if n is Searchlight:   # T-153: MAN_SEARCHLIGHT (a bot takes the tower light)
		return {"kind": "activate", "sub": "searchlight", "label": "Searchlight", "price": 0}
	if n is PerkMachine:
		var pm: PerkMachine = n as PerkMachine
		return {"kind": "buy", "sub": "perk", "label": PerkManager.display_name(pm.perk_id), "price": PerkManager.price(pm.perk_id), "id": String(pm.perk_id)}
	if n is WallBuy:
		var wb: WallBuy = n as WallBuy
		var row: Dictionary = (GLData.table("weapons").get("weapons", {}) as Dictionary).get(String(wb.weapon_id), {})
		var nm: String = str(row.get("name", String(wb.weapon_id).capitalize()))
		return {"kind": "buy", "sub": "gun", "label": nm, "price": wb.price(), "id": String(wb.weapon_id), "gun": not row.is_empty()}
	if n is AmmoBox:
		return {"kind": "buy", "sub": "ammo_box", "label": "Ammo box", "price": AmmoBox.price_for({}, false, AmmoBox.cfg())}
	if n is BuyDoor:
		var d: BuyDoor = n as BuyDoor
		if d.is_open:
			return {}
		return {"kind": "buy", "sub": "door", "label": d.label if d.label != "" and d.label != "Door" else BotBrain.door_label(d).capitalize(), "price": d.cost,
			"locked": d.requires_power and not GameState.power_on}
	if n is MysteryCrate:
		var mc: MysteryCrate = n as MysteryCrate
		if mc.phase == MysteryCrate.Phase.HIDDEN:
			return {}
		return {"kind": "buy", "sub": "crate", "label": "Requisition Crate", "price": CrateManager.cost()}
	if n is Crucible:
		return {"kind": "buy", "sub": "crucible", "label": "The Crucible", "price": Crucible.price_for(&"upgrade", GLData.table("economy"), 0)}
	if n is TrapLever:
		var t: Node = (n as TrapLever).trap()
		var tc: int = int(t.call("cost")) if t != null and t.has_method("cost") else 1000
		return {"kind": "buy", "sub": "trap", "label": "Trap", "price": tc}
	if n is ArmorersBench:
		return {"kind": "buy", "sub": "bench", "label": "Armorer's Bench", "price": 0}
	if n is PowerSwitch:
		if GameState.power_on:
			return {}
		return {"kind": "activate", "sub": "power", "label": "Power switch", "price": 0}
	if n is PowerupPickup:
		var pid: StringName = (n as PowerupPickup).powerup_id
		return {"kind": "collect", "sub": "powerup", "label": PowerupManager.display_name(pid), "price": 0}
	if MapState.is_quest_node(n) or n is Workbench:
		return {"kind": "collect", "sub": "quest", "label": MapState._quest_label(n) if not (n is Workbench) else "Workbench", "price": 0}
	return {}


## The node of a map POI, classified (the pause map's clicks); {"kind": "go"} when it is nothing to buy.
static func classify_poi(poi: Dictionary, ms: MapState) -> Dictionary:
	if poi.is_empty() or ms == null:
		return {"kind": "go", "sub": "", "label": "", "price": 0, "node": null}
	var n: Node = ms.poi_node(poi)
	if n != null:
		var c: Dictionary = classify(n)
		if str(c["kind"]) != "go":
			return c
	return {"kind": "go", "sub": "", "label": str(poi.get("label", "")), "price": int(poi.get("price", 0)), "node": n}


## The mark kind for a target ("buy" / "collect" / "go"; activate marks show as collect).
static func mark_kind(c: Dictionary) -> String:
	match str(c.get("kind", "go")):
		"buy":
			return "buy"
		"collect", "activate":
			return "collect"
	return "go"


## "1,250"
static func money(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## The question a door mark asks before it becomes an order: "Open this door for 1,250?"
static func door_question(price: int) -> String:
	return "Open this door for %s?" % money(price)
