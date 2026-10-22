class_name MoveIntent
extends RefCounted
## What the shared Player movement code reads instead of Input (Update 03 section 3, T-056). The local human's
## Player fills it from the input actions every physics frame (Player._read_move_intent); a bot's BotLocomotion
## fills one and hands it to Player.drive_bot(), so bots walk, sprint, slide and mantle with exactly the
## human's rules (acceleration curves, stamina, sprint only forward-ish, the sprint-out, slide physics, mantles).
##
## `move` uses Input.get_vector's convention in the body's local frame: x = right, y = back (forward is -1).

var move: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var jump_held: bool = false
var sprint_pressed: bool = false
var sprint_held: bool = false
var crouch_pressed: bool = false
var crouch_held: bool = false
## Fire / ADS input cancels a sprint (the gun's sprint-out runs meanwhile).
var fire_pressed: bool = false
var fire_held: bool = false
var ads_held: bool = false


## Back to "no input" (a bot standing still).
func clear() -> void:
	move = Vector2.ZERO
	jump_pressed = false
	jump_held = false
	sprint_pressed = false
	sprint_held = false
	crouch_pressed = false
	crouch_held = false
	fire_pressed = false
	fire_held = false
	ads_held = false


## The local stick for a world-space wish direction `world` (length 0..1) given the body's basis: what a
## person would push to walk that way while facing where the body faces.
static func local_move(body_basis: Basis, world: Vector3) -> Vector2:
	var flat: Vector3 = Vector3(world.x, 0.0, world.z)
	if flat.length_squared() < 0.000001:
		return Vector2.ZERO
	var l: Vector3 = body_basis.inverse() * flat
	var v: Vector2 = Vector2(l.x, l.z)
	return v.limit_length(1.0)
