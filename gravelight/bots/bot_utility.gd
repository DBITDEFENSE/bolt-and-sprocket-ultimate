class_name BotUtility
extends RefCounted
## Utility-AI scoring (Update 03 section 1): response curves, considerations, action scores and the pick with
## hysteresis. Pure (no scene access), so the decisions are unit-tested from hand-built contexts
## (gravelight/tests/unit/test_bot_brain.gd). Tuning: data/gravelight/ai/actions.json and curves.json.
##
## A context is a Dictionary of normalised inputs (0..1, the names in actions.json _inputs). An action scores
##   weight x product(curve_i(input_i), compensated) x personality[action] x role[action] x order mult + order boost
## and the running action gets the hysteresis bonus (+ commit_bonus while it is mid-task).


## One response curve at x (0..1 in, 0..1 out). `c` is a curve object or a name in `curves`.
static func curve(c: Variant, x: float, curves: Dictionary = {}) -> float:
	var d: Dictionary = {}
	if c is String or c is StringName:
		d = curves.get(String(c), {})
		if d.is_empty():
			push_warning("BotUtility: unknown curve '%s'" % str(c))
			return clampf(x, 0.0, 1.0)
	elif c is Dictionary:
		d = c
	else:
		return clampf(x, 0.0, 1.0)
	x = clampf(x, 0.0, 1.0)
	var y: float = 0.0
	match str(d.get("type", "linear")):
		"linear":
			y = float(d.get("m", 1.0)) * (x - float(d.get("c", 0.0))) + float(d.get("b", 0.0))
		"poly":
			var base: float = x - float(d.get("c", 0.0))
			var k: float = float(d.get("k", 2.0))
			y = float(d.get("m", 1.0)) * (pow(base, k) if k == floorf(k) else pow(maxf(base, 0.0), k)) + float(d.get("b", 0.0))
		"logistic":
			y = float(d.get("k", 1.0)) / (1.0 + exp(-float(d.get("m", 10.0)) * (x - float(d.get("c", 0.5))))) + float(d.get("b", 0.0))
		"step":
			y = float(d.get("hi", 1.0)) if x >= float(d.get("c", 0.5)) else float(d.get("lo", 0.0))
		"points":
			y = _points(d.get("points", []), x)
		_:
			y = x
	return clampf(y, 0.0, 1.0)


## Piecewise linear through [[x, y], ...] (x ascending), flat beyond the ends.
static func _points(pts: Array, x: float) -> float:
	if pts.is_empty():
		return x
	var first: Array = pts[0]
	if x <= float(first[0]):
		return float(first[1])
	for i: int in range(1, pts.size()):
		var a: Array = pts[i - 1]
		var b: Array = pts[i]
		if x <= float(b[0]):
			var span: float = float(b[0]) - float(a[0])
			var t: float = 0.0 if span <= 0.0 else (x - float(a[0])) / span
			return lerpf(float(a[1]), float(b[1]), t)
	return float((pts[pts.size() - 1] as Array)[1])


## An action's raw score from its considerations (no weight): the product of the curve values, each made up
## for the number of considerations (so an action with five factors isn't punished against one with two).
static func considerations_score(cons: Array, ctx: Dictionary, curves: Dictionary) -> float:
	if cons.is_empty():
		return 1.0
	var mod: float = 1.0 - 1.0 / float(cons.size())
	var total: float = 1.0
	for c: Variant in cons:
		var cd: Dictionary = c
		var v: float = curve(cd.get("curve", "identity"), float(ctx.get(str(cd.get("input", "")), 0.0)), curves)
		v = v + (1.0 - v) * mod * v
		total *= v
		if total <= 0.0:
			return 0.0
	return total


## Every action's score for this context: {action id: score}. `mods` = {"personality": {id: mult}, "role":
## {id: mult}, "order_mult": {id: mult}, "order_boost": {id: add}}.
static func score_all(cfg: Dictionary, ctx: Dictionary, curves: Dictionary, mods: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	var pers: Dictionary = mods.get("personality", {})
	var role: Dictionary = mods.get("role", {})
	var omult: Dictionary = mods.get("order_mult", {})
	var oboost: Dictionary = mods.get("order_boost", {})
	var acts: Dictionary = cfg.get("actions", {})
	for id: Variant in acts.keys():
		var a: Dictionary = acts[id]
		var key: String = str(id)
		var s: float = float(a.get("weight", 1.0)) * considerations_score(a.get("considerations", []), ctx, curves)
		s *= float(pers.get(key, 1.0)) * float(role.get(key, 1.0)) * float(omult.get(key, 1.0))
		if float(oboost.get(key, 0.0)) != 0.0 and _gates_open(a, ctx, curves):
			s = maxf(0.0, s + float(oboost[key]) * float(pers.get(key, 1.0)) * float(omult.get(key, 1.0)))
		out[key] = s
	return out


## True when every gate-like consideration (a step curve) passes: an order's boost never revives an action whose
## preconditions are false (no hold spot, no downed teammate).
static func _gates_open(a: Dictionary, ctx: Dictionary, curves: Dictionary) -> bool:
	for c: Variant in a.get("considerations", []):
		var cd: Dictionary = c
		var cv: Variant = cd.get("curve", "")
		var d: Dictionary = curves.get(String(cv), {}) if (cv is String or cv is StringName) else (cv as Dictionary if cv is Dictionary else {})
		if str(d.get("type", "")) == "step" and float(d.get("lo", 0.0)) <= 0.0 and curve(cv, float(ctx.get(str(cd.get("input", "")), 0.0)), curves) <= 0.0:
			return false
	return true


## The winner: [action id, its final score] after hysteresis for `current` (+ commit when it is mid-task) and
## gaussian `noise` (decision quality by skill). `rng` may be null for no noise.
static func choose(scores: Dictionary, current: String, hysteresis: float, commit: float = 0.0, noise: float = 0.0,
		rng: RandomNumberGenerator = null) -> Array:
	var best: String = ""
	var best_s: float = -INF
	for id: Variant in scores.keys():
		var s: float = float(scores[id])
		if s <= 0.0 and str(id) != current:
			continue
		if str(id) == current and s > 0.0:
			s += hysteresis + commit
		if noise > 0.0 and rng != null and s > 0.0:
			s += rng.randfn(0.0, noise)
		if s > best_s:
			best_s = s
			best = str(id)
	return [best, best_s]


## The top `n` [id, score] pairs, best first (the debug overlay).
static func top(scores: Dictionary, n: int) -> Array:
	var arr: Array = []
	for id: Variant in scores.keys():
		arr.append([str(id), float(scores[id])])
	arr.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	return arr.slice(0, n)


## The modifiers an order gives (actions.json orders.<id>) at `strength` (1 = fresh, 0 = expired):
## {"order_boost": {...}, "order_mult": {...}}. A mult fades toward 1 with the strength.
static func order_mods(cfg: Dictionary, order_id: String, strength: float) -> Dictionary:
	var o: Dictionary = (cfg.get("orders", {}) as Dictionary).get(order_id, {})
	var boost: Dictionary = {}
	var mult: Dictionary = {}
	if o.is_empty() or strength <= 0.0:
		return {"order_boost": boost, "order_mult": mult}
	for k: Variant in (o.get("boost", {}) as Dictionary).keys():
		boost[str(k)] = float(o["boost"][k]) * strength
	for k2: Variant in (o.get("mult", {}) as Dictionary).keys():
		mult[str(k2)] = lerpf(1.0, float(o["mult"][k2]), clampf(strength, 0.0, 1.0))
	return {"order_boost": boost, "order_mult": mult}


## Strength of an order given `age` seconds ago that lasts `duration` seconds: 1 until it runs out, then 0.
static func order_strength(age: float, duration: float) -> float:
	return 1.0 if age >= 0.0 and age < duration else 0.0
