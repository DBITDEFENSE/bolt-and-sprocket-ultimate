"""T-285: the gameplay trailer's edit (about 86 s at 120 BPM: a bar is 2 s, cuts land on beats).
Sources are the in-engine recordings in build/trailers/src/<run>/<shot>.mp4 (tools/trailer/record.sh)."""

BPM = 120.0
G = "game"


def edit(c, src):
    m0 = lambda s: src("game_m0", s)   # noqa: E731
    m1 = lambda s: src("game_m1", s)   # noqa: E731
    m2 = lambda s: src("game_m2", s)   # noqa: E731
    m4b = lambda s: src("game_m4b", s)  # noqa: E731
    m4d = lambda s: src("game_m4d", s)  # noqa: E731
    return [
        # A, the cold open (the tick bed)
        {"card": None, "dur": 1.0},
        {"src": m2("u01_pen_sweep"), "start": 0.5, "dur": 3.0, "grade": G, "fade_in": 0.6},
        {"src": m1("k01_yard_horde"), "start": 1.5, "dur": 2.0, "grade": G},
        {"src": m0("g02_window_out"), "start": 1.5, "dur": 2.0, "grade": G},
        # B, music A (16 bars)
        {"src": m0("g01_window_fight"), "start": 0.2, "dur": 3.5, "grade": G, "overlay": c["g_hold"]},
        {"src": m0("g15_squad"), "start": 2.0, "dur": 2.0, "grade": G, "overlay": c["g_squad"]},
        {"src": m1("k04_eye_mg"), "start": 0.3, "dur": 2.0, "grade": G},
        {"src": m0("g03_grenade"), "start": 0.8, "dur": 2.5, "grade": G},
        {"src": m0("g04_shell_slowmo"), "start": 0.6, "dur": 2.5, "grade": G, "overlay": c["g_arsenal"]},
        {"src": m0("g05_bomb_wide"), "start": 1.2, "dur": 1.5, "grade": G},
        {"src": m0("g06_tank_drive"), "start": 0.8, "dur": 3.5, "grade": G, "overlay": c["g_steel"]},
        {"src": m0("g07_tank_fire"), "start": 0.6, "dur": 2.5, "grade": G},
        {"src": m0("g08_tank_follow"), "start": 1.0, "dur": 2.0, "grade": G},
        {"src": m0("g11_rocketman"), "start": 0.8, "dur": 1.2, "grade": G},
        {"src": m0("g09_v2_ignite"), "start": 0.6, "dur": 6.0, "grade": G, "overlay": c["g_launch"]},
        {"src": m0("g10_v2_climb"), "start": 2.2, "dur": 2.8, "grade": G},
        # C, music B (the drop at 40 s)
        {"src": m0("g12_horse_follow"), "start": 0.0, "dur": 2.4, "grade": G, "flash": 2, "overlay": c["g_ride"]},
        {"src": m0("g13_horse_rider"), "start": 0.2, "dur": 2.0, "grade": G},
        {"src": m0("g14_zip"), "start": 0.8, "dur": 3.0, "grade": G},
        {"src": m1("k03_zip"), "start": 0.9, "dur": 2.6, "grade": G},
        {"src": m1("k02_tank_gate"), "start": 1.5, "dur": 2.0, "grade": G},
        {"src": m2("u04_quay_horde"), "start": 0.8, "dur": 3.0, "grade": G},
        {"src": m2("u02_tower_down"), "start": 0.5, "dur": 2.0, "grade": G},
        {"src": m4b("f01_wing_sun"), "start": 0.3, "dur": 3.5, "grade": G, "overlay": c["g_fronts"]},
        {"src": m4b("f03_bay_drop"), "start": 0.8, "dur": 2.0, "grade": G},
        {"src": m4b("f04_casing"), "start": 0.5, "dur": 1.5, "grade": G},
        {"src": m4d("f05_earth"), "start": 0.5, "dur": 2.0, "grade": G},
        {"src": m4d("f06_meteors"), "start": 1.0, "dur": 2.0, "grade": G},
        {"src": m0("g16_totenross"), "start": 0.5, "dur": 2.0, "grade": G},
        {"src": m0("g17_cousins"), "start": 0.5, "dur": 2.0, "grade": G},
        # D, the last montage: half a second each
        {"src": m0("g01_window_fight"), "start": 3.6, "dur": 0.5, "grade": G},
        {"src": m0("g03_grenade"), "start": 1.9, "dur": 0.5, "grade": G},
        {"src": m0("g07_tank_fire"), "start": 1.5, "dur": 0.5, "grade": G},
        {"src": m1("k04_eye_mg"), "start": 3.0, "dur": 0.5, "grade": G},
        {"src": m0("g05_bomb_wide"), "start": 1.6, "dur": 0.5, "grade": G},
        {"src": m0("g15_squad"), "start": 4.0, "dur": 0.5, "grade": G},
        {"src": m0("g09_v2_ignite"), "start": 6.8, "dur": 0.5, "grade": G},
        {"src": m0("g12_horse_follow"), "start": 1.0, "dur": 0.5, "grade": G},
        {"card": None, "dur": 0.6},
        {"card": c["g_title"], "dur": 6.4, "fade_in": 0.05, "fade_out": 0.8},
        {"card": c["g_tag"], "dur": 3.0, "fade_in": 0.4, "fade_out": 1.0},
    ]


def _idx(seg, name):
    for i, s in enumerate(seg):
        if name in str(s.get("src", "")) or name == str(s.get("card", "")):
            return i
    return -1


def cues(seg):
    import edit as E
    st = E.starts(seg)
    dur = E.total(seg)
    at = lambda n, k=0: st[[i for i, s in enumerate(seg) if n in str(s.get("src", s.get("missing", "")))][k]]  # noqa: E731
    i_title = len(seg) - 2
    t_b = st[4]
    t_c = st[16]
    t_d = st[30]
    q = [
        (0.0, "tick_bed", t_b),
        (st[3] + 0.0, "groans", 2.0),
        (t_b - 1.5, "roll", 1.5),
        (t_b, "boom", None),
        (t_b, "music_a", t_c - t_b),
        (at("g01_window_fight"), "gun", ("fire_thompson", 12, 0.09)),
        (at("g01_window_fight") + 1.7, "gun", ("fire_thompson", 12, 0.09)),
        (at("g15_squad"), "gun", ("fire_stg44", 8, 0.12)),
        (at("k04_eye_mg"), "gun", ("fire_mg42", 16, 0.06)),
        (at("g03_grenade") + 1.0, "blast", "big"),
        (at("g04_shell_slowmo") + 0.25, "blast", "big"),
        (at("g05_bomb_wide") + 0.2, "blast", "big"),
        (at("g06_tank_drive"), "engine", 3.5 + 2.5 + 2.0),
        (at("g07_tank_fire") + 0.8, "tank_gun", None),
        (at("g07_tank_fire") + 0.9, "blast", "big"),
        (at("g09_v2_ignite") + 0.4, "rocket", 9.0),
        (t_c - 2.0, "roll", 2.0),
        (t_c, "boom", None),
        (t_c, "music_b", t_d - t_c),
        (at("g12_horse_follow"), "horse", 4.4),
        (at("g14_zip"), "zip", 3.0),
        (at("k03_zip"), "zip", 2.0),
        (at("u04_quay_horde"), "groans", 3.0),
        (at("f01_wing_sun"), "whoosh", 0.6),
        (at("f04_casing"), "whoosh", 0.5),
        (at("g16_totenross"), "horse_scream", None),
        (at("g17_cousins"), "roar", 2),
        (t_d, "music_b", st[i_title - 1] - t_d),
    ]
    for k in range(4, i_title - 1):
        q.append((st[k], "hit", None) if k in (4, 10, 14, 16, 23) else (st[k], "whoosh", 0.25))
    for k in range(30, i_title - 1):
        q.append((st[k], "stab", (k * 5) % 12))
    q += [
        (at("g01_window_fight", 1), "gun", ("fire_thompson", 5, 0.09)),
        (at("g03_grenade", 1), "blast", "big"),
        (at("g07_tank_fire", 1), "tank_gun", None),
        (st[i_title - 1], "silence", 0.6),
        (st[i_title], "boom", None),
        (st[i_title] + 0.4, "tick_bed", dur - st[i_title] - 0.4),
    ]
    return q, dur
