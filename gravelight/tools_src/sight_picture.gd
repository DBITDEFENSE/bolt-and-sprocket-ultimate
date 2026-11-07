class_name SightPicture
extends RefCounted
## T-182: what the eye actually sees through the sights when fully aimed, measured from the gun's triangles (no
## GPU). ads_check (T-047) proves the SightPoint / FrontSight markers sit on the aim point; this proves the sight
## GEOMETRY does: a ray per pixel round the aim point (pure ADS pose, the rig's viewmodel-FOV scale and compression,
## 720 p at the camera's FOV) finds the nearest triangle of the held model, and its depth says which sight it
## belongs to (nearer than half way from the rear marker's depth to the front marker's = the rear sight, farther =
## the front sight). From that:
##   post_x / post_w   the front post's (blade, bead) horizontal centre and width two rows under its tip (px, + right;
##                     0 = centred on the aim point);
##   post_tip          how far the post's tip is below the aim point (px, + down; 0 = the tip on the aim point);
##   rear_x            the centre of the rear notch / aperture opening on the row the post's tip shows in (px);
##   rear_open         that opening's width (px);
##   hole_y            an aperture's hole centre (px, + down) when the rear sight closes above the aim point too;
##   err               the worst of |post_x|, |post_tip|, |rear_x|, |hole_y| (scoped guns: 0).
## Used by ads_check --geometry and test_ads_sight_geometry.

const HW: int = 48        # px either side of the aim point
const HH: int = 40
const CELL: int = 6       # binning cell, px
const H: float = 720.0
const NEAR: float = 0.01          # the player camera's near plane (Player: camera.near), camera space
const BLOCKED_ERR: float = 99.0   # err when the aim point sits on the rear sight or no front sight shows


## Camera-space triangles of the held model in the pure ADS pose (meshes hidden in the tree are left out).
static func _tris(h: WeaponHolder, names: Array = []) -> PackedVector3Array:
	var out: PackedVector3Array = []
	var model: Node3D = h.get("_model") as Node3D
	if model == null:
		return out
	var rig: Node3D = h.get("_rig") as Node3D
	var gun: Node3D = h.get("_gun") as Node3D
	var xf: Transform3D = rig.transform * Transform3D(Basis.from_euler(h.get("_ads_rot")), h.get("_ads")) * gun.transform * model.transform
	var items: Array = []   # [MeshInstance3D, camera-space transform]
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null or not _shown(mi, model):
			continue
		items.append([mi, xf * _rel(mi, model)])
	# the arms (hands, forearms, sleeves: each survivor's own meshes) as the last _animate posed them; they hold the
	# gun from below, but a big glove must not climb into the sight picture either
	var vm: Node3D = h.get("_vm") as Node3D
	for n2: Node in rig.get_children():
		if n2 == vm or not (n2 is Node3D) or not (n2 as Node3D).visible:
			continue
		var top: Node3D = n2 as Node3D
		var meshes: Array = top.find_children("*", "MeshInstance3D", true, false)
		if top is MeshInstance3D:
			meshes.append(top)
		for m2: Node in meshes:
			var mi2: MeshInstance3D = m2 as MeshInstance3D
			if mi2.mesh != null and _shown(mi2, top):
				items.append([mi2, rig.transform * top.transform * _rel(mi2, top)])
	for it: Array in items:
		var mi: MeshInstance3D = it[0]
		var full: Transform3D = it[1]
		var nm: String = "%s/%s" % [mi.get_parent().name, mi.name]
		for s: int in mi.mesh.get_surface_count():
			if _see_through(mi.get_active_material(s)):
				continue   # glass (the Panzerschreck's sighting window): the eye looks through it
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if ids.is_empty():
				for i: int in vs.size() - vs.size() % 3:
					out.append(full * vs[i])
					if i % 3 == 0:
						names.append(nm)
			else:
				for i2: int in ids.size() - ids.size() % 3:
					out.append(full * vs[ids[i2]])
					if i2 % 3 == 0:
						names.append(nm)
	return out


## `n`'s transform relative to its ancestor `top` (top's own transform left out).
static func _rel(n: Node, top: Node) -> Transform3D:
	var rel: Transform3D = Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != top:
		if c is Node3D:
			rel = (c as Node3D).transform * rel
		c = c.get_parent()
	return rel


static func _see_through(m: Material) -> bool:
	if m is BaseMaterial3D:
		var bm: BaseMaterial3D = m as BaseMaterial3D
		return bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and bm.albedo_color.a < 0.6
	return false


static func _shown(n: Node, top: Node) -> bool:
	var c: Node = n
	while c != null:
		if c is Node3D and not (c as Node3D).visible:
			return false
		if c == top:
			return true
		c = c.get_parent()
	return true


## The class grid: Dictionary Vector2i(px) -> "R" (the rear sight: nearer than half way from the rear marker's depth
## to the front marker's), "F" (the front sight: farther), "N" (well nearer than the rear sight: the receiver or
## hood right at the eye) or "B" (well beyond the front sight: the barrel's end, a muzzle device); missing = nothing
## there (the target shows). Also the marker depths and each pixel's depth share t (0 rear marker, 1 front marker).
static func classify(h: WeaponHolder, fov: float) -> Dictionary:
	var marks: Array = h.sight_marks_camera(false)
	if marks.size() < 2:
		return {}
	var zr: float = -(marks[0] as Vector3).z
	var zf: float = -(marks[1] as Vector3).z
	var f: float = H * 0.5 / tan(deg_to_rad(fov) * 0.5)
	var names: Array = []
	var tris: PackedVector3Array = _tris(h, names)
	var cells: Dictionary = {}
	for t: int in range(0, tris.size() - 2, 3):
		var lo: Vector2 = Vector2(INF, INF)
		var hi: Vector2 = Vector2(-INF, -INF)
		var ok: bool = true
		for k: int in 3:
			var p: Vector3 = tris[t + k]
			if p.z > -0.0001:
				ok = false
				break
			var s: Vector2 = Vector2(p.x / -p.z, -p.y / -p.z) * f
			lo = lo.min(s)
			hi = hi.max(s)
		if not ok or hi.x < -HW or lo.x > HW or hi.y < -HH or lo.y > HH:
			continue
		for cx: int in range(floori(maxf(lo.x, -HW) / CELL), floori(minf(hi.x, HW) / CELL) + 1):
			for cy: int in range(floori(maxf(lo.y, -HH) / CELL), floori(minf(hi.y, HH) / CELL) + 1):
				var key: Vector2i = Vector2i(cx, cy)
				if not cells.has(key):
					cells[key] = []
				(cells[key] as Array).append(t)
	var grid: Dictionary = {}
	var depth: Dictionary = {}
	var far: Dictionary = {}
	var who: Dictionary = {}   # px -> the mesh nearest the eye there
	var span: float = maxf(0.0001, zf - zr)
	for y: int in range(-HH, HH + 1):
		for x: int in range(-HW, HW + 1):
			var key2: Vector2i = Vector2i(floori(float(x) / CELL), floori(float(y) / CELL))
			if not cells.has(key2):
				continue
			var dir: Vector3 = Vector3(float(x) / f, -float(y) / f, -1.0)
			var best: float = INF
			var best_t: int = -1
			var best_far: float = INF   # the nearest hit beyond half way: the front sight as if the rear weren't there
			for t2: int in cells[key2] as Array:
				# scaled up x1000: the compressed viewmodel's triangles are so small that the intersection's
				# parallel-ray epsilon would reject them
				var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3.ZERO, dir, tris[t2] * 1000.0, tris[t2 + 1] * 1000.0, tris[t2 + 2] * 1000.0)
				if hit != null:
					var hz: float = -(hit as Vector3).z * 0.001
					if hz < NEAR:
						continue   # in front of the camera's near plane: clipped away when drawn
					if hz < best:
						best = hz
						best_t = t2
					if (hz - zr) / span >= 0.5:
						best_far = minf(best_far, hz)
			if best_far < INF:
				var tf: float = (best_far - zr) / span
				far[Vector2i(x, y)] = "F" if tf <= 1.6 else "B"
			if best == INF:
				continue
			var tt: float = (best - zr) / span
			var cls: String = "R" if tt < 0.5 else "F"
			if tt < -0.6:
				cls = "N"
			elif tt > 1.6:
				cls = "B"
			grid[Vector2i(x, y)] = cls
			depth[Vector2i(x, y)] = tt
			who[Vector2i(x, y)] = names[best_t / 3] if best_t >= 0 and best_t / 3 < names.size() else ""
	return {"grid": grid, "far": far, "depth": depth, "who": who, "zr": zr, "zf": zf}


## Fitting aid (ads_check --autofit): where on screen (px from the aim point) the rear sight's aim point is, from
## the near silhouette (R / N): the opening nearest the aim point with walls both sides; an aperture (closed above
## too) aims at its hole's centre, a notch at a quarter of its depth below its shoulders (the front post then shows
## level with them). {} when no opening is found.
static func rear_target(g: Dictionary) -> Dictionary:
	var near: Callable = func(x: int, y: int) -> bool:
		return str(g.get(Vector2i(x, y), "")) in ["R", "N"]
	var walls: Callable = func(x: int, y: int) -> Vector2i:   # (left wall x, right wall x) on row y round x, or (1, -1)
		var l: int = x
		while l > x - 18 and not near.call(l, y):
			l -= 1
		var r: int = x
		while r < x + 18 and not near.call(r, y):
			r += 1
		return Vector2i(l, r) if near.call(l, y) and near.call(r, y) else Vector2i(1, -1)
	var bestd: float = INF
	var o: Vector2i = Vector2i.ZERO
	for y: int in range(-22, 23):
		for x: int in range(-25, 26):
			if near.call(x, y):
				continue
			var w: Vector2i = walls.call(x, y)
			if w.x > w.y:
				continue
			# an opening has the sight's body under it (within 25 px)
			var below: bool = false
			for yy: int in range(y + 1, y + 26):
				if near.call(x, yy):
					below = true
					break
			if not below:
				continue
			var d: float = Vector2(x, y).length()
			if d < bestd:
				bestd = d
				o = Vector2i(x, y)
	if bestd == INF:
		return {}
	var w0: Vector2i = walls.call(o.x, o.y)
	var cx: int = roundi((w0.x + w0.y) * 0.5)
	var yb: int = o.y
	while yb < HH and not near.call(cx, yb):
		yb += 1                                  # first near row under the opening: the notch bottom / ring
	var yt: int = o.y
	var closed: bool = false
	while yt > -HH:
		if near.call(cx, yt - 1):
			closed = true                         # an aperture: the ring closes above
			break
		var wt: Vector2i = walls.call(cx, yt - 1)
		if wt.x > wt.y:
			break                                 # above the shoulders
		yt -= 1
	var ty: float = (yt + yb - 1) * 0.5 if closed else yt + maxf(1.0, 0.25 * float(yb - yt))
	var wr: Vector2i = walls.call(cx, roundi(ty))
	var tx: float = (wr.x + wr.y) * 0.5 if wr.x <= wr.y else float(cx)
	return {"at": Vector2(tx, ty), "kind": "aperture" if closed else "notch", "top": yt, "bottom": yb, "width": w0.y - w0.x - 1}


## Width of the F run through (x, y) on its row.
static func _run(at: Callable, x: int, y: int) -> int:
	if at.call(x, y) != "F":
		return 0
	var l: int = x
	while l > -HW and at.call(l - 1, y) == "F":
		l -= 1
	var r: int = x
	while r < HW and at.call(r + 1, y) == "F":
		r += 1
	return r - l + 1


## Fitting aid: the front post's tip (px from the aim point) in the far grid (the front sight even where the rear
## hides it), the post found as in measure_grid but preferring central columns. {} when none.
static func front_target(far: Dictionary) -> Dictionary:
	var at: Callable = func(x: int, y: int) -> String:
		return str(far.get(Vector2i(x, y), ""))
	var best: float = INF
	var tip: Vector2i = Vector2i.ZERO
	for y: int in range(-20, 31):
		for x: int in range(-30, 31):
			if at.call(x, y) != "F" or at.call(x, y - 1) == "F":
				continue
			if not (at.call(x, y + 1) == "F" and at.call(x, y + 2) == "F"):
				continue
			if _run(at, x, y) > 7 or _run(at, x, y + 1) > 7:
				continue   # widening fast: a hood's or a ring's arch, not a post
			var dd: float = Vector2(x * 2.0, y).length()
			if dd < best:
				best = dd
				tip = Vector2i(x, y)
	if best == INF:
		return {}
	var l: int = tip.x
	while l > -HW and at.call(l - 1, tip.y + 1) == "F":
		l -= 1
	var r: int = tip.x
	while r < HW and at.call(r + 1, tip.y + 1) == "F":
		r += 1
	var px: float = (l + r) * 0.5 if r - l + 1 <= 30 else float(tip.x)
	return {"at": Vector2(px, float(tip.y)), "width": r - l + 1}


## The measures in the class comment, for the held gun. `fov` = the camera's (ADS-zoomed) vertical FOV.
static func measure(h: WeaponHolder, fov: float) -> Dictionary:
	var out: Dictionary = {"post_x": 0.0, "post_w": 0.0, "post_tip": 0.0, "rear_x": 0.0, "rear_open": 0.0, "hole_y": 0.0,
		"err": 0.0, "scoped": false, "found_post": false, "found_rear": false, "blocked": false}
	var model: Node3D = h.get("_model") as Node3D
	if model == null or model.has_meta("scope"):
		out["scoped"] = model != null
		return out
	var c: Dictionary = classify(h, fov)
	if c.is_empty():
		return out
	return measure_grid(c["grid"])


## The measures from a class grid (see classify).
static func measure_grid(g: Dictionary) -> Dictionary:
	var out: Dictionary = {"post_x": 0.0, "post_w": 0.0, "post_tip": 0.0, "rear_x": 0.0, "rear_open": 0.0, "hole_y": 0.0,
		"err": 0.0, "scoped": false, "found_post": false, "found_rear": false, "blocked": false}
	var at: Callable = func(x: int, y: int) -> String:
		return str(g.get(Vector2i(x, y), ""))
	# front post: the top of a narrow F column nearest the aim point (central columns count double): an F pixel with
	# no F straight above it and at least 2 px of F showing under it, at most 7 px wide over those rows (a hood's or
	# a ring's arch widens at once); 12 px above to 30 px below the aim point.
	var best: float = INF
	var tip: Vector2i = Vector2i.ZERO
	for pass_i: int in 1:
		for y: int in range(-12, 31):
			for x: int in range(-30, 31):
				if at.call(x, y) != "F" or at.call(x, y - 1) == "F" or at.call(x, y + 1) != "F":
					continue
				if pass_i == 0 and (_run(at, x, y) > 7 or _run(at, x, y + 1) > 7):
					continue
				var dd: float = Vector2(x * 2.0, y).length()
				if dd < best:
					best = dd
					tip = Vector2i(x, y)
		if best < INF:
			break
	if best < INF:
		out["found_post"] = true
		out["post_tip"] = float(tip.y)
		var yy: int = tip.y + 1
		var l: int = tip.x
		while l > -HW and at.call(l - 1, yy) == "F":
			l -= 1
		var r: int = tip.x
		while r < HW and at.call(r + 1, yy) == "F":
			r += 1
		out["post_w"] = float(r - l + 1)
		out["post_x"] = (l + r) * 0.5
		if r - l + 1 > 30:   # not a post but a wide front (a shield, a bell's rim): the tip column then
			out["post_x"] = float(tip.x)
	# rear sight: the opening (no R / N) round the post on the row its tip shows in
	var ry: int = int(out["post_tip"]) + 1 if bool(out["found_post"]) else 1
	var cx0: int = roundi(float(out["post_x"])) if bool(out["found_post"]) else 0
	var near: Callable = func(x: int, y: int) -> bool:
		return at.call(x, y) in ["R", "N"]
	if not near.call(cx0, ry):
		var lx: int = cx0
		while lx > -HW and not near.call(lx, ry):
			lx -= 1
		var rx: int = cx0
		while rx < HW and not near.call(rx, ry):
			rx += 1
		if near.call(lx, ry) and near.call(rx, ry):
			out["found_rear"] = true
			out["rear_x"] = (lx + rx) * 0.5
			out["rear_open"] = float(rx - lx - 1)
			# an aperture: closed above the aim point as well, within a ring's reach
			var hx: int = roundi(float(out["rear_x"]))
			var u: int = ry
			while u > -HH and not near.call(hx, u):
				u -= 1
			var d: int = ry
			while d < HH and not near.call(hx, d):
				d += 1
			if near.call(hx, u) and near.call(hx, d) and (d - u) < int(out["rear_open"]) + 10:
				out["hole_y"] = (u + d) * 0.5
	# the aim point itself on the rear sight (or the receiver): the shot goes where no sight shows
	out["blocked"] = near.call(0, 0) or (near.call(0, 1) and near.call(0, 2))
	var err: float = 0.0
	if bool(out["blocked"]) or not bool(out["found_post"]):
		err = BLOCKED_ERR
	elif bool(out["found_post"]):
		err = maxf(absf(float(out["post_x"])), absf(float(out["post_tip"])))
	if bool(out["found_rear"]) and not bool(out["blocked"]):
		err = maxf(err, maxf(absf(float(out["rear_x"])), absf(float(out["hole_y"]))))
	out["err"] = err
	return out


## A map of the classes round the aim point (1 px a column, 2 px a row): R rear sight, F front sight, n nearer,
## b beyond, + the aim point, . clear.
static func ascii(h: WeaponHolder, fov: float, half_w: int = 45, half_h: int = 26, step_y: int = 2) -> PackedStringArray:
	var c: Dictionary = classify(h, fov)
	var out: PackedStringArray = []
	if c.is_empty():
		return out
	var g: Dictionary = c["grid"]
	var fg: Dictionary = c["far"]
	for y: int in range(-half_h, half_h + 1, step_y):
		var line: String = ""
		var line2: String = ""   # the far grid: the front sight with the rear taken away
		for x: int in range(-half_w, half_w + 1, 1):
			if x == 0 and y == 0:
				line += "+"
				line2 += "+"
				continue
			var s: String = str(g.get(Vector2i(x, y), "."))
			line += s.to_lower() if s in ["N", "B"] else s
			var s2: String = str(fg.get(Vector2i(x, y), "."))
			line2 += s2.to_lower() if s2 == "B" else s2
		out.append(line + "   " + line2)
	return out
