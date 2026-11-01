class_name NetSignaling
extends Node
## WebRTC signaling for one lobby (UPDATE 09 section 2a, docs/U09_CONTRACTS.md C3, DECISIONS T-138).
##
## Before two games can talk peer to peer they swap a few small messages through a third party: who is there
## ("hello"), the session descriptions ("offer" / "answer"), the network candidates ("ice") and goodbyes ("bye").
## This is the abstract channel for those messages; `SupabaseSignaling` sends them through Supabase Realtime
## broadcast, `MockSignaling` through the tiny local relay (`MockSignalServer`) the tests start.
##
## Addressing: every member of the lobby channel has a string id. The host is always "host"; each client picks a
## random id (`self_id`) before it has a network peer id. A message is sent to one id, or to "*" (everyone).
## Every message on the wire is one JSON object `{"from", "to", "kind", "payload"}` (encode / decode below), so
## both transports and the tests share one format. Messages may be lost or duplicated: the callers resend
## "hello" until answered and ignore repeats.

signal message(from_peer: String, kind: String, payload: Dictionary)
## The channel is joined: messages can be sent now.
signal channel_ready
## The channel closed (or never opened). `reason` is a short human sentence.
signal channel_closed(reason: String)

const HOST_ID: String = "host"
const EVERYONE: String = "*"
const KINDS: PackedStringArray = ["offer", "answer", "ice", "hello", "bye"]
const MAX_MESSAGE_BYTES: int = 32768
const ID_ALPHABET: String = "abcdefghijkmnpqrstuvwxyz23456789"

var code: String = ""
var is_host: bool = false
var self_id: String = ""


## Joins the lobby's channel (asynchronous: `channel_ready` or `channel_closed` follows).
func connect_lobby(lobby_code: String, host: bool) -> Error:
	code = lobby_code
	is_host = host
	self_id = HOST_ID if host else random_id(12)
	return ERR_UNAVAILABLE


## Sends `kind` with `payload` to `to_peer` (an id, or "*").
func send(_to_peer: String, _kind: String, _payload: Dictionary) -> void:
	pass


func close() -> void:
	pass


func is_ready() -> bool:
	return false


# ---------------------------------------------------------------- wire format (shared by every transport)

static func encode(from_id: String, to_id: String, kind: String, payload: Dictionary) -> Dictionary:
	return {"from": from_id, "to": to_id, "kind": kind, "payload": payload}


static func encode_text(from_id: String, to_id: String, kind: String, payload: Dictionary) -> String:
	return JSON.stringify(encode(from_id, to_id, kind, payload))


## A message for `my_id`, checked: a Dictionary with from / to / kind / payload, a known kind, addressed to
## `my_id` or to everyone, not sent by `my_id` itself. Anything else returns {} (dropped).
static func decode(msg: Variant, my_id: String) -> Dictionary:
	if msg is String:
		if (msg as String).length() > MAX_MESSAGE_BYTES:
			return {}
		msg = JSON.parse_string(msg as String)
	if not (msg is Dictionary):
		return {}
	var d: Dictionary = msg
	if not (d.get("from") is String and d.get("to") is String and d.get("kind") is String and d.get("payload") is Dictionary):
		return {}
	var from_id: String = d["from"]
	var to_id: String = d["to"]
	if from_id == "" or from_id == my_id or not KINDS.has(str(d["kind"])):
		return {}
	if to_id != my_id and to_id != EVERYONE:
		return {}
	return d


static func random_id(n: int) -> String:
	var out: String = ""
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	for i: int in n:
		out += ID_ALPHABET[rng.randi_range(0, ID_ALPHABET.length() - 1)]
	return out


## Hands a decoded message to the listeners (the transports call this).
func _deliver(d: Dictionary) -> void:
	if d.is_empty():
		return
	message.emit(str(d["from"]), str(d["kind"]), d["payload"] as Dictionary)
