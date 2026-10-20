class_name Unlocks
extends RefCounted
## Front-end unlock flow from data/unlocks.json. Pure functions: give it the set of facts a profile
## holds (unlock ids + completion flags) and it answers what is open.


## Every unlock id that is open for a profile holding `facts` (the start set is always open).
static func resolve(rules_doc: Dictionary, facts: Array) -> PackedStringArray:
	var have: Dictionary = {}
	for f: Variant in facts:
		have[str(f)] = true
	for s: Variant in rules_doc.get("start", []):
		have[str(s)] = true
	var rules: Dictionary = rules_doc.get("rules", {})
	var changed: bool = true
	while changed:   # rules can depend on other rules
		changed = false
		for id: String in rules.keys():
			if have.has(id):
				continue
			var r: Dictionary = rules[id]
			var ok_all: bool = r.has("all") and (r["all"] as Array).all(func(x: Variant) -> bool: return have.has(str(x)))
			var ok_any: bool = r.has("any") and (r["any"] as Array).any(func(x: Variant) -> bool: return have.has(str(x)))
			if ok_all or ok_any:
				have[id] = true
				changed = true
	return PackedStringArray(have.keys())


static func is_open(rules_doc: Dictionary, facts: Array, id: String) -> bool:
	return id in resolve(rules_doc, facts)
