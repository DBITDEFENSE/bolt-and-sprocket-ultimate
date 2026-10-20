extends SceneTree
## Procedural placeholder audio generator. Every sound here is synthesized from scratch
## (noise, oscillators, filters), so it's original and project-owned. No samples are used.
## Output: 16-bit mono 44.1 kHz WAV in res://gravelight/audio/sfx/placeholder/ and res://gravelight/audio/music/placeholder/.
##
## Run:  godot --headless --path . --script res://gravelight/tools_src/gen_sfx.gd
## A fixed seed makes the output reproducible.

const SR: int = 44100
const SFX_DIR: String = "res://gravelight/audio/sfx/placeholder/"
const MUS_DIR: String = "res://gravelight/audio/music/placeholder/"
const PEAK: float = 0.708  # -3 dBFS
const SEED: int = 19441223

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _count: int = 0


func _init() -> void:
	rng.seed = SEED
	DirAccess.make_dir_recursive_absolute(SFX_DIR)
	DirAccess.make_dir_recursive_absolute(MUS_DIR)
	var t0: int = Time.get_ticks_msec()
	_gen_weapons()
	_gen_feedback()
	_gen_barricades()
	_gen_zombies()
	_gen_music()
	print("gen_sfx: wrote %d files in %.1f s" % [_count, float(Time.get_ticks_msec() - t0) / 1000.0])
	quit()


# ─────────────────────────────────────────────────────────────── DSP helpers

func buf_n(n: int) -> PackedFloat32Array:
	var b: PackedFloat32Array = PackedFloat32Array()
	b.resize(n)
	b.fill(0.0)
	return b


func buf(sec: float) -> PackedFloat32Array:
	return buf_n(int(sec * SR))


func noise(sec: float) -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(sec)
	for i: int in b.size():
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


## Smooth random curve in [-1, 1] (cosine-interpolated random points at `rate` per second).
func smooth_noise(sec: float, rate: float) -> PackedFloat32Array:
	var pts: PackedFloat32Array = PackedFloat32Array()
	var count: int = int(sec * rate) + 3
	for k: int in count:
		pts.append(rng.randf_range(-1.0, 1.0))
	var b: PackedFloat32Array = buf(sec)
	for i: int in b.size():
		var pos: float = float(i) / SR * rate
		var k0: int = int(pos)
		var fr: float = pos - float(k0)
		var w: float = (1.0 - cos(fr * PI)) * 0.5
		b[i] = lerpf(pts[k0], pts[k0 + 1], w)
	return b


## Read a per-sample curve at time t (clamped).
static func at(curve: PackedFloat32Array, t: float) -> float:
	return curve[clampi(int(t * SR), 0, curve.size() - 1)]


## Oscillator. shape: 0 sine, 1 saw, 2 triangle. `freq` is a float or Callable(t) -> float.
func osc(sec: float, freq: Variant, shape: int = 0, phase0: float = 0.0) -> PackedFloat32Array:
	var b: PackedFloat32Array = buf(sec)
	var is_fn: bool = freq is Callable
	var fr: float = 0.0 if is_fn else float(freq)
	var ph: float = phase0
	for i: int in b.size():
		if is_fn and (i & 15) == 0:
			fr = (freq as Callable).call(float(i) / SR)
		ph += fr / SR
		ph -= floorf(ph)
		if shape == 0:
			b[i] = sin(TAU * ph)
		elif shape == 1:
			b[i] = 2.0 * ph - 1.0
		else:
			b[i] = 4.0 * absf(ph - 0.5) - 1.0
	return b


## Chamberlin state-variable filter. mode: 0 low, 1 band, 2 high.
## `fc` is a float or Callable(t) -> float. `damp` is 1/Q (small = resonant).
func svf(x: PackedFloat32Array, fc: Variant, damp: float, mode: int) -> PackedFloat32Array:
	var y: PackedFloat32Array = buf_n(x.size())
	var is_fn: bool = fc is Callable
	var max_fc: float = float(SR) / 6.5
	var f: float = 0.0
	if not is_fn:
		f = 2.0 * sin(PI * clampf(float(fc), 20.0, max_fc) / SR)
	var low: float = 0.0
	var band: float = 0.0
	for i: int in x.size():
		if is_fn and (i & 31) == 0:
			var c: float = (fc as Callable).call(float(i) / SR)
			f = 2.0 * sin(PI * clampf(c, 20.0, max_fc) / SR)
		low += f * band
		var high: float = x[i] - low - damp * band
		band += f * high
		if mode == 0:
			y[i] = low
		elif mode == 1:
			y[i] = band
		else:
			y[i] = high
	return y


## One-pole high-pass (removes rumble / DC).
func hp1(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var a: float = 1.0 - exp(-TAU * fc / SR)
	var y: PackedFloat32Array = buf_n(x.size())
	var lp: float = 0.0
	for i: int in x.size():
		lp += a * (x[i] - lp)
		y[i] = x[i] - lp
	return y


## Linear attack, then exponential decay with time constant `tau`. Silent before `delay`.
func env_ad(x: PackedFloat32Array, attack: float, tau: float, delay: float = 0.0) -> PackedFloat32Array:
	var y: PackedFloat32Array = x.duplicate()
	for i: int in y.size():
		var t: float = float(i) / SR - delay
		var e: float = 0.0
		if t < 0.0:
			e = 0.0
		elif t < attack:
			e = t / attack
		else:
			e = exp(-(t - attack) / tau)
		y[i] *= e
	return y


## Multiply by an arbitrary envelope Callable(t) -> float.
func env_fn(x: PackedFloat32Array, fn: Callable) -> PackedFloat32Array:
	var y: PackedFloat32Array = x.duplicate()
	var e: float = 0.0
	for i: int in y.size():
		if (i & 7) == 0:
			e = fn.call(float(i) / SR)
		y[i] *= e
	return y


## Smooth hump envelope: rises over `attack`, holds, falls over `release` before the end.
static func hump(t: float, sec: float, attack: float, release: float) -> float:
	if t < 0.0 or t > sec:
		return 0.0
	var a: float = clampf(t / maxf(attack, 0.0001), 0.0, 1.0)
	var r: float = clampf((sec - t) / maxf(release, 0.0001), 0.0, 1.0)
	return smoothstep(0.0, 1.0, a) * smoothstep(0.0, 1.0, r)


## Add `src` into `dst` at time `at_sec`, growing `dst` if needed.
func mix(dst: PackedFloat32Array, src: PackedFloat32Array, at_sec: float = 0.0, gain: float = 1.0) -> PackedFloat32Array:
	var off: int = int(at_sec * SR)
	var n: int = maxi(dst.size(), off + src.size())
	var out: PackedFloat32Array = buf_n(n)
	for i: int in dst.size():
		out[i] = dst[i]
	for i: int in src.size():
		out[off + i] += src[i] * gain
	return out


func scale(x: PackedFloat32Array, g: float) -> PackedFloat32Array:
	var y: PackedFloat32Array = x.duplicate()
	for i: int in y.size():
		y[i] *= g
	return y


## Soft saturation, normalized so a full-scale input stays near full scale.
func drive(x: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y: PackedFloat32Array = x.duplicate()
	var peak: float = 0.0
	for v: float in y:
		peak = maxf(peak, absf(v))
	if peak <= 0.0:
		return y
	var norm: float = tanh(k)
	for i: int in y.size():
		y[i] = tanh(k * y[i] / peak) / norm * peak
	return y


## Small Schroeder reverb (6 damped combs + 2 allpasses). Adds `tail` seconds.
func reverb(x: PackedFloat32Array, wet: float, size: float = 1.0, tail: float = 1.0, fb: float = 0.84, damp: float = 0.3) -> PackedFloat32Array:
	var n: int = x.size() + int(tail * SR)
	var dry: PackedFloat32Array = mix(buf_n(n), x)
	var wet_buf: PackedFloat32Array = buf_n(n)
	var combs: Array[int] = [1557, 1617, 1491, 1422, 1277, 1356]
	for d0: int in combs:
		var d: int = maxi(8, int(float(d0) * size))
		var line: PackedFloat32Array = buf_n(d)
		var idx: int = 0
		var z: float = 0.0
		for i: int in n:
			var o: float = line[idx]
			z = o * (1.0 - damp) + z * damp
			line[idx] = dry[i] + z * fb
			idx += 1
			if idx >= d:
				idx = 0
			wet_buf[i] += o
	var aps: Array[int] = [556, 225]
	for a0: int in aps:
		var d: int = maxi(8, int(float(a0) * size))
		var line: PackedFloat32Array = buf_n(d)
		var idx: int = 0
		for i: int in n:
			var bo: float = line[idx]
			var inp: float = wet_buf[i]
			wet_buf[i] = bo - inp
			line[idx] = inp + bo * 0.5
			idx += 1
			if idx >= d:
				idx = 0
	var out: PackedFloat32Array = buf_n(n)
	var wg: float = wet / float(combs.size()) * 1.6
	for i: int in n:
		out[i] = dry[i] * (1.0 - wet * 0.5) + wet_buf[i] * wg
	return out


## Equal-power crossfade of the end into the start so the buffer loops seamlessly.
func make_loop(x: PackedFloat32Array, xfade_sec: float) -> PackedFloat32Array:
	var xf: int = int(xfade_sec * SR)
	var length: int = x.size() - xf
	var y: PackedFloat32Array = buf_n(length)
	for i: int in length:
		y[i] = x[i]
	for i: int in xf:
		var p: float = float(i) / float(xf) * PI * 0.5
		y[i] = x[i] * sin(p) + x[length + i] * cos(p)
	return y


# ─────────────────────────────────────────────────────────────── building blocks

func sine(sec: float, f: float) -> PackedFloat32Array:
	return osc(sec, f, 0)


## Pitch-dropping sine thump (kick-drum style body).
func thump(sec: float, f_start: float, f_end: float, drop_tau: float, amp_tau: float) -> PackedFloat32Array:
	var fn: Callable = func(t: float) -> float: return f_end + (f_start - f_end) * exp(-t / drop_tau)
	return env_ad(osc(sec, fn, 0), 0.001, amp_tau)


## Mechanical click: a short band-passed noise burst with an optional metallic ring.
func click(freq: float, tau: float = 0.004, ring: float = 0.0) -> PackedFloat32Array:
	var c: PackedFloat32Array = env_ad(svf(noise(0.12), freq, 0.35, 1), 0.0002, tau)
	if ring > 0.0:
		c = mix(c, env_ad(sine(0.12, freq * 0.73), 0.0002, ring), 0.0, 0.25)
		c = mix(c, env_ad(sine(0.12, freq * 1.41), 0.0002, ring * 0.6), 0.0, 0.12)
	return c


## Metal-on-metal slide/scrape.
func scrape(sec: float, freq: float) -> PackedFloat32Array:
	var jit: PackedFloat32Array = smooth_noise(sec, 40.0)
	var fc: Callable = func(t: float) -> float: return freq * (1.0 + 0.35 * at(jit, t))
	var shape: Callable = func(t: float) -> float: return hump(t, sec, sec * 0.3, sec * 0.5)
	return env_fn(svf(noise(sec), fc, 0.25, 1), shape)


## Inharmonic bell. `ratios`/`amps` are partials; higher partials decay faster.
func bell(sec: float, f: float, ratios: Array[float], amps: Array[float], tau: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = buf(sec)
	for k: int in ratios.size():
		var p: PackedFloat32Array = env_ad(sine(sec, f * ratios[k]), 0.002, tau / (1.0 + ratios[k] * 0.8))
		out = mix(out, p, 0.0, amps[k])
	var strike: PackedFloat32Array = env_ad(svf(noise(0.05), f * 3.0, 0.5, 1), 0.0005, 0.006)
	return mix(out, strike, 0.0, 0.3)


func timpani(sec: float, f: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = buf(sec)
	var ratios: Array[float] = [1.0, 1.5, 1.99, 2.44]
	var amps: Array[float] = [1.0, 0.5, 0.35, 0.2]
	var taus: Array[float] = [0.9, 0.5, 0.35, 0.25]
	for k: int in ratios.size():
		var r: float = ratios[k]
		var fn: Callable = func(t: float) -> float: return f * r * (1.0 + 0.04 * exp(-t / 0.05))
		out = mix(out, env_ad(osc(sec, fn, 0), 0.002, taus[k]), 0.0, amps[k])
	var mallet: PackedFloat32Array = env_ad(svf(noise(0.1), 800.0, 0.9, 0), 0.0005, 0.02)
	return mix(out, mallet, 0.0, 0.6)


## Brass-like note: 3 detuned saws, an envelope-tracked low-pass ("blat"), slow vibrato.
func brass(sec: float, f: float, attack: float, release: float, bright: float, vib: float = 0.003) -> PackedFloat32Array:
	var shape: Callable = func(t: float) -> float: return hump(t, sec, attack, release)
	var out: PackedFloat32Array = buf(sec)
	var detunes: Array[float] = [1.0, 1.0041, 0.9959]
	for d: float in detunes:
		var fn: Callable = func(t: float) -> float: return f * d * (1.0 + vib * sin(TAU * 4.8 * t))
		out = mix(out, osc(sec, fn, 1, rng.randf()), 0.0, 0.33)
	var fc: Callable = func(t: float) -> float: return 180.0 + f * 1.5 + bright * hump(t, sec, attack * 1.2, release)
	out = svf(out, fc, 0.85, 0)
	return env_fn(out, shape)


## Zombie voice: pitch-wobbled saw + rasp noise through 3 formant band-passes,
## with a slow amplitude "fry" and saturation.
func voice(sec: float, f0: Callable, rasp: float, f1: Callable, f2: Callable, f3: float, env: Callable, drv: float, fry: float, fry_rate: float) -> PackedFloat32Array:
	var src: PackedFloat32Array = osc(sec, f0, 1)
	src = mix(src, hp1(noise(sec), 900.0), 0.0, rasp)
	var fry_lfo: PackedFloat32Array = smooth_noise(sec, fry_rate)
	var fry_fn: Callable = func(t: float) -> float: return 1.0 - fry * (0.5 + 0.5 * at(fry_lfo, t))
	src = env_fn(src, fry_fn)
	var out: PackedFloat32Array = scale(svf(src, f1, 0.18, 1), 1.0)
	out = mix(out, svf(src, f2, 0.14, 1), 0.0, 0.55)
	out = mix(out, svf(src, f3, 0.12, 1), 0.0, 0.25)
	out = drive(out, drv)
	return env_fn(out, env)


## Generic gunshot: crack transient + pitch-drop body + falling low-pass blast + room.
func gunshot(length: float, crack_gain: float, crack_tau: float, body_f: float, body_tau: float,
		blast_fc: float, blast_tau: float, drv: float, rev_wet: float, rev_size: float, rev_tail: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = buf(length)
	var crack: PackedFloat32Array = env_ad(svf(noise(0.2), 3800.0, 0.7, 2), 0.0004, crack_tau)
	out = mix(out, crack, 0.0, crack_gain)
	out = mix(out, thump(minf(length, 0.6), body_f * 2.4, body_f, 0.015, body_tau), 0.0, 1.0)
	var fc: Callable = func(t: float) -> float: return 180.0 + blast_fc * exp(-t * 5.0)
	var blast: PackedFloat32Array = env_ad(svf(noise(length), fc, 0.9, 0), 0.0008, blast_tau)
	out = mix(out, blast, 0.0, 1.3)
	out = drive(out, drv)
	return reverb(out, rev_wet, rev_size, rev_tail)


# ─────────────────────────────────────────────────────────────── output

func save(x: PackedFloat32Array, path: String, loop: bool = false) -> void:
	var y: PackedFloat32Array = hp1(x, 25.0)
	if not loop:
		# 3 ms of lead-in silence so the 2 ms fade-in never eats a transient,
		# then short fades so there are no clicks at the edges.
		y = mix(buf(0.003), y, 0.003)
		var fin: int = mini(int(0.002 * SR), y.size())
		var fout: int = mini(int(0.03 * SR), y.size())
		for i: int in fin:
			y[i] *= float(i) / float(fin)
		for i: int in fout:
			y[y.size() - 1 - i] *= float(i) / float(fout)
	# Normalize last so every file peaks at -3 dBFS.
	var peak: float = 0.0
	for v: float in y:
		peak = maxf(peak, absf(v))
	if peak > 0.0:
		y = scale(y, PEAK / peak)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(y.size() * 2)
	for i: int in y.size():
		bytes.encode_s16(i * 2, int(clampf(y[i], -1.0, 1.0) * 32767.0))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = y.size()
	var err: Error = s.save_to_wav(path)
	if err != OK:
		push_error("gen_sfx: failed to save %s (%s)" % [path, error_string(err)])
		return
	_count += 1
	print("  %s  (%.2f s)" % [path, float(y.size()) / SR])


# ─────────────────────────────────────────────────────────────── weapons

func _gen_weapons() -> void:
	# Pistol: tight crack, mid body, short room.
	save(gunshot(0.45, 0.9, 0.012, 120.0, 0.05, 2200.0, 0.09, 2.2, 0.22, 0.8, 0.5), SFX_DIR + "gun_pistol.wav")

	# Rifle: hard crack, deep body, plus a delayed slap-back echo for the "tail".
	var rifle: PackedFloat32Array = gunshot(0.9, 1.4, 0.01, 85.0, 0.09, 3000.0, 0.16, 2.8, 0.3, 1.3, 1.1)
	var slap: PackedFloat32Array = svf(rifle, 900.0, 0.9, 0)
	rifle = mix(rifle, slap, 0.13, 0.28)
	rifle = mix(rifle, slap, 0.29, 0.12)
	save(rifle, SFX_DIR + "gun_rifle.wav")

	# SMG: short and punchy so it repeats cleanly at 500+ RPM.
	save(gunshot(0.28, 1.0, 0.008, 150.0, 0.035, 2000.0, 0.05, 2.0, 0.12, 0.6, 0.25), SFX_DIR + "gun_smg.wav")

	# Shotgun: boomy low body, broad blast.
	save(gunshot(1.0, 0.7, 0.014, 52.0, 0.16, 1300.0, 0.24, 3.0, 0.3, 1.2, 1.0), SFX_DIR + "gun_shotgun.wav")

	# Dry fire.
	var dry: PackedFloat32Array = mix(click(3200.0, 0.003, 0.015), thump(0.08, 400.0, 300.0, 0.01, 0.01), 0.0, 0.3)
	save(mix(buf(0.15), dry), SFX_DIR + "gun_dry.wav")

	# Reload start: release click, mag slides out, mag clears.
	var rs: PackedFloat32Array = buf(0.45)
	rs = mix(rs, click(2800.0, 0.004, 0.03))
	rs = mix(rs, scrape(0.16, 1600.0), 0.05, 0.45)
	rs = mix(rs, click(2100.0, 0.006, 0.02), 0.22, 0.8)
	save(rs, SFX_DIR + "reload_start.wav")

	# Reload end: mag seats (with a body knock), then the slide/bolt clacks home.
	var re: PackedFloat32Array = buf(0.5)
	re = mix(re, click(1800.0, 0.006, 0.02))
	re = mix(re, thump(0.15, 230.0, 160.0, 0.01, 0.03), 0.0, 0.6)
	re = mix(re, click(3200.0, 0.004, 0.025), 0.18, 1.0)
	re = mix(re, click(2400.0, 0.005, 0.02), 0.205, 0.8)
	re = mix(re, thump(0.12, 300.0, 200.0, 0.01, 0.02), 0.2, 0.4)
	save(re, SFX_DIR + "reload_end.wav")

	# Bolt cycle: up, back, catch, forward, lock.
	var bc: PackedFloat32Array = buf(0.55)
	bc = mix(bc, click(2600.0, 0.004, 0.02))
	bc = mix(bc, scrape(0.12, 1800.0), 0.03, 0.5)
	bc = mix(bc, click(3000.0, 0.004, 0.02), 0.16, 0.8)
	bc = mix(bc, scrape(0.10, 2100.0), 0.2, 0.45)
	bc = mix(bc, click(2200.0, 0.006, 0.03), 0.31, 1.0)
	bc = mix(bc, thump(0.12, 260.0, 180.0, 0.01, 0.025), 0.31, 0.5)
	save(bc, SFX_DIR + "bolt_cycle.wav")

	# Knife swing: band-pass noise sweeping up and back down.
	var sw_sec: float = 0.36
	var sw_fc: Callable = func(t: float) -> float: return 500.0 + 2600.0 * sin(PI * clampf(t / sw_sec, 0.0, 1.0))
	var sw_env: Callable = func(t: float) -> float: return pow(sin(PI * clampf(t / sw_sec, 0.0, 1.0)), 2.0)
	save(env_fn(svf(noise(sw_sec), sw_fc, 0.55, 1), sw_env), SFX_DIR + "knife_swing.wav")

	# Knife hit: dull meaty thud with a little crunch.
	var kh: PackedFloat32Array = thump(0.3, 150.0, 60.0, 0.02, 0.06)
	kh = mix(kh, env_ad(svf(noise(0.3), 500.0, 0.9, 0), 0.001, 0.04), 0.0, 0.9)
	kh = mix(kh, env_ad(svf(noise(0.1), 2000.0, 0.4, 1), 0.0005, 0.006), 0.0, 0.25)
	save(drive(kh, 2.0), SFX_DIR + "knife_hit.wav")

	# Grenade: crack + falling low-pass blast + sub drop + scattered debris + big room.
	var ge: PackedFloat32Array = buf(3.0)
	var ge_fc: Callable = func(t: float) -> float: return 150.0 + 3500.0 * exp(-t / 0.12)
	ge = mix(ge, env_ad(svf(noise(3.0), ge_fc, 1.0, 0), 0.003, 0.7))
	ge = mix(ge, thump(2.5, 70.0, 32.0, 0.15, 0.6), 0.0, 1.3)
	ge = mix(ge, env_ad(svf(noise(0.2), 3000.0, 0.7, 2), 0.0005, 0.01), 0.0, 0.6)
	ge = drive(ge, 2.5)
	for k: int in 40:
		var when: float = rng.randf_range(0.3, 2.5)
		var g: float = rng.randf_range(0.04, 0.18) * (1.0 - when / 3.0)
		ge = mix(ge, click(rng.randf_range(1500.0, 5000.0), rng.randf_range(0.002, 0.008)), when, g)
	save(reverb(ge, 0.35, 1.6, 1.5), SFX_DIR + "grenade_explode.wav")

	# Grenade pin: click, ringing pin, then the spoon flips off.
	var gp: PackedFloat32Array = buf(0.7)
	var metal_r: Array[float] = [1.0, 1.58, 2.31, 3.07]
	var metal_a: Array[float] = [1.0, 0.6, 0.4, 0.25]
	gp = mix(gp, click(4000.0, 0.003))
	gp = mix(gp, bell(0.4, 3100.0, metal_r, metal_a, 0.12), 0.01, 0.5)
	gp = mix(gp, click(2600.0, 0.004, 0.02), 0.25, 0.7)
	gp = mix(gp, bell(0.3, 2300.0, metal_r, metal_a, 0.08), 0.255, 0.35)
	save(gp, SFX_DIR + "grenade_pin.wav")


# ─────────────────────────────────────────────────────────────── feedback

func _gen_feedback() -> void:
	# Hitmarker: tiny tick.
	var hm: PackedFloat32Array = env_ad(svf(noise(0.08), 4500.0, 0.3, 1), 0.0003, 0.004)
	hm = mix(hm, env_ad(sine(0.08, 2200.0), 0.0003, 0.012), 0.0, 0.5)
	save(hm, SFX_DIR + "hitmarker.wav")

	# Headshot: the tick plus a crunchy, saturated snap and a small knock.
	var hs: PackedFloat32Array = mix(buf(0.25), hm, 0.0, 0.8)
	hs = mix(hs, drive(env_ad(svf(noise(0.2), 1600.0, 0.5, 1), 0.0005, 0.03), 3.0), 0.0, 0.8)
	hs = mix(hs, thump(0.15, 260.0, 140.0, 0.01, 0.03), 0.0, 0.5)
	save(hs, SFX_DIR + "headshot.wav")

	# Buy: register click + two-tone ding.
	var by: PackedFloat32Array = buf(0.9)
	var ding_r: Array[float] = [1.0, 2.0, 3.0, 4.2]
	var ding_a: Array[float] = [1.0, 0.35, 0.15, 0.06]
	by = mix(by, click(2500.0, 0.004, 0.02), 0.0, 0.6)
	by = mix(by, bell(0.7, 1318.5, ding_r, ding_a, 0.5), 0.02, 0.7)
	by = mix(by, bell(0.7, 1760.0, ding_r, ding_a, 0.6), 0.12, 0.7)
	save(reverb(by, 0.15, 0.7, 0.3), SFX_DIR + "buy.wav")

	# Deny: low beating buzz + dull thud.
	var dn_sec: float = 0.45
	var dn: PackedFloat32Array = mix(osc(dn_sec, 70.0, 1), osc(dn_sec, 73.5, 1), 0.0, 1.0)
	dn = drive(svf(dn, 500.0, 0.8, 0), 3.0)
	var dn_env: Callable = func(t: float) -> float: return hump(t, dn_sec, 0.01, 0.12)
	dn = env_fn(dn, dn_env)
	dn = mix(dn, thump(0.3, 90.0, 60.0, 0.02, 0.08), 0.0, 0.8)
	save(dn, SFX_DIR + "deny.wav")

	# Scrip tick: short bright coin-like tick.
	var st: PackedFloat32Array = env_ad(sine(0.12, 2637.0), 0.0005, 0.025)
	st = mix(st, env_ad(sine(0.12, 3951.0), 0.0005, 0.015), 0.0, 0.4)
	save(st, SFX_DIR + "scrip_tick.wav")

	# Door: a long stick-slip scrape, then a heavy thunk into a room.
	var sc_sec: float = 1.5
	var sc_jit: PackedFloat32Array = smooth_noise(sc_sec, 18.0)
	var sc_am: PackedFloat32Array = smooth_noise(sc_sec, 25.0)
	var sc_tone: PackedFloat32Array = smooth_noise(sc_sec, 6.0)
	var sc_fc: Callable = func(t: float) -> float: return 600.0 + 300.0 * at(sc_jit, t)
	var sc_f0: Callable = func(t: float) -> float: return 55.0 + 15.0 * at(sc_tone, t)
	var sc_env: Callable = func(t: float) -> float: return hump(t, sc_sec, 0.2, 0.3) * (0.6 + 0.4 * at(sc_am, t))
	var door: PackedFloat32Array = svf(noise(sc_sec), sc_fc, 0.25, 1)
	door = mix(door, svf(osc(sc_sec, sc_f0, 1), 500.0, 0.7, 0), 0.0, 0.4)
	door = env_fn(door, sc_env)
	var thunk: PackedFloat32Array = thump(0.7, 110.0, 60.0, 0.03, 0.12)
	thunk = mix(thunk, env_ad(svf(noise(0.5), 500.0, 0.9, 0), 0.001, 0.07), 0.0, 1.0)
	thunk = mix(thunk, env_ad(sine(0.4, 180.0), 0.001, 0.09), 0.0, 0.4)
	thunk = mix(thunk, click(1500.0, 0.006), 0.0, 0.5)
	door = mix(door, scale(thunk, 1.6), 1.55)
	save(reverb(door, 0.3, 1.2, 0.8), SFX_DIR + "door_open.wav")

	# Player hurt: dull impact, then a muffled breathy gasp.
	var ph: PackedFloat32Array = thump(0.4, 140.0, 70.0, 0.02, 0.07)
	ph = mix(ph, env_ad(svf(noise(0.4), 700.0, 0.9, 0), 0.001, 0.05), 0.0, 0.9)
	var br_sec: float = 0.55
	var br_env: Callable = func(t: float) -> float: return hump(t, br_sec, 0.06, 0.35)
	var breath: PackedFloat32Array = env_fn(svf(noise(br_sec), 1100.0, 0.6, 1), br_env)
	ph = mix(ph, breath, 0.08, 0.45)
	save(svf(ph, 2500.0, 1.2, 0), SFX_DIR + "player_hurt.wav")

	# Heartbeat: lub-dub, loopable at 1.6 s.
	var hb: PackedFloat32Array = buf(1.6)
	for beat: Array in [[0.05, 1.0], [0.33, 0.75]]:
		var b: PackedFloat32Array = thump(0.4, 55.0, 40.0, 0.03, 0.09)
		b = mix(b, env_ad(svf(noise(0.3), 150.0, 0.9, 0), 0.004, 0.05), 0.0, 0.6)
		hb = mix(hb, b, float(beat[0]), float(beat[1]))
	hb.resize(int(1.6 * SR))
	save(hb, SFX_DIR + "heartbeat.wav", true)


# ─────────────────────────────────────────────────────────────── barricades

func _gen_barricades() -> void:
	# Board break: a fast cluster of wood cracks over a hollow body.
	var bb: PackedFloat32Array = buf(0.9)
	var when: float = 0.0
	for k: int in 7:
		bb = mix(bb, click(rng.randf_range(900.0, 2600.0), rng.randf_range(0.003, 0.012)), when, rng.randf_range(0.5, 1.0))
		when += rng.randf_range(0.008, 0.03)
	bb = mix(bb, thump(0.3, 260.0, 180.0, 0.02, 0.06), 0.0, 0.7)
	bb = mix(bb, env_ad(sine(0.3, 410.0), 0.001, 0.05), 0.0, 0.3)
	bb = mix(bb, env_ad(svf(noise(0.4), 900.0, 0.8, 0), 0.001, 0.08), 0.0, 0.6)
	save(reverb(drive(bb, 1.8), 0.2, 0.8, 0.4), SFX_DIR + "board_break.wav")

	# Board place: two hammer knocks.
	var bp: PackedFloat32Array = buf(0.6)
	for t_k: float in [0.0, 0.17]:
		var knock: PackedFloat32Array = thump(0.25, 340.0, 260.0, 0.01, 0.03)
		knock = mix(knock, env_ad(svf(noise(0.1), 900.0, 0.5, 1), 0.0005, 0.012), 0.0, 0.8)
		knock = mix(knock, env_ad(sine(0.2, 520.0), 0.001, 0.04), 0.0, 0.3)
		bp = mix(bp, knock, t_k, 1.0 if t_k == 0.0 else 0.85)
	save(reverb(bp, 0.15, 0.7, 0.3), SFX_DIR + "board_place.wav")

	# Board slam: one heavy impact with a rattle.
	var bs: PackedFloat32Array = thump(0.7, 160.0, 70.0, 0.03, 0.14)
	bs = mix(bs, env_ad(svf(noise(0.5), 1400.0, 0.8, 0), 0.001, 0.07), 0.0, 1.0)
	for k: int in 4:
		bs = mix(bs, click(rng.randf_range(1200.0, 2400.0), 0.005), 0.03 + 0.025 * k, 0.25)
	save(reverb(drive(bs, 2.0), 0.25, 1.1, 0.5), SFX_DIR + "board_slam.wav")


# ─────────────────────────────────────────────────────────────── zombies

func _gen_zombies() -> void:
	for v: int in 3:
		var vf: float = float(v)

		# Groan: low, slow, sliding down; vowel drifts "oh" → "uh".
		var g_sec: float = 1.3 + 0.3 * vf + rng.randf_range(0.0, 0.2)
		var g_base: float = 76.0 + 11.0 * vf + rng.randf_range(-4.0, 4.0)
		var g_j: PackedFloat32Array = smooth_noise(g_sec, 3.0)
		var g_f0: Callable = func(t: float) -> float: return g_base * (1.0 - 0.18 * t / g_sec) + 5.0 * sin(TAU * 4.3 * t) + 9.0 * at(g_j, t)
		var g_f1: Callable = func(t: float) -> float: return 470.0 + 160.0 * t / g_sec + 50.0 * at(g_j, t)
		var g_f2: Callable = func(t: float) -> float: return 820.0 + 260.0 * t / g_sec
		var g_env: Callable = func(t: float) -> float: return hump(t, g_sec, 0.18, 0.45)
		save(voice(g_sec, g_f0, 0.35, g_f1, g_f2, 2400.0 + 150.0 * vf, g_env, 2.2, 0.5, 30.0), SFX_DIR + "zombie_groan_%d.wav" % (v + 1))

		# Attack: sharp snarl, open "ah" vowel, lots of rasp.
		var a_sec: float = 0.6
		var a_base: float = 150.0 + 20.0 * vf
		var a_j: PackedFloat32Array = smooth_noise(a_sec, 20.0)
		var a_f0: Callable = func(t: float) -> float: return a_base - 35.0 * t / a_sec + 14.0 * at(a_j, t)
		var a_f1: Callable = func(t: float) -> float: return 760.0 + 60.0 * at(a_j, t)
		var a_f2: Callable = func(_t: float) -> float: return 1250.0 + 80.0 * vf
		var a_env: Callable = func(t: float) -> float: return 0.0 if t < 0.0 else minf(t / 0.02, 1.0) * exp(-maxf(t - 0.02, 0.0) / 0.25)
		save(voice(a_sec, a_f0, 0.7, a_f1, a_f2, 2600.0, a_env, 4.0, 0.3, 40.0), SFX_DIR + "zombie_attack_%d.wav" % (v + 1))

		# Death: descending, gurgling, fading out.
		var d_sec: float = 1.2 + 0.15 * vf
		var d_start: float = 115.0 + 10.0 * vf
		var d_f0: Callable = func(t: float) -> float: return 45.0 + (d_start - 45.0) * exp(-t / 0.4)
		var d_f1: Callable = func(t: float) -> float: return 600.0 - 250.0 * t / d_sec
		var d_f2: Callable = func(t: float) -> float: return 1000.0 - 300.0 * t / d_sec
		var d_env: Callable = func(t: float) -> float: return hump(t, d_sec, 0.03, d_sec * 0.7)
		save(voice(d_sec, d_f0, 0.4, d_f1, d_f2, 2300.0, d_env, 2.5, 0.8, 14.0 + 3.0 * vf), SFX_DIR + "zombie_death_%d.wav" % (v + 1))

		# Sprint: raspy, higher, in three panting bursts.
		var s_sec: float = 1.0
		var s_base: float = 180.0 + 15.0 * vf
		var s_j: PackedFloat32Array = smooth_noise(s_sec, 12.0)
		var s_f0: Callable = func(t: float) -> float: return s_base + 25.0 * at(s_j, t)
		var s_f1: Callable = func(_t: float) -> float: return 700.0 + 40.0 * vf
		var s_f2: Callable = func(t: float) -> float: return 1500.0 + 150.0 * at(s_j, t)
		var s_env: Callable = func(t: float) -> float: return maxf(maxf(hump(t, 0.25, 0.04, 0.15), hump(t - 0.33, 0.25, 0.04, 0.15)), hump(t - 0.66, 0.3, 0.04, 0.2))
		save(voice(s_sec, s_f0, 0.9, s_f1, s_f2, 2800.0, s_env, 3.0, 0.4, 35.0), SFX_DIR + "zombie_sprint_%d.wav" % (v + 1))


# ─────────────────────────────────────────────────────────────── music

const D2: float = 73.42
const A2: float = 110.0
const BB2: float = 116.54
const C3: float = 130.81
const D3: float = 146.83
const EB3: float = 155.56
const E3: float = 164.81
const F3: float = 174.61
const G3: float = 196.0
const A3: float = 220.0


func _gen_music() -> void:
	# Round start: low brass cluster swells for ~2.7 s into a timpani hit, then rings out.
	var rs: PackedFloat32Array = buf(4.0)
	var cluster: Array[float] = [D2, A2, D3, EB3, F3]
	for f: float in cluster:
		rs = mix(rs, brass(3.3, f, 2.5, 0.6, 1400.0), 0.0, 0.3)
	var rumble_env: Callable = func(t: float) -> float: return hump(t, 3.3, 2.6, 0.5)
	rs = mix(rs, env_fn(svf(noise(3.3), 120.0, 0.9, 0), rumble_env), 0.0, 0.5)
	rs = mix(rs, timpani(1.6, D2), 2.7, 1.4)
	save(reverb(rs, 0.35, 1.3, 1.0), MUS_DIR + "round_start.wav")

	# Round end: a mournful descending D-minor horn line over a low drone.
	var re: PackedFloat32Array = buf(5.3)
	re = mix(re, brass(5.3, D2, 1.0, 1.5, 300.0), 0.0, 0.35)
	re = mix(re, brass(5.3, A2, 1.2, 1.5, 250.0), 0.0, 0.25)
	var line: Array[float] = [A3, G3, F3, E3, D3]
	for k: int in line.size():
		var dur: float = 1.8 if k == line.size() - 1 else 0.95
		re = mix(re, brass(dur, line[k], 0.12, 0.3, 700.0, 0.005), 0.1 + 0.85 * k, 0.5)
	save(reverb(re, 0.4, 1.4, 1.2), MUS_DIR + "round_end.wav")

	# Game over: a tolling bell, an ominous drone, and a falling brass line into silence.
	var go: PackedFloat32Array = buf(7.0)
	go = mix(go, brass(7.0, D2, 1.5, 2.5, 250.0), 0.0, 0.35)
	go = mix(go, brass(7.0, A2, 2.0, 2.5, 200.0), 0.0, 0.2)
	go = mix(go, brass(6.0, EB3 * 0.5, 2.5, 2.0, 200.0), 0.5, 0.15)
	var bell_r: Array[float] = [0.5, 1.0, 1.19, 1.5, 2.0, 2.52, 3.0, 4.07]
	var bell_a: Array[float] = [0.6, 1.0, 0.5, 0.4, 0.35, 0.25, 0.15, 0.1]
	for t_b: float in [0.0, 2.4, 4.8]:
		go = mix(go, bell(3.0, D3, bell_r, bell_a, 3.5), t_b, 0.45 if t_b < 4.0 else 0.3)
	var fall: Array[float] = [D3, C3, BB2, A2]
	for k: int in fall.size():
		var dur: float = 2.0 if k == fall.size() - 1 else 1.55
		go = mix(go, brass(dur, fall[k], 0.25, 0.6, 600.0, 0.004), 0.5 + 1.5 * k, 0.45)
	go = mix(go, timpani(1.6, D2), 5.0, 0.8)
	var go_fade: Callable = func(t: float) -> float: return clampf((7.0 - t) / 1.5, 0.0, 1.0)
	save(env_fn(reverb(go, 0.45, 1.5, 1.0), go_fade), MUS_DIR + "game_over.wav")

	# Ambient wind: broad gusting band-pass noise + a faint whistle, crossfaded into a 20 s loop.
	var w_sec: float = 22.0
	var lf1: PackedFloat32Array = smooth_noise(w_sec, 0.4)
	var lf2: PackedFloat32Array = smooth_noise(w_sec, 0.25)
	var lf3: PackedFloat32Array = smooth_noise(w_sec, 0.15)
	var w_fc: Callable = func(t: float) -> float: return 380.0 + 260.0 * at(lf1, t)
	var wh_fc: Callable = func(t: float) -> float: return 1300.0 + 400.0 * at(lf2, t)
	var gust: Callable = func(t: float) -> float: return 0.55 + 0.45 * at(lf3, t)
	var src: PackedFloat32Array = noise(w_sec)
	var wind: PackedFloat32Array = svf(src, w_fc, 0.9, 1)
	wind = mix(wind, svf(src, wh_fc, 0.08, 1), 0.0, 0.15)
	wind = svf(env_fn(wind, gust), 3000.0, 1.0, 0)
	save(make_loop(wind, 2.0), MUS_DIR + "ambient_wind.wav", true)
