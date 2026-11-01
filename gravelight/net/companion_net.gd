class_name CompanionNet
extends RefCounted
## Companions online (C3, DECISIONS T-138): Jakub (JakubCompanion) and the map companions (MapCompanion) are
## simulated on the host only, exactly as offline (their Player + BotBrain, their state machine). Every client builds
## the same body as a puppet (a non-bot remote Player fed by the host's player stream, NetMatch._send_players), keeps
## the companion's state, weapon and lines in step through Net.mirror calls (`_net_state`, `_net_say`), and gets the
## Talk choice card on its own screen: the host sends it (`_net_card`), the answer comes back through a whitelisted
## call that carries the sender's pid (`net_by_choose`, `net_by_choose_tonic`; NetMatch.on_quest_request).

## A client: the companion here is a puppet (no brain, no state machine).
static func puppet_mode() -> bool:
	return Net.is_client()


## Host: `p` is a teammate playing on another machine (its card has to go there).
static func is_remote_human(p: Player) -> bool:
	return p != null and Net.is_host() and not p.is_local and not p.is_bot and not p.is_companion


## What can travel in an rpc: the same Dictionary without Objects (a WeaponInstance, a machine node).
static func wire(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d.keys():
		if not (d[k] is Object):
			out[k] = d[k]
	return out


## Host: open the choice card on `p`'s own screen (their machine calls companion._net_card).
static func send_card(companion: Node, p: Player, offer: Dictionary, tonic: Dictionary) -> void:
	var s: NetMatch = Net.session
	var peer: int = Net.peer_of(p.player_id)
	if s == null or peer <= 1 or not companion.is_inside_tree():
		return
	Net._rpc_world.rpc_id(peer, String(s.map.get_path_to(companion)), &"_net_card", [wire(offer), wire(tonic)])


## Client: an answer for the host's companion.
static func forward(companion: Node, method: StringName, args: Array) -> void:
	if Net.session != null and companion.is_inside_tree():
		Net.session.request_call(companion, method, args)


## Host: the Player behind a request's pid.
static func player_for(pid: int) -> Player:
	return Net.session.players.get(pid) as Player if Net.session != null else null


## Host: mirrors `now` (the companion's state signature) to the clients when it changed; returns it.
static func sync(companion: Node, last: Array, now: Array) -> Array:
	if Net.replicating() and now != last:
		Net.mirror(companion, &"_net_state", now)
	return now


## Client: registers the puppet body so the player stream, revives and nameplates find it.
static func register_puppet(p: Player) -> void:
	if Net.session != null and p != null:
		Net.session.companions[p.player_id] = p
