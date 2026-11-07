extends CinemaSet
## T-194, LAZARUS SATURDAY set F (§6.1, after the respect review R-03): the mortuary room off the fever ward of the
## district hospital on 18 April 1930: a cold whitewashed room where the dead wait for the cart. Plank trestles along
## the left wall (z 0 to -12), three at the near end with a body under a sheet drawn up over the face, the rest bare;
## a tag on a nail by the nearest (18.IV.30), a frosted window, an oil lamp on a stool; at the far end the open door to
## the ward, warm, and the nurse's back in it in a white kerchief. On the nearest a bandaged hand lies outside the
## sheet. Shot 28: the sheet moves once at the chest, the hand turns over, and the cut comes before anything sits up.
## Gore "full": a stain spreads at the bitten hand. Markers: NearSheet, Chart. Effects: sheet_breath, stain.

var chest: MeshInstance3D
var hand: Node3D
var stain: MeshInstance3D


func _build() -> void:
	env({"bg": [0.5, 0.5, 0.48], "ambient": [0.66, 0.68, 0.7], "ambient_e": 0.6, "fog": [0.6, 0.6, 0.6], "fog_d": 0.012, "glow_t": 1.3})
	var wash: Variant = "limewash"
	box(self, Vector3(0, -0.05, -6), Vector3(6.4, 0.1, 13.0), "stone")
	box(self, Vector3(0, 3.45, -6), Vector3(6.4, 0.1, 13.0), wash)
	box(self, Vector3(-3.2, 1.7, -6), Vector3(0.12, 3.5, 13.0), wash)
	box(self, Vector3(3.2, 1.7, -6), Vector3(0.12, 3.5, 13.0), wash)
	box(self, Vector3(0, 1.7, 0.6), Vector3(6.4, 3.5, 0.12), wash)
	# the far wall and the open door to the fever ward: warm lamplight beyond, the nurse's back in it
	box(self, Vector3(-1.9, 1.7, -12.5), Vector3(2.6, 3.5, 0.12), wash)
	box(self, Vector3(1.9, 1.7, -12.5), Vector3(2.6, 3.5, 0.12), wash)
	box(self, Vector3(0, 2.95, -12.5), Vector3(1.2, 1.1, 0.12), wash)
	box(self, Vector3(0, 1.2, -14.5), Vector3(4.0, 2.4, 0.1), glow(Color(0.9, 0.78, 0.6), 0.7))
	omni(self, Vector3(0, 1.8, -13.6), [1.0, 0.8, 0.55], 1.2, 5.0)
	var nurse: CinemaPerson = person(self, "nurse", look_of("nurse"), Vector3(0.1, 0, -13.0), 0.0, "stand")
	nurse.name = "Nurse"
	# the window in the right wall: frost, the grey day behind it
	box(self, Vector3(3.14, 1.9, -5.0), Vector3(0.04, 1.5, 1.1), glow(Color(0.78, 0.8, 0.82), 1.3))
	for wy: float in [1.15, 1.9, 2.65]:
		box(self, Vector3(3.1, wy, -5.0), Vector3(0.06, 0.06, 1.2), "#d8d4c8")
	box(self, Vector3(3.1, 1.9, -5.0), Vector3(0.06, 1.55, 0.06), "#d8d4c8")
	spot(self, Vector3(2.6, 2.3, -5.0), Vector3(-1.5, 0.6, -4.0), [0.86, 0.9, 1.0], 2.4, 10.0, 48.0)
	sun(Vector3(-55, 80, 0), [0.85, 0.88, 0.92], 0.25)
	for i: int in 5:
		_trestle(Vector3(-2.2, 0, -1.6 - 2.1 * float(i)), i < 3, i == 0)
	# the tag on its nail by the nearest: a date, 18.IV.30
	var ch: Node3D = group(self, "Chart", Vector3(-3.12, 1.45, -1.0))
	box(ch, Vector3.ZERO, Vector3(0.02, 0.22, 0.16), "paper_old")
	words(ch, "18.IV.30", Vector3(0.015, 0.03, 0.0), 0.0014, Color(0.18, 0.16, 0.14), 90.0)
	box(self, Vector3(-1.1, 0.4, -5.0), Vector3(0.36, 0.8, 0.36), "furniture")   # a stool and the lamp on it
	var lamp: Node3D = prop(self, "lamp_oil_table", Vector3(-1.1, 0.82, -5.0), 0.0)
	if lamp == null:
		box(self, Vector3(-1.1, 0.95, -5.0), Vector3(0.12, 0.25, 0.12), glow(Color(1.0, 0.8, 0.5), 1.5))
	var ll: OmniLight3D = omni(self, Vector3(-1.1, 1.2, -5.0), [1.0, 0.78, 0.5], 0.7, 6.0)
	ll.set_meta("flicker", 0.7)
	ll.add_to_group(&"cinema_flicker")


## A plank board on two trestles; `covered`: a body under a sheet drawn up over the face.
func _trestle(at: Vector3, covered: bool, nearest: bool) -> void:
	var g: Node3D = group(self, "Trestle", at)
	for ex: float in [-0.75, 0.75]:
		box(g, Vector3(ex, 0.35, 0), Vector3(0.08, 0.7, 0.7), "beam", Vector3(0, 0, 0))
	box(g, Vector3(0, 0.74, 0), Vector3(2.0, 0.06, 0.7), "planks")
	if not covered:
		return
	var sheet: StandardMaterial3D = flat(Color(0.84, 0.83, 0.79), 0.95)
	ball(g, Vector3(-0.72, 0.85, 0), Vector3(0.26, 0.2, 0.24), sheet)
	var c: MeshInstance3D = ball(g, Vector3(-0.25, 0.83, 0), Vector3(0.62, 0.2, 0.5), sheet)
	ball(g, Vector3(0.45, 0.8, 0), Vector3(0.95, 0.14, 0.42), sheet)
	box(g, Vector3(0.0, 0.78, 0), Vector3(1.95, 0.04, 0.74), sheet)
	if nearest:
		g.name = "NearBoard"
		chest = c
		marker("NearSheet", at + Vector3(-0.2, 0.9, 0))
		hand = group(g, "Hand", Vector3(-0.15, 0.8, 0.4))
		box(hand, Vector3(0, 0, 0), Vector3(0.09, 0.03, 0.16), "linen")
		for f: int in 4:
			box(hand, Vector3(-0.03 + 0.02 * float(f), 0, 0.1), Vector3(0.016, 0.018, 0.06), "#c9a891")
		stain = plane(g, Vector3(-0.15, 0.802, 0.28), Vector2(0.01, 0.01), flat(Color(0.28, 0.04, 0.03, 0.85), 0.6), Vector3.ZERO, "Stain")
		stain.add_to_group(&"gore_full")


## Shot 28: the sheet draws one breath at the chest; then the bandaged hand turns over. Cut before anything sits up.
func fx_sheet_breath(secs: float) -> void:
	if chest == null:
		return
	var base: Vector3 = Vector3(0.62, 0.2, 0.5)
	var tw: Tween = create_tween()
	tw.tween_interval(secs * 0.25)
	tw.tween_property(chest, "scale", Vector3(0.64, 0.27, 0.53), secs * 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(chest, "scale", base, secs * 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hand, "rotation:z", PI * 0.85, secs * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Gore full: the stain spreads on the sheet at the hand.
func fx_stain(secs: float) -> void:
	if stain == null or gore() != "full":
		return
	var pm: PlaneMesh = stain.mesh as PlaneMesh
	pm.size = Vector2(0.01, 0.01)
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void: pm.size = Vector2(0.01, 0.01).lerp(Vector2(0.22, 0.16), k), 0.0, 1.0, secs * 0.8).set_trans(Tween.TRANS_SINE)
