class_name InterpBuffer
extends RefCounted
## Snapshot interpolation for one replicated body (a teammate or a zombie). Samples are stamped in this
## peer's clock (NetMatch converts the sender's clock with a smoothed offset); sample() renders a time a
## little in the past (data/net.json interp_delay_ms) so there is always a pair to blend between.
## Past the newest sample it extrapolates for at most EXTRAPOLATE_MS, then holds.

const MAX_SAMPLES: int = 24
const EXTRAPOLATE_MS: float = 120.0

var pos: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var pitch: float = 0.0
var flags: int = 0
var aux: int = 0            # extra per-sample byte (zombie sub-state), taken from the newer sample

var _t: PackedFloat64Array = PackedFloat64Array()
var _p: PackedVector3Array = PackedVector3Array()
var _y: PackedFloat32Array = PackedFloat32Array()
var _pi: PackedFloat32Array = PackedFloat32Array()
var _f: PackedInt32Array = PackedInt32Array()
var _a: PackedInt32Array = PackedInt32Array()


func clear() -> void:
	_t.clear()
	_p.clear()
	_y.clear()
	_pi.clear()
	_f.clear()
	_a.clear()


func is_empty() -> bool:
	return _t.is_empty()


## Adds a sample (out-of-order or duplicate times are dropped).
func push(t_ms: float, p: Vector3, yaw_v: float, pitch_v: float, flags_v: int, aux_v: int = 0) -> void:
	if not _t.is_empty() and t_ms <= _t[_t.size() - 1]:
		return
	_t.append(t_ms)
	_p.append(p)
	_y.append(yaw_v)
	_pi.append(pitch_v)
	_f.append(flags_v)
	_a.append(aux_v)
	if _t.size() > MAX_SAMPLES:
		_t.remove_at(0)
		_p.remove_at(0)
		_y.remove_at(0)
		_pi.remove_at(0)
		_f.remove_at(0)
		_a.remove_at(0)


## Jumps straight to a state (spawn / teleport): no blending from the old position.
func snap(t_ms: float, p: Vector3, yaw_v: float) -> void:
	clear()
	push(t_ms, p, yaw_v, 0.0, 0)
	pos = p
	yaw = yaw_v


func newest_time() -> float:
	return _t[_t.size() - 1] if not _t.is_empty() else -1.0


## Fills pos/yaw/pitch/flags for `render_ms`. Returns false when there is no data yet.
func sample(render_ms: float) -> bool:
	var n: int = _t.size()
	if n == 0:
		return false
	if n == 1 or render_ms <= _t[0]:
		_take(0 if render_ms <= _t[0] else n - 1)
		return true
	var last: int = n - 1
	if render_ms >= _t[last]:
		# extrapolate a little along the last segment, then hold
		var dt: float = _t[last] - _t[last - 1]
		var over: float = minf(render_ms - _t[last], EXTRAPOLATE_MS)
		_take(last)
		if dt > 0.5 and over > 0.0:
			var k: float = over / dt
			pos = _p[last] + (_p[last] - _p[last - 1]) * minf(k, 1.0)
		return true
	var i: int = last - 1
	while i > 0 and _t[i] > render_ms:
		i -= 1
	var span: float = maxf(0.001, _t[i + 1] - _t[i])
	var k2: float = clampf((render_ms - _t[i]) / span, 0.0, 1.0)
	pos = _p[i].lerp(_p[i + 1], k2)
	yaw = lerp_angle(_y[i], _y[i + 1], k2)
	pitch = lerpf(_pi[i], _pi[i + 1], k2)
	flags = _f[i + 1] if k2 > 0.5 else _f[i]
	aux = _a[i + 1] if k2 > 0.5 else _a[i]
	# drop samples nobody will need again
	if i > 2:
		for j: int in i - 2:
			_t.remove_at(0)
			_p.remove_at(0)
			_y.remove_at(0)
			_pi.remove_at(0)
			_f.remove_at(0)
			_a.remove_at(0)
	return true


func _take(i: int) -> void:
	pos = _p[i]
	yaw = _y[i]
	pitch = _pi[i]
	flags = _f[i]
	aux = _a[i]
