class_name HorseGait
extends RefCounted
## The horse's gaits as pure rules (T-240; the living horse in the Inn's yard and the undead ones share them). No
## nodes: the rig (HorseRig) asks these for where a hoof is at a stride phase, how the body rides and how the head
## nods; the tests (test_horse_gait.gd) ask them for the beats.
##   - STAND: four feet down, weight shifts.
##   - WALK: four-beat lateral sequence (left hind, left fore, right hind, right fore), two or three feet down.
##   - TROT: two-beat, diagonal pairs (left hind + right fore, right hind + left fore), a short suspension between.
##   - GALLOP: four-beat transverse (left hind, right hind, left fore, right fore: the right lead), then all four
##     feet off the ground (the suspension).
## Legs: 0 left hind, 1 left fore, 2 right hind, 3 right fore. A stride phase is 0..1. Forward is -Z.

enum Gait { STAND, WALK, TROT, GALLOP }

const LH: int = 0
const LF: int = 1
const RH: int = 2
const RF: int = 3
const LEG_NAMES: PackedStringArray = ["LH", "LF", "RH", "RF"]

## When each leg's stance begins (stride phase) and the share of the stride it stays down (the duty factor).
const OFFSETS: Dictionary = {
	Gait.STAND: [0.0, 0.25, 0.5, 0.75],
	Gait.WALK: [0.0, 0.25, 0.5, 0.75],
	Gait.TROT: [0.0, 0.5, 0.5, 0.0],
	Gait.GALLOP: [0.0, 0.4, 0.12, 0.52],
}
const DUTY: Dictionary = {Gait.STAND: 1.0, Gait.WALK: 0.64, Gait.TROT: 0.42, Gait.GALLOP: 0.26}
## Speeds (m/s) a gait is meant for: [slowest, cruise, fastest]; strides per second at the cruise speed.
const SPEEDS: Dictionary = {
	Gait.STAND: [0.0, 0.0, 0.15],
	Gait.WALK: [0.15, 1.9, 2.6],
	Gait.TROT: [2.6, 4.6, 6.2],
	Gait.GALLOP: [6.2, 9.5, 12.0],
}
const STRIDE_HZ: Dictionary = {Gait.STAND: 0.0, Gait.WALK: 0.95, Gait.TROT: 1.45, Gait.GALLOP: 2.0}
## How high a hoof lifts in its swing (m): [hind, fore].
const LIFT: Dictionary = {Gait.STAND: [0.0, 0.0], Gait.WALK: [0.10, 0.13], Gait.TROT: [0.17, 0.22], Gait.GALLOP: [0.26, 0.34]}
const HYSTERESIS: float = 0.35   # m/s: a gait is kept this far past its border before it changes


## The gait for `speed` (m/s, >= 0), keeping `current` inside a hysteresis band so it never flutters at a border.
static func gait_for(speed: float, current: int = Gait.STAND) -> int:
	var s: float = absf(speed)
	var natural: int = Gait.GALLOP
	if s < 0.15:
		natural = Gait.STAND
	elif s < 2.6:
		natural = Gait.WALK
	elif s < 6.2:
		natural = Gait.TROT
	if natural == current:
		return current
	if current == Gait.STAND:
		return natural   # (a standing horse steps off at once)
	if s < 0.08:
		return Gait.STAND
	var cur: Array = SPEEDS[current]
	if s > float(cur[2]) + HYSTERESIS or s < float(cur[0]) - HYSTERESIS:
		return natural
	return current


static func gait_name(g: int) -> String:
	return ["stand", "walk", "trot", "gallop"][clampi(g, 0, 3)]


## Strides per second at `speed`: the cruise rate, quicker and slower with the speed inside the gait (a stride also
## lengthens, so the rate moves by the square root).
static func stride_hz(g: int, speed: float) -> float:
	if g == Gait.STAND:
		return 0.0
	var cruise: float = float((SPEEDS[g] as Array)[1])
	return float(STRIDE_HZ[g]) * sqrt(clampf(absf(speed) / cruise, 0.3, 1.8))


## Metres covered per stride at `speed`.
static func stride_length(g: int, speed: float) -> float:
	var hz: float = stride_hz(g, speed)
	return absf(speed) / hz if hz > 0.0 else 0.0


static func duty(g: int) -> float:
	return float(DUTY[g])


## The leg's own phase: 0 as its hoof lands, `duty` as it leaves the ground, 1 as it lands again.
static func leg_phase(g: int, leg: int, phase: float) -> float:
	return fposmod(phase - float((OFFSETS[g] as Array)[leg]), 1.0)


static func in_stance(g: int, leg: int, phase: float) -> bool:
	return g == Gait.STAND or leg_phase(g, leg, phase) < duty(g)


## Hooves on the ground at `phase`.
static func feet_down(g: int, phase: float) -> int:
	var n: int = 0
	for leg: int in 4:
		if in_stance(g, leg, phase):
			n += 1
	return n


## True when the gait has a moment with no hoof on the ground (the trot's and the gallop's suspension).
static func has_suspension(g: int) -> bool:
	for i: int in 200:
		if feet_down(g, float(i) / 200.0) == 0:
			return true
	return false


## The distinct footfall times in a stride (hooves landing within `merge` of each other are one beat).
static func beats(g: int, merge: float = 0.03) -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	if g == Gait.STAND:
		return out
	var offs: Array = (OFFSETS[g] as Array).duplicate()
	offs.sort()
	for o: Variant in offs:
		var t: float = float(o)
		if out.is_empty() or t - out[out.size() - 1] > merge:
			out.append(t)
	return out


## The legs whose hooves land between `from` and `to` (stride phases; `to` may have wrapped past 1).
static func landings(g: int, from: float, to: float) -> PackedInt32Array:
	var out: PackedInt32Array = []
	if g == Gait.STAND:
		return out
	for leg: int in 4:
		var o: float = float((OFFSETS[g] as Array)[leg])
		var hit: bool = (o > from and o <= to) if to >= from else (o > from or o <= to)
		if hit:
			out.append(leg)
	return out


## Where a hoof is relative to its place under the body, at a stride phase: x unused, y the lift, z the reach
## (-Z ahead). In stance it travels back at the body's speed (so it does not slide: the reach is speed x the stance
## time), in the swing it comes forward on an arc. `speed` signed: a horse backing up swings its feet the other way.
static func hoof_offset(g: int, leg: int, phase: float, speed: float) -> Vector3:
	if g == Gait.STAND:
		return Vector3.ZERO
	var hz: float = stride_hz(g, speed)
	if hz <= 0.0:
		return Vector3.ZERO
	var d: float = duty(g)
	var reach: float = speed * d / hz            # metres the hoof travels on the ground
	var lp: float = leg_phase(g, leg, phase)
	if lp < d:
		var s: float = lp / d
		return Vector3(0.0, 0.0, -reach * (0.5 - s))
	var u: float = (lp - d) / (1.0 - d)
	var e: float = u * u * (3.0 - 2.0 * u)
	var lift: float = float((LIFT[g] as Array)[0 if leg == LH or leg == RH else 1])
	# the hoof leaves the ground late and lands flat: the arc peaks a little before the middle of the swing
	var arc: float = sin(PI * pow(u, 0.85))
	return Vector3(0.0, lift * arc, -reach * (e - 0.5))


## The body's rise and fall over a stride (m): the walk barely moves, the trot bounces twice a stride (up through
## each suspension), the gallop rises once (up through its suspension).
static func body_bob(g: int, phase: float) -> float:
	match g:
		Gait.WALK:
			return 0.012 * cos(TAU * 2.0 * (phase - 0.07))
		Gait.TROT:
			return 0.038 * -cos(TAU * 2.0 * (phase - 0.21))
		Gait.GALLOP:
			return 0.085 * -cos(TAU * (phase - 0.2))
	return 0.0


## The body's pitch over a stride (radians, positive = the forehand up): the gallop rocks (the forehand lifts
## through the suspension and comes down onto the leading leg).
static func body_pitch(g: int, phase: float) -> float:
	match g:
		Gait.WALK:
			return 0.008 * sin(TAU * 2.0 * phase)
		Gait.GALLOP:
			return 0.075 * sin(TAU * (phase - 0.02))
	return 0.0


## The body's roll over a stride (radians): the walk sways over the hind foot bearing the weight.
static func body_roll(g: int, phase: float) -> float:
	match g:
		Gait.WALK:
			return 0.022 * sin(TAU * (phase + 0.1))
		Gait.TROT:
			return 0.008 * sin(TAU * phase)
	return 0.0


## The head's nod over a stride (radians added to the neck, positive = the head down): at the walk the head drops as
## each forefoot takes the weight; at the trot it is carried still; at the gallop the neck reaches down and forward
## as the forehand lands and lifts through the suspension.
static func head_nod(g: int, phase: float) -> float:
	match g:
		Gait.WALK:
			return 0.07 * cos(TAU * 2.0 * (phase - 0.33))
		Gait.TROT:
			return 0.012 * cos(TAU * 2.0 * phase)
		Gait.GALLOP:
			return 0.16 * cos(TAU * (phase - 0.6))
	return 0.0


## What the rider feels at a stride phase: [rise (m), pitch (rad), roll (rad)] of the saddle.
static func saddle_motion(g: int, phase: float) -> Vector3:
	return Vector3(body_bob(g, phase), body_pitch(g, phase), body_roll(g, phase))
