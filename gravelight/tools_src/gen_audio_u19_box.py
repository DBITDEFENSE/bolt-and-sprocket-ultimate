#!/usr/bin/env python3
"""GRAVELIGHT T-254 (UPDATE 19): the Requisition Crate's and the Crucible's new one-shots, synthesized from scratch.

No recordings and no samples: gen_audio.py's DSP core with gen_audio_bosses.py's ogg writer, the way the Sherman and
boss packs were made. License: Owned (our own work). The keys go into data/gravelight/audio.json as ONE block at the
END of "sounds" (sorted), so a three-way merge with another branch's audio.json never meets it; a key already there
is replaced.

  crate_spill        the lid heaves open: a glassy swell of Nachtglas light under the creak (layered on crate_open)
  crate_settle       the crate has made up its mind: a small rising figure on glass and a soft thump
  crate_close        the lid falls shut: a wooden thud, the hasp's rattle
  crate_sink         Herr Tamtam's exit: the crate goes down into the floor, a falling glass sweep and a deep knock
  crate_arrive       the crate comes up at its new spot: a rising swell, the skids' knock on the floor
  crate_hum          the crate where it stands: a very quiet glass hum with a slow beat (loop; the locator by ear)
  crucible_tick_1..3 a cold furnace ticking as its iron settles (unpowered idle)
  crucible_feed      the weapon goes in: the feed door's iron slam, a chain's short rattle
  crucible_clank_1..3 the machine working: a drop hammer inside the casing, muffled, with the iron ringing
  crucible_out       the weapon comes out: a struck-glass ring over a steam release

Run from the repo root:   python gravelight/tools_src/gen_audio_u19_box.py
then reimport:             godot --headless --import --path .
Needs numpy, scipy and ffmpeg on PATH.
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.argv = sys.argv[:1]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as A                        # noqa: E402
import gen_audio_bosses as B                 # noqa: E402
import numpy as np                           # noqa: E402

N, tax, white, pink, brown = A.N, A.tax, A.white, A.pink, A.brown
lp, hp, bp, reson, nrm, sat = A.lp, A.hp, A.bp, A.reson, A.nrm, A.sat
expenv, attack, place, adsr, zeros = A.expenv, A.attack, A.place, A.adsr, A.zeros
smooth_rand, reverb, echo = A.smooth_rand, A.reverb, A.echo
SR = A.SR
emit_ogg = B.emit_ogg
WORLD = dict(bus="SFX", attenuation="world")


def r_(name: str, i: int = 0):
    return A.rng_for("u19_%s_%d" % (name, i))


def glass(r, f: float, sec: float, decay: float = 0.9, bright: float = 1.0):
    """A struck or bowed Nachtglas tone: a few slightly inharmonic partials with slow beating."""
    n = N(sec)
    t = tax(n)
    y = np.zeros(n)
    for k, (m, a) in enumerate([(1.0, 1.0), (2.01, 0.5), (2.76, 0.32 * bright), (4.1, 0.2 * bright), (5.43, 0.12 * bright)]):
        fr = f * m * (1.0 + r.uniform(-0.003, 0.003))
        if fr > SR * 0.45:
            break
        y += a * np.sin(2 * np.pi * fr * t + r.uniform(0, 6.28)) * (0.75 + 0.25 * np.sin(2 * np.pi * r.uniform(2.0, 6.0) * t)) \
            * np.exp(-t / (decay / (1 + 0.4 * k)))
    return y


def swell(r, sec: float, f0: float, f1: float, peak_at: float = 0.6):
    """A glassy noise swell sweeping f0 -> f1, peaking at `peak_at` of its length."""
    n = N(sec)
    x = A.sweep_noise(r, sec, f0, f1, q=6.0, bands=10)
    env = np.interp(np.linspace(0, 1, n), [0.0, peak_at, 1.0], [0.0, 1.0, 0.0]) ** 1.6
    return nrm(x[:n]) * env


def gen_crate():
    # the light spilling out as the lid heaves: a low glass chord swelling, a breath of air
    r = r_("spill")
    sec = 1.9
    x = zeros(sec)
    for k, nm in enumerate(["D3", "A3", "F4", "A4"]):
        g = glass(r, A.hz(nm), sec, 1.6, 0.7) * attack(N(sec), 0.35 + 0.08 * k)
        place(x, g, 0.0, 0.5 / (1 + 0.3 * k))
    place(x, swell(r, 1.2, 500, 3200, 0.5) * 0.35, 0.05)
    place(x, nrm(lp(brown(r, 0.7), 220)) * adsr(N(0.7), 0.05, 0.2, 0.3, 0.4), 0.1, 0.5)
    emit_ogg("crate_spill", "sfx/world/crate_spill_01", reverb(x, r, 1.2, 0.3, 6000), -3.0, volume_db=-5.0, max_voices=1,
             pitch=[0.98, 1.02], **WORLD)

    # the settle: three glass notes up and a soft thump (not a fanfare: the crate is not pleased with anybody)
    r = r_("settle")
    sec = 1.5
    x = zeros(sec)
    for k, nm in enumerate(["A4", "D5", "A5"]):
        place(x, glass(r, A.hz(nm), 1.1, 0.55, 1.0) * attack(N(1.1), 0.004), 0.07 * k, 0.6)
    place(x, A.shimmer(r, A.hz("D5"), 0.9, 0.45, 6) * 0.25, 0.14)
    place(x, A.kick(r, 0.5, 120, 55, 0.07, 0.3), 0.0, 0.5)
    emit_ogg("crate_settle", "sfx/world/crate_settle_01", reverb(x, r, 0.9, 0.25, 7000), -3.0, volume_db=-4.0, max_voices=1,
             pitch=[0.97, 1.03], **WORLD)

    # the lid falls shut
    r = r_("close")
    sec = 0.8
    x = zeros(sec)
    place(x, A.thunk(r, 150, 0.05, 0.25), 0.0, 1.0)
    place(x, nrm(lp(white(r, 0.2), 900)) * expenv(N(0.2), 0.03), 0.0, 0.7)
    for k in range(3):
        place(x, A.mech_click(r, 1700 + 400 * k, 0.05, 0.006), 0.06 + 0.045 * k + r.uniform(0, 0.01), 0.35 / (1 + k))
    emit_ogg("crate_close", "sfx/world/crate_close_01", reverb(x, r, 0.4, 0.14), -2.0, volume_db=-4.0, max_voices=2,
             pitch=[0.94, 1.06], **WORLD)

    # the crate goes down into the floor
    r = r_("sink")
    sec = 2.0
    x = zeros(sec)
    n = N(1.4)
    t = tax(n)
    f = 620.0 * np.exp(-t * 1.3)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = (np.sin(ph) + 0.4 * np.sin(2.76 * ph) + 0.2 * np.sin(4.1 * ph)) * attack(n, 0.05) * expenv(n, 0.7)
    place(x, tone, 0.0, 0.6)
    place(x, swell(r, 1.2, 2600, 240, 0.25) * 0.5, 0.0)
    place(x, A.kick(r, 0.9, 80, 32, 0.3, 0.8), 1.05, 0.9)
    place(x, nrm(lp(brown(r, 0.6), 300)) * expenv(N(0.6), 0.2), 1.05, 0.5)
    emit_ogg("crate_sink", "sfx/world/crate_sink_01", reverb(x, r, 1.3, 0.28, 4500), -2.0, volume_db=-3.0, max_voices=1,
             pitch=[1.0, 1.0], **WORLD)

    # ... and comes up somewhere else
    r = r_("arrive")
    sec = 2.2
    x = zeros(sec)
    n = N(1.1)
    t = tax(n)
    f = 150.0 * np.exp(t * 1.25)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = (np.sin(ph) + 0.4 * np.sin(2.01 * ph) + 0.25 * np.sin(2.76 * ph)) * (t / t[-1]) ** 1.5
    place(x, tone, 0.0, 0.5)
    place(x, swell(r, 1.1, 300, 3000, 0.85) * 0.5, 0.0)
    place(x, A.thunk(r, 110, 0.07, 0.3), 1.1, 1.0)
    place(x, A.thunk(r, 95, 0.06, 0.25), 1.19, 0.6)
    for k, nm in enumerate(["D4", "A4"]):
        place(x, glass(r, A.hz(nm), 0.9, 0.6), 1.1, 0.35)
    emit_ogg("crate_arrive", "sfx/world/crate_arrive_01", reverb(x, r, 1.2, 0.26, 5500), -2.0, volume_db=-3.0, max_voices=1,
             pitch=[1.0, 1.0], attenuation="loud", bus="SFX")

    # where it stands: a glass hum you only hear close by
    r = r_("hum")
    dur = 6.0
    t = tax(N(dur))
    hum = sum(np.sin(2 * np.pi * A.periodic(fq, dur) * t) * a for fq, a in
              [(146.83, 1.0), (146.83 * 1.004, 0.7), (293.66, 0.3), (440.0, 0.16), (587.33 * 1.002, 0.07)])
    hum *= 0.75 + 0.25 * np.sin(2 * np.pi * A.periodic(1 / 3, dur) * t)
    air = 0.1 * A.loopify(nrm(bp(pink(r, dur + 0.3), 600, 3000)), 0.3) * (0.6 + 0.4 * np.sin(2 * np.pi * A.periodic(0.5, dur) * t + 1.0))
    emit_ogg("crate_hum", "sfx/world/crate_hum_01", hum + air, -9.0, loop=True, bus="SFX", volume_db=-16.0, max_voices=2,
             pitch=[1.0, 1.0], attenuation="world")


def gen_crucible():
    # cold iron ticking
    for i in range(3):
        r = r_("tick", i)
        sec = 0.5
        x = zeros(sec)
        place(x, A.mech_click(r, 2300 + 500 * i, 0.06, 0.004, 22), 0.0, 1.0)
        place(x, glass(r, 1900 + 350 * i, 0.3, 0.07, 0.6), 0.0, 0.25)
        if i == 1:
            place(x, A.mech_click(r, 2000, 0.05, 0.004, 20), 0.11, 0.5)
        emit_ogg("crucible_tick", "sfx/world/crucible_tick_%02d" % (i + 1), reverb(x, r, 0.6, 0.22, 5000), -6.0, volume_db=-12.0,
                 max_voices=2, pitch=[0.9, 1.12], **WORLD)

    # the feed door
    r = r_("feed")
    sec = 1.3
    x = zeros(sec)
    place(x, A.scrape(r, 0.25, 500, 2600, 60.0) * 0.6, 0.0)
    place(x, A.thunk(r, 95, 0.09, 0.4), 0.24, 1.0)
    place(x, reson(white(r, 0.4) * expenv(N(0.4), 0.05), 410, 18) * 0.12, 0.24)
    place(x, reson(white(r, 0.4) * expenv(N(0.4), 0.05), 1130, 25) * 0.07, 0.24)
    for k in range(7):
        place(x, A.mech_click(r, 2600 + r.uniform(-500, 500), 0.04, 0.004), 0.36 + 0.05 * k + r.uniform(0, 0.015), 0.3 * (1 - k / 8.0))
    emit_ogg("crucible_feed", "sfx/world/crucible_feed_01", reverb(x, r, 0.9, 0.22, 4000), -1.5, volume_db=-2.0, max_voices=1,
             pitch=[0.96, 1.04], **WORLD)

    # the hammer inside
    for i in range(3):
        r = r_("clank", i)
        sec = 0.9
        x = zeros(sec)
        place(x, A.kick(r, 0.9, 120 - 10 * i, 48, 0.09, 0.4), 0.0, 1.0)
        hit = white(r, 0.6) * expenv(N(0.6), 0.02)
        ring = reson(hit, 520 + 60 * i, 30) + 0.6 * reson(hit, 1370 + 90 * i, 40) + 0.3 * reson(hit, 2210, 45)
        place(x, nrm(ring) * expenv(N(0.6), 0.22), 0.0, 0.45)
        place(x, nrm(lp(white(r, 0.12), 1400)) * expenv(N(0.12), 0.02), 0.0, 0.5)
        emit_ogg("crucible_clank", "sfx/world/crucible_clank_%02d" % (i + 1), reverb(lp(x, 3800), r, 1.0, 0.25, 3500), -2.0,
                 volume_db=-5.0, max_voices=3, pitch=[0.92, 1.08], **WORLD)

    # out it comes
    r = r_("out")
    sec = 2.4
    x = zeros(sec)
    for k, nm in enumerate(["D4", "A4", "D5", "F#5"]):
        place(x, glass(r, A.hz(nm), 2.0, 1.1, 1.0) * attack(N(2.0), 0.003), 0.012 * k, 0.5 / (1 + 0.25 * k))
    place(x, A.shimmer(r, A.hz("D5"), 1.4, 0.7, 7) * 0.3, 0.0)
    hiss = nrm(bp(white(r, 1.5), 1800, 9000)) * adsr(N(1.5), 0.02, 0.25, 0.45, 0.9)
    place(x, hiss, 0.05, 0.35)
    place(x, A.thunk(r, 120, 0.06, 0.25), 0.0, 0.7)
    emit_ogg("crucible_out", "sfx/world/crucible_out_01", reverb(x, r, 1.3, 0.28, 6500), -2.0, volume_db=-3.0, max_voices=1,
             pitch=[0.98, 1.02], **WORLD)


def write_manifest():
    path = A.AUDIO_JSON
    text = open(path, encoding="utf-8").read()
    nl = "\r\n" if "\r\n" in text else "\n"
    text = text.replace("\r\n", "\n")
    for key in A.KEYS:
        text = re.sub(r',?\n    "%s": \{.*?\n    \}' % re.escape(key), "", text, flags=re.S)
    blocks = []
    for key in sorted(A.KEYS):
        body = json.dumps(A.KEYS[key], indent=2, ensure_ascii=False)
        body = "\n".join(("    " + ln) if i else ln for i, ln in enumerate(body.splitlines()))
        blocks.append('    "%s": %s' % (key, body))
    tail = "\n  }\n}"
    at = text.rstrip().rfind(tail)
    assert at > 0 and text.rstrip().endswith(tail)
    text = text[:at] + ",\n" + ",\n".join(blocks) + tail + "\n"
    json.loads(text)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text.replace("\n", nl))


def main():
    gen_crate()
    gen_crucible()
    write_manifest()
    total = sum(s for _, s in B.STATS)
    print(f"gen_audio_u19_box: wrote {len(B.STATS)} files ({total:.1f} s of audio), {len(A.KEYS)} keys merged into data/gravelight/audio.json")


if __name__ == "__main__":
    main()
