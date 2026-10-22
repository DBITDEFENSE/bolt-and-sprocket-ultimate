class_name BotConfig
extends RefCounted
## Pure rules for AI teammates (T-031): tuning lookup, who plays which survivor, how much a bot counts for
## round scaling, the kill-share rule, and what a bot buys. No scene access, so it is unit-tested directly
## (gravelight/tests/unit/test_bots.gd). Tuning: data/gravelight/bots.json.

const CHARACTERS: PackedStringArray = ["dutch", "peg", "deacon", "wren"]


static func cfg() -> Dictionary:
	return GLData.table("bots")


## A skill preset's name after the old-name aliases (bots.json skill_aliases: green -> recruit, regular ->
## veteran); unknown names give the default preset's name.
static func skill_key(c: Dictionary, skill_name: String) -> String:
	var aliases: Dictionary = c.get("skill_aliases", {})
	var k: String = str(aliases.get(skill_name, skill_name))
	if (c.get("skills", {}) as Dictionary).has(k):
		return k
	return str(c.get("skill_default", "veteran"))


## A skill preset (Update 03 section 7: "recruit" / "veteran" / "elite"; the old "green" / "regular" map there):
## bots.json skills.<name> (turn rate, bursts) with data/gravelight/ai/skills.json <name> (reaction, aim
## convergence, decision noise, spend smartness) merged over it. Unknown names fall back to the default preset.
static func skill(c: Dictionary, skill_name: String) -> Dictionary:
	var k: String = skill_key(c, skill_name)
	var out: Dictionary = ((c.get("skills", {}) as Dictionary).get(k, {}) as Dictionary).duplicate()
	out.merge(BotAIData.skill(k), true)
	return out


## The next skill preset in the menu cycle (an old name counts as its new one).
static func next_skill(c: Dictionary, current: String) -> String:
	var order: Array = c.get("skill_order", ["veteran"])
	var cur: String = str((c.get("skill_aliases", {}) as Dictionary).get(current, current))
	var i: int = order.find(cur)
	return str(order[(i + 1) % order.size()])


static func clamp_bots(c: Dictionary, n: int) -> int:
	return clampi(n, 0, int(c.get("max_bots", 3)))


## Survivors for `n` bots: every survivor once, never the ones in `taken` (the humans'), in roster order.
static func assign_characters(taken: Array, n: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for ch: String in CHARACTERS:
		if out.size() >= n:
			break
		if not taken.has(ch) and not taken.has(StringName(ch)):
			out.append(StringName(ch))
	return out


## Spawn kit (bots.json spawn_kit): the kit guns not held yet (by base id), in kit order.
static func kit_weapons_missing(kit: Dictionary, held_bases: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for w: Variant in kit.get("weapons", []):
		var wid: String = str(w)
		if not held_bases.has(wid) and not held_bases.has(StringName(wid)):
			out.append(StringName(wid))
	return out


## Spawn kit: the kit perks not owned yet, in kit order.
static func kit_perks_missing(kit: Dictionary, owned: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Variant in kit.get("perks", []):
		var pid: String = str(p)
		if not owned.has(pid) and not owned.has(StringName(pid)):
			out.append(StringName(pid))
	return out


## The objective planner's mode from the menu settings: "local" when on, else "off".
static func ai_mode_from_settings(values: Dictionary, bots: int) -> String:
	if bots <= 0:
		return "off"
	return "local" if bool(values.get("bot_local_ai", true)) else "off"


## Players the round scaling sees: humans count 1, bots `bot_player_weight` each (rounded), 1..max_players.
static func scaled_player_count(humans: int, bots: int, c: Dictionary, max_players: int = 4) -> int:
	var w: float = float((c.get("scaling", {}) as Dictionary).get("bot_player_weight", 1.0))
	return clampi(maxi(1, humans) + roundi(float(bots) * w), 1, max_players)


## Kill share: true when bots may take any kill. `recent` = killer pids of the last kills (newest last).
static func human_share_ok(recent: Array, human_ids: Array, ks: Dictionary) -> bool:
	var window: int = int(ks.get("window", 24))
	var sample: Array = recent.slice(maxi(0, recent.size() - window))
	if sample.size() < int(ks.get("min_sample", 6)):
		return true
	var human: int = 0
	for pid: Variant in sample:
		if human_ids.has(int(pid)):
			human += 1
	return float(human) / float(sample.size()) >= float(ks.get("human_min_share", 0.45))


## The wall weapon to buy next: the first wishlist entry on the map that is better than everything held
## (earlier in the wishlist = better; unlisted held guns count as worst) and affordable with the buffer.
## `prices` = weapon id -> wall price for the wall-buys on this map. Returns &"" for nothing.
static func pick_weapon(wishlist: Array, held: Array, scrip: int, prices: Dictionary, buffer: int) -> StringName:
	var best_held: int = wishlist.size()
	for h: Variant in held:
		var i: int = wishlist.find(String(h))
		if i >= 0:
			best_held = mini(best_held, i)
	for i2: int in range(0, mini(best_held, wishlist.size())):
		var wid: String = str(wishlist[i2])
		if prices.has(wid) and scrip >= int(prices[wid]) + buffer:
			return StringName(wid)
	return &""


## The perk to drink next: the first wishlist perk not owned and affordable, while under max_perks.
## `prices` = perk id -> price for machines that can sell to this bot right now.
static func pick_perk(wishlist: Array, owned: Array, scrip: int, prices: Dictionary, max_perks: int, buffer: int) -> StringName:
	if owned.size() >= max_perks:
		return &""
	for p: Variant in wishlist:
		var pid: String = str(p)
		if owned.has(pid) or owned.has(StringName(pid)):
			continue
		if prices.has(pid) and scrip >= int(prices[pid]) + buffer:
			return StringName(pid)
	return &""


## Doors (shopping.doors): may this bot buy one now? `since_round_start` seconds into the round, `bought` doors
## this bot opened this round.
static func door_allowed(d: Dictionary, since_round_start: float, bought: int) -> bool:
	if not bool(d.get("enabled", true)):
		return false
	if since_round_start < float(d.get("round_delay_s", 20.0)):
		return false
	return bought < int(d.get("max_per_round_per_bot", 1))


## The door to buy: `doors` = [{"cost": int, "pos": Vector3, "ok": bool (usable and reachable)}, ...]. Affordable
## with the reserve, preferring the one the human looks at (human_look_cone_deg) and the one nearest the human
## (near_bonus_m - distance). Returns the index in `doors`, or -1.
static func pick_door(d: Dictionary, doors: Array, scrip: int, human_pos: Vector3, human_fwd: Vector3) -> int:
	var best: int = -1
	var best_s: float = -INF
	for i: int in doors.size():
		var door: Dictionary = doors[i]
		if not bool(door.get("ok", true)) or scrip < int(door.get("cost", 0)) + int(d.get("reserve_scrip", 0)):
			continue
		var pos: Vector3 = door.get("pos", Vector3.ZERO)
		var dist: float = Vector2(pos.x - human_pos.x, pos.z - human_pos.z).length()
		var s: float = maxf(0.0, float(d.get("near_bonus_m", 14.0)) - dist)
		if in_fire_cone(human_pos, human_fwd, pos, float(d.get("human_look_cone_deg", 35.0)), 60.0):
			s += 20.0
		if s > best_s:
			best_s = s
			best = i
	return best


## Crucible ammo (shopping.crucible): the upgraded gun in hand is under ammo_below_frac of its reserve and the
## ammo price plus ammo_reserve_scrip is in hand.
static func crucible_ammo_wanted(c: Dictionary, upgraded: bool, reserve: int, reserve_max: int, scrip: int, cost: int) -> bool:
	if not bool(c.get("enabled", true)) or not upgraded or reserve_max <= 0:
		return false
	if float(reserve) >= float(reserve_max) * float(c.get("ammo_below_frac", 0.35)):
		return false
	return scrip >= cost + int(c.get("ammo_reserve_scrip", 0))


## Crucible (shopping.crucible): worth feeding the gun in hand? `can_upgrade` = the gun has an upgrade and isn't
## upgraded yet; `cost` = the upgrade price.

static func crucible_wanted(c: Dictionary, can_upgrade: bool, scrip: int, cost: int, round_number: int) -> bool:
	if not bool(c.get("enabled", true)) or not can_upgrade:
		return false
	if round_number < int(c.get("min_round", 8)):
		return false
	return scrip >= cost + int(c.get("reserve_scrip", 0))


## Aim error (degrees) `t` seconds after picking a target: starts wide and settles like a person's.

static func aim_error_deg(sk: Dictionary, t: float) -> float:
	var a: float = float(sk.get("aim_error_deg", 3.0))
	var s: float = float(sk.get("settle_error_deg", 1.0))
	var tau: float = maxf(0.05, float(sk.get("settle_s", 0.5)))
	return s + (a - s) * exp(-maxf(0.0, t) / tau)


## A value from a [min, max] pair in the tuning.
static func range_roll(pair: Variant, rng: RandomNumberGenerator, fallback: float) -> float:
	if pair is Array and (pair as Array).size() >= 2:
		return rng.randf_range(float(pair[0]), float(pair[1]))
	return fallback


## Formation slot offset (leader-local, -Z forward) for the i-th bot.
static func slot_offset(follow: Dictionary, i: int) -> Vector3:
	var angles: Array = follow.get("slot_angles_deg", [180])
	var a: float = deg_to_rad(float(angles[i % angles.size()]))
	var r: float = float(follow.get("slot_radius_m", 3.0)) + 0.6 * float(i / angles.size())
	return Vector3(sin(a) * r, 0.0, -cos(a) * r)


## True when `p` stands in the cone in front of a shooter at `origin` facing `fwd` (both flat).
static func in_fire_cone(origin: Vector3, fwd: Vector3, p: Vector3, cone_deg: float, max_range: float) -> bool:
	var to: Vector3 = p - origin
	to.y = 0.0
	var d: float = to.length()
	if d < 0.3 or d > max_range:
		return false
	var f: Vector3 = Vector3(fwd.x, 0.0, fwd.z)
	if f.length_squared() < 0.0001:
		return false
	return f.normalized().angle_to(to / d) < deg_to_rad(cone_deg)


## Shooting from `a` to `b` would pass within `radius` of `p` (a teammate in the way).
static func blocks_shot(a: Vector3, b: Vector3, p: Vector3, radius: float) -> bool:
	var ab: Vector3 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.0001:
		return false
	var t: float = (p - a).dot(ab) / len2
	if t <= 0.02 or t >= 0.98:
		return false
	return (a + ab * t).distance_to(p) < radius


# ---------------------------------------------------------------- U02 section 5: bonus perk, commands, doorways

## The squad's bonus perks (bots.json bonus_perk): one per bot, drawn from the perks the map sells (`map_perks`,
## the perk machines on it), never a spawn-kit perk (`kit_perks`) or an `exclude` one, no two bots the same.
## When the pool runs out the later bots get &"". `rng` makes the draw repeatable in tests.
static func pick_bonus_perks(bcfg: Dictionary, map_perks: Array, kit_perks: Array, n: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	if not bool(bcfg.get("enabled", true)) or n <= 0:
		return out
	var excl: Array = bcfg.get("exclude", [])
	var pool: Array[String] = []
	for p: Variant in map_perks:
		var pid: String = str(p)
		if pid == "" or pool.has(pid) or excl.has(pid) or kit_perks.has(pid) or kit_perks.has(StringName(pid)):
			continue
		pool.append(pid)
	pool.sort()   # the draw depends on the rng only, not on the scene's node order
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: String = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	for k: int in n:
		out.append(StringName(pool[k]) if k < pool.size() else &"")
	return out


## Bonus perks are on: the "Bot Bonus Perk" setting (bot_bonus_perk, default on) and bots.json bonus_perk.enabled.
static func bonus_enabled(settings_values: Dictionary, bcfg: Dictionary) -> bool:
	return bool(settings_values.get("bot_bonus_perk", true)) and bool(bcfg.get("enabled", true))


## The bonus perk's announcement trigger (bots.json bonus_perk.triggers): "reload", "fire", "sprint",
## "headshot", "swap", "explosion", "overclock", "hurt", "revive"; "" = only the round fallback.
static func bonus_trigger(bcfg: Dictionary, perk_id: StringName) -> String:
	return str((bcfg.get("triggers", {}) as Dictionary).get(String(perk_id), ""))


## The squad's standing orders (BotSquad.command, the T-031 / U02 set). Update 03: every order in the wheel's data
## list (bots.json commands.orders) reaches the brains (BotBrain.on_order) as a high-weight action for 60 s or
## until done (data/gravelight/ai/actions.json orders); these four also set the squad's standing order.
const COMMANDS: Array[StringName] = [&"follow", &"hold", &"repair", &"revive"]


## The command wheel's orders, clockwise from the top (bots.json commands.orders: [{"id", "label", "vo"?}]).
## Falls back to COMMANDS when the table has none.
static func orders(c: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Variant in (c.get("commands", {}) as Dictionary).get("orders", []):
		if o is Dictionary and str((o as Dictionary).get("id", "")) != "":
			out.append(o as Dictionary)
	if out.is_empty():
		for id: StringName in COMMANDS:
			out.append({"id": String(id), "label": String(id).capitalize()})
	return out


static func order_ids(c: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for o: Dictionary in orders(c):
		out.append(StringName(str(o["id"])))
	return out


## An order's label for people ("Hold here"); the id capitalised when the table has none.
static func order_label(c: Dictionary, id: StringName) -> String:
	for o: Dictionary in orders(c):
		if StringName(str(o["id"])) == id:
			return str(o.get("label", String(id).capitalize()))
	return String(id).capitalize()


## The wheel segment a look vector points at (screen space, -y up): 0 at the top, clockwise; -1 inside the
## dead zone.
static func wheel_index(v: Vector2, segments: int, deadzone: float) -> int:
	if segments <= 0 or v.length() < deadzone:
		return -1
	var a: float = fposmod(atan2(v.x, -v.y), TAU)   # 0 = up, clockwise
	var step: float = TAU / float(segments)
	return int(floor(fposmod(a + step * 0.5, TAU) / step)) % segments


## Nudge / doorway rule: should a bot at `me` step aside for a human at `human` moving with velocity `hv`?
## True when the human is within `near_m`, moving at least `min_speed` and heading at the bot (within
## `cone_deg`), or when the bot stands in a choke point (`in_choke`) with the human within `choke_near_m`.
static func should_step_aside(me: Vector3, human: Vector3, hv: Vector3, in_choke: bool, f: Dictionary) -> bool:
	var to_me: Vector3 = me - human
	to_me.y = 0.0
	var d: float = to_me.length()
	if in_choke and d < float(f.get("choke_near_m", 4.0)):
		return true
	var flat_v: Vector3 = Vector3(hv.x, 0.0, hv.z)
	if d > float(f.get("nudge_near_m", 1.6)) or d < 0.01 or flat_v.length() < float(f.get("nudge_min_speed", 1.0)):
		return false
	return flat_v.normalized().angle_to(to_me / d) < deg_to_rad(float(f.get("nudge_cone_deg", 50.0)))


## Which way to step: perpendicular to the human's heading `hv`, on the side the bot already leans to (`me`
## relative to `human`); straight away from the human when they stand still.
static func step_aside_dir(me: Vector3, human: Vector3, hv: Vector3) -> Vector3:
	var to_me: Vector3 = me - human
	to_me.y = 0.0
	var flat_v: Vector3 = Vector3(hv.x, 0.0, hv.z)
	if flat_v.length() < 0.2:
		return to_me.normalized() if to_me.length() > 0.01 else Vector3.RIGHT
	var fwd: Vector3 = flat_v.normalized()
	var side: Vector3 = Vector3(-fwd.z, 0.0, fwd.x)
	if side.dot(to_me) < 0.0:
		side = -side
	return side


## A narrow passage: walls within `half_width_m` on both sides.
static func is_narrow(left_m: float, right_m: float, half_width_m: float) -> bool:
	return left_m <= half_width_m and right_m <= half_width_m


## Formation slot for the i-th bot while the leader moves (training): beside and a little ahead of the leader's
## heading, so the bots move with them and never fill the space behind them (where the leader backs into and the
## horde follows). `heading` is the leader's flat velocity direction; follow.moving_slots = [[lateral_m, ahead_m],
## ...] (+lateral = the heading's left). Returns a world-space offset.
static func moving_slot_offset(follow: Dictionary, i: int, heading: Vector3) -> Vector3:
	var fwd: Vector3 = Vector3(heading.x, 0.0, heading.z)
	if fwd.length() < 0.01:
		return Vector3.ZERO
	fwd = fwd.normalized()
	var left: Vector3 = Vector3(fwd.z, 0.0, -fwd.x)
	var slots: Array = follow.get("moving_slots", [[2.2, 0.8], [-2.2, 0.8], [3.4, 2.2]])
	var s: Array = slots[i % slots.size()]
	var extra: float = 0.6 * float(i / slots.size())
	return left * (float(s[0]) + signf(float(s[0])) * extra) + fwd * float(s[1])
