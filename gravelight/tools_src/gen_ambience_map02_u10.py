#!/usr/bin/env python3
"""Totenhafen's living-world one-shots (UPDATE 10 section 2.2, DECISIONS T-154): the sounds the MapAmbience events
and the ZoneAmbience beds play that the U09 set (gen_ambience_map02.py) does not have.

    amb_m2_foghorn       the lighthouse's diaphone, every few minutes until it goes dark (round 10)
    amb_m2_siren         the air-raid siren on the cliff (the round-12 raid)
    amb_m2_chain         chains and pulley blocks clanking when they swing
    amb_m2_conveyor      the cannery belt jolting into motion at power-on
    amb_m2_radio         a burst of static and squelch before the U-boat traffic
    amb_m2_cutter_groan  the cutter's timbers groaning and its keel scraping off the cradle (round 15)
    amb_m2_pump_start    the tide pumps thundering up at power-on
    amb_m2_icicle        an icicle shattering on the concrete (the raid)
    amb_m2_crate_spill   a fish crate going over and the fish sliding out
    amb_m2_ship_guns     a warship's guns far out at sea (the beds' one-shot; MapAmbience uses war_artillery_boom)

All synthesis with gen_audio.py's DSP through gen_ambience_map02.py's helpers (no recordings), OGG Vorbis q4 under
gravelight/audio/sfx/ambience/map02/; keys merged into data/gravelight/audio.json (existing tuning kept). Deterministic.

    <python with numpy+scipy> -I gravelight/tools_src/gen_ambience_map02_u10.py
"""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0]]
sys.path.insert(0, HERE)
import gen_ambience_map02 as base   # noqa: E402  (shots(), merge_manifest(), creak(), the gen_audio DSP as base.ga)
import numpy as np                  # noqa: E402

ga = base.ga
N = ga.N
SR = ga.SR


def tone(freqs: np.ndarray, harm: list) -> np.ndarray:
    ph = 2 * np.pi * np.cumsum(freqs) / SR
    return sum(a * np.sin(h * ph) for h, a in harm)


def foghorn(r) -> np.ndarray:
    """A diaphone: a reedy low tone that swells, holds, and drops a fifth into the grunt at the end."""
    sec = 3.6
    n = N(sec)
    x = np.linspace(0, 1, n)
    f = np.where(x < 0.78, 165.0 + 4.0 * np.sin(2 * np.pi * 0.7 * x), 165.0 - 55.0 * (x - 0.78) / 0.22)
    y = tone(f, [(1, 1.0), (2, 0.7), (3, 0.5), (4, 0.3), (5, 0.22), (7, 0.1)])
    y = ga.lp(y, 1400, 2) * ga.adsr(n, 0.35, 0.1, 0.9, 0.5)
    out = np.concatenate([y, np.zeros(N(3.0))])
    return ga.reverb(out, r, 4.0, 0.55, 1600, 0.08)[:len(out)]


def siren(r) -> np.ndarray:
    """An air-raid siren two wails long: the rotor winding up, wailing up and down, running down at the end."""
    sec = 13.0
    n = N(sec)
    t = np.linspace(0, sec, n)
    wail = 0.5 - 0.5 * np.cos(2 * np.pi * t / 6.0)
    spin = np.clip(t / 2.5, 0, 1) * np.clip((sec - t) / 2.5, 0, 1)
    f = 140.0 + 480.0 * wail * spin
    y = tone(f, [(1, 1.0), (2, 0.45), (3, 0.3), (5, 0.12)]) + 0.6 * tone(f * 1.26, [(1, 0.5), (2, 0.2)])
    y = ga.bp(y, 120, 3200) * (0.15 + 0.85 * spin)
    return ga.reverb(ga.lp(y, 2600, 2), r, 3.5, 0.5, 2000, 0.12)[:n]


def chain(r) -> np.ndarray:
    sec = 1.1
    out = np.zeros(N(sec + 0.4))
    t = 0.0
    for k in range(int(r.integers(4, 9))):
        c = ga.mech_click(r, r.uniform(1800, 4200), 0.07, 0.004)
        c = ga.reson(c, r.uniform(2200, 3600), 18) * 0.3 + c
        ga.place(out, c * r.uniform(0.4, 1.0), t)
        t += r.uniform(0.04, 0.16)
    return ga.reverb(out, r, 2.4, 0.4, 4000, 0.03)[:len(out)]


def conveyor(r) -> np.ndarray:
    sec = 2.4
    out = np.zeros(N(sec))
    ga.place(out, ga.thunk(r, 85, 0.08, 0.4), 0.02)
    ga.place(out, ga.thunk(r, 140, 0.03, 0.2) * 0.6, 0.11)
    for k in range(int(sec * 9)):
        ga.place(out, ga.mech_click(r, r.uniform(900, 1500), 0.04, 0.004) * r.uniform(0.2, 0.5) * min(1.0, k / 6), 0.25 + k / 9.0)
    t = ga.tax(N(sec))
    whine = np.sin(2 * np.pi * np.cumsum(40 + 60 * np.clip(t / 1.2, 0, 1)) / SR) * 0.25 * np.clip(t / 0.6, 0, 1)
    return ga.reverb(out + whine, r, 1.6, 0.3, 4000, 0.02)[:N(sec)]


def radio(r) -> np.ndarray:
    sec = r.uniform(0.9, 1.4)
    n = N(sec)
    hiss = ga.bp(ga.white(r, sec), 400, 5200) * (0.5 + 0.5 * ga.smooth_rand(r, sec, 9, 0, 1))
    crack = ga.crackle(r, sec, 40, 1.0, 800, 6000) * 0.8
    sq = np.sin(2 * np.pi * r.uniform(900, 1300) * ga.tax(n)) * 0.25 * ga.expenv(n, 0.08)
    return (hiss * 0.6 + crack + sq) * ga.adsr(n, 0.01, 0.05, 0.8, 0.12)


def cutter_groan(r) -> np.ndarray:
    sec = 6.5
    n = N(sec)
    y = base.creak(r, r.uniform(140, 190), sec) * 0.8 + base.creak(r, r.uniform(260, 330), sec) * 0.4
    scrape = ga.bp(ga.brown(r, sec) + 0.3 * ga.pink(r, sec), 150, 1800) * ga.adsr(n, 1.5, 0.3, 0.9, 1.2)
    crack = np.zeros(n)
    for k in range(4):
        ga.place(crack, ga.thunk(r, r.uniform(90, 160), 0.04, 0.3), r.uniform(1.0, 5.0))
    return ga.reverb(ga.nrm(y) * 0.6 + ga.nrm(scrape) * 0.5 + crack * 0.5, r, 2.5, 0.4, 2500, 0.03)[:n]


def pump_start(r) -> np.ndarray:
    """The tide pumps thundering up: the stroke thumps quickening, the motors' hum rising, the deck rumbling."""
    sec = 7.0
    n = N(sec)
    out = np.zeros(n)
    t = 0.15
    while t < sec - 0.5:
        rate = 1.0 + 2.2 * min(1.0, t / 4.5)
        ga.place(out, ga.thunk(r, r.uniform(48, 62), 0.12, 0.5) * r.uniform(0.8, 1.0), t)
        t += 1.0 / rate
    tt = ga.tax(n)
    f = 25 + 25 * np.clip(tt / 4.0, 0, 1)
    hum = tone(f, [(1, 1.0), (2, 0.6), (4, 0.25)]) * np.clip(tt / 2.0, 0, 1) * 0.35
    rum = ga.lp(ga.brown(r, sec), 90, 2) * np.clip(tt / 3.0, 0, 1)
    y = ga.lp(out, 320) + hum + ga.nrm(rum) * 0.4
    return ga.reverb(y * ga.adsr(n, 0.05, 0.0, 1.0, 0.8), r, 2.8, 0.45, 2200, 0.04)[:n]


def icicle(r) -> np.ndarray:
    sec = 0.9
    out = np.zeros(N(sec))
    ga.place(out, ga.mech_click(r, 5200, 0.03, 0.002), 0.0)
    for k in range(int(r.integers(5, 10))):
        f = r.uniform(3000, 7500)
        d = 0.12
        ping = np.sin(2 * np.pi * f * ga.tax(N(d))) * ga.expenv(N(d), 0.02)
        ga.place(out, ping * r.uniform(0.2, 0.6), r.uniform(0.0, 0.5))
    return ga.reverb(ga.hp(out, 1500), r, 1.2, 0.3, 9000, 0.01)[:len(out)]


def crate_spill(r) -> np.ndarray:
    sec = 1.3
    out = np.zeros(N(sec))
    ga.place(out, ga.thunk(r, 210, 0.04, 0.25), 0.0)
    ga.place(out, ga.thunk(r, 160, 0.05, 0.3) * 0.8, 0.22)
    slide = ga.bp(ga.white(r, 0.7), 600, 3500) * ga.adsr(N(0.7), 0.05, 0.1, 0.6, 0.3) * 0.4
    ga.place(out, slide, 0.25)
    for k in range(5):
        ga.place(out, ga.thunk(r, r.uniform(300, 500), 0.01, 0.05) * 0.3, r.uniform(0.3, 1.0))
    return out


def ship_guns(r) -> np.ndarray:
    sec = 4.5
    n = N(sec)
    out = np.zeros(n)
    for k in range(int(r.integers(1, 3))):
        boom = ga.lp(ga.brown(r, 2.5), 140, 2) * ga.expenv(N(2.5), 0.6)
        ga.place(out, boom, k * r.uniform(0.6, 1.2))
    return ga.reverb(out, r, 3.5, 0.5, 900, 0.1)[:n]


def merge_keys() -> None:
    """Adds / refreshes this tool's keys in audio.json without touching anything else: existing keys keep their
    place and tuning (only "files" is refreshed); new ones go after the U09 amb_m2_* block (json indent 2)."""
    import json
    with open(ga.AUDIO_JSON, "r", encoding="utf-8") as f:
        d = json.load(f)
    sounds = d["sounds"]
    new = sorted(k for k in base.KEYS if k not in sounds)
    for k, v in base.KEYS.items():
        if k in sounds:
            sounds[k]["files"] = v["files"]
    out = {}
    for k, v in sounds.items():
        out[k] = v
        if k == "amb_m2_weld":
            for m in new:
                out[m] = base.KEYS[m]
    for m in new:
        out.setdefault(m, base.KEYS[m])
    d["sounds"] = out
    with open(ga.AUDIO_JSON, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")


def main() -> None:
    R = ga.rng_for
    base.shots("amb_m2_foghorn", "foghorn", [foghorn(R(f"m2u_fog{i}")) for i in range(1, 3)], max_voices=1, attenuation="world")
    base.shots("amb_m2_siren", "siren", [siren(R("m2u_siren1"))], max_voices=3, attenuation="world")
    base.shots("amb_m2_chain", "chain_clank", [chain(R(f"m2u_chain{i}")) for i in range(1, 4)], max_voices=2)
    base.shots("amb_m2_conveyor", "conveyor_jolt", [conveyor(R("m2u_conv1"))], max_voices=1)
    base.shots("amb_m2_radio", "radio_static", [radio(R(f"m2u_radio{i}")) for i in range(1, 4)], max_voices=1)
    base.shots("amb_m2_cutter_groan", "cutter_groan", [cutter_groan(R("m2u_cutter1"))], max_voices=1, attenuation="world")
    base.shots("amb_m2_pump_start", "pump_start", [pump_start(R("m2u_pump1"))], max_voices=2, attenuation="world")
    base.shots("amb_m2_icicle", "icicle", [icicle(R(f"m2u_ice{i}")) for i in range(1, 4)], max_voices=3)
    base.shots("amb_m2_crate_spill", "crate_spill", [crate_spill(R(f"m2u_crate{i}")) for i in range(1, 3)], max_voices=2)
    base.shots("amb_m2_ship_guns", "ship_guns", [ship_guns(R(f"m2u_guns{i}")) for i in range(1, 3)], max_voices=1)
    merge_keys()
    print(f"gen_ambience_map02_u10: {len(base.KEYS)} keys -> data/gravelight/audio.json")


if __name__ == "__main__":
    main()
