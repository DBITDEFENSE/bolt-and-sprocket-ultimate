class_name BreachDoor
extends BuyDoor
## Werk Thalbach's `Breach_E_apron` (UPDATE 10 Act I, DECISIONS T-155): the hole the air raid blows through
## Montage 2's north wall into the test stands. Until the raid it is sealed (hidden, no prompt, no collider: the
## wall plug stands where it is). After the fall it is a plain Prüfstand door in the "pruefstand" link group: open
## already if the stands were bought (the group opened it, unseen), else buyable at the group's price, so the raid
## never hands out a free zone. ThalbachRaid calls set_sealed().

var sealed: bool = true


func _ready() -> void:
	super._ready()
	add_to_group(&"a1_breach")
	_apply_sealed()


func set_sealed(v: bool) -> void:
	sealed = v
	_apply_sealed()


func _apply_sealed() -> void:
	if not is_inside_tree():
		return
	visible = not sealed and not is_open
	if area != null:
		area.collision_layer = 0 if (sealed or is_open) else LAYER_INTERACTABLE
	if _body != null:
		_body.collision_layer = 0 if (sealed or is_open) else LAYER_DOOR


func get_prompt(player: Player) -> String:
	if sealed:
		return ""
	return super.get_prompt(player)


func can_interact(player: Player) -> bool:
	return not sealed and super.can_interact(player)
