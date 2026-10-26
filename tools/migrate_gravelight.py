"""Brings the built GRAVELIGHT project (C:\\Users\\Devin\\PROJECTS\\New folder) into TERMS & CONDITIONS as the
Gravelight module (DECISIONS T-007, T-024). Re-runnable: it wipes and recopies /gravelight and /data/gravelight.

What it does:
  - copies autoload/ enemies/ maps/ player/ ui/ weapons/ world/ tools_src/ tests/ audio/ assets/  ->  gravelight/<dir>/
    and data/*.json -> data/gravelight/ ; default_bus_layout.tres -> project root (Gravelight's audio buses)
  - rewrites res:// paths in .gd .tscn .tres .json .cfg .import .gdshader files
  - renames the autoloads that collide with the shared core, inside Gravelight code only:
        EventBus -> GLBus, Data -> GLData, Settings -> GLSettings, VOManager -> GLVO, DevConsole -> GLConsole
    (their signals / APIs differ from the core's; unification is M9)
  - gives Gravelight its own save files: user://gravelight_profile.json, user://gravelight_settings.cfg
  - prints the autoload block to paste into project.godot (the script also patches it)
The original folder is only read, never modified.
Usage: python tools/migrate_gravelight.py"""
import os, re, shutil, sys

SRC = os.environ.get("GRAVELIGHT_MIGRATE_SRC", r"C:\Users\Devin\PROJECTS\New folder")   # one-off M0 tool; override per machine
DST = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = ["autoload", "enemies", "maps", "player", "ui", "weapons", "world", "net", "tools_src", "tests", "audio", "assets"]
TEXT_EXT = {".gd", ".tscn", ".tres", ".json", ".cfg", ".import", ".gdshader", ".txt", ".md"}
RENAMES = [("EventBus", "GLBus"), ("Data", "GLData"), ("Settings", "GLSettings"), ("VOManager", "GLVO"), ("DevConsole", "GLConsole")]
AUTOLOAD_ORDER = ["GLBus", "GLData", "GLSettings", "ProfileSave", "GameState", "Economy", "RoundManager", "PowerupManager",
                  "PerkManager", "CrateManager", "QuestManager", "AudioDirector", "GLVO", "Effects", "Net", "GLConsole"]

path_re = re.compile(r"res://(" + "|".join(DIRS) + r")/")


def rewrite(text: str, is_gd: bool) -> str:
    text = path_re.sub(lambda m: "res://gravelight/%s/" % m.group(1), text)
    text = text.replace("res://data/", "res://data/gravelight/")
    if is_gd:
        for old, new in RENAMES:
            text = re.sub(r"(?<![\w.])%s(?=\s*\.)" % old, new, text)       # Old.member -> New.member
            text = re.sub(r"(?<![\w.])%s(?=\s*[,)\]])" % old, new, text)   # passed as a value
        text = text.replace("user://profile.json", "user://gravelight_profile.json")
        text = text.replace("user://settings.cfg", "user://gravelight_settings.cfg")
    return text


def copy_tree(src: str, dst: str) -> int:
    n = 0
    for root, dirs, files in os.walk(src):
        dirs[:] = [d for d in dirs if d not in (".godot", "__pycache__")]
        rel = os.path.relpath(root, src)
        out = os.path.join(dst, rel) if rel != "." else dst
        os.makedirs(out, exist_ok=True)
        for f in files:
            sp, dp = os.path.join(root, f), os.path.join(out, f)
            ext = os.path.splitext(f)[1].lower()
            if ext in TEXT_EXT:
                with open(sp, encoding="utf-8", errors="surrogateescape") as fh:
                    t = fh.read()
                with open(dp, "w", encoding="utf-8", newline="\n", errors="surrogateescape") as fh:
                    fh.write(rewrite(t, ext == ".gd"))
            else:
                shutil.copy2(sp, dp)
            n += 1
    return n


## Post-copy patches (file, old, new). Each "old" must match exactly once, or the migration stops.
## T = tab, N = newline (constants keep the patch text readable and escape-safe).
T = "\t"
N = "\n"
PATCHES = [
    ("gravelight/autoload/settings.gd",
     T + "apply_bindings()" + N + T + "_build_overlays()" + N + T + "apply_visuals()" + N,
     T + "_build_overlays()" + N + T + "_overlay.visible = false   # Gravelight only: see activate() (T-024)" + N),
    ("gravelight/autoload/settings.gd",
     "func _on_node_added(n: Node) -> void:" + N + T + "if n is WorldEnvironment:",
     "## The shared game hosts several modes: Gravelight's bindings, screen overlays (colorblind, film grain) and" + N
     + "## environment presets apply only while Gravelight is active." + N
     + "var active: bool = false" + N + N + N
     + "func activate() -> void:" + N + T + "active = true" + N + T + "apply_bindings()" + N
     + T + "_overlay.visible = true" + N + T + "apply_visuals()" + N + N + N
     + "func deactivate() -> void:" + N + T + "active = false" + N + T + "if _overlay != null:" + N
     + T + T + "_overlay.visible = false" + N + N + N
     + "func _on_node_added(n: Node) -> void:" + N + T + "if n is WorldEnvironment and active:"),
    ("gravelight/ui/main_menu.gd",
     "func _ready() -> void:" + N + T + "get_tree().paused = false" + N,
     "func _ready() -> void:" + N + T + "GLSettings.activate()" + N + T + "Game.set_mode(Game.Mode.GRAVELIGHT)" + N
     + T + "get_tree().paused = false" + N),
    # Gravelight is one mode of the merged game: its Quit returns to the hub instead of closing everything.
    ("gravelight/ui/main_menu.gd",
     'MenuKit.button("Quit", func() -> void: get_tree().quit(), 26)',
     'MenuKit.button("Back to Terms & Conditions", func() -> void: get_tree().change_scene_to_file("res://ui/main_menu.tscn"), 26)'),
    # A click carried over from the hub (double-click) must not land on a menu button.
    ("gravelight/ui/main_menu.gd",
     T + "add_child(_menu)" + N + T + "_build()" + N,
     T + "add_child(_menu)" + N + T + "_build()" + N
     + T + "var guard: Control = Control.new()   # swallow clicks for a moment (T-025)" + N
     + T + "guard.set_anchors_preset(Control.PRESET_FULL_RECT)" + N
     + T + "guard.mouse_filter = Control.MOUSE_FILTER_STOP" + N
     + T + "add_child(guard)" + N
     + T + "get_tree().create_timer(0.35).timeout.connect(guard.queue_free)" + N),
    ("gravelight/tests/unit/test_progression.gd",
     "func test_keybind_override_roundtrip() -> void:" + N,
     "func test_keybind_override_roundtrip() -> void:" + N + T + "GLSettings.activate()   # Gravelight's bindings exist only in Gravelight mode (T-024)" + N),
    ("gravelight/maps/map_root.gd",
     "func _ready() -> void:" + N + T + "get_tree().paused = false" + N + T + "_online",
     "func _ready() -> void:" + N + T + "GLSettings.activate()" + N + T + "Game.set_mode(Game.Mode.GRAVELIGHT)" + N
     + T + "get_tree().paused = false" + N + T + "_online"),
]


def apply_patches() -> None:
    for rel, old, new in PATCHES:
        p = os.path.join(DST, rel)
        t = open(p, encoding="utf-8").read()
        if t.count(old) != 1:
            sys.exit("patch failed (%d matches) in %s: %r" % (t.count(old), rel, old[:60]))
        open(p, "w", encoding="utf-8", newline=N).write(t.replace(old, new))


def main() -> None:
    if "--force" not in sys.argv:
        sys.exit("The migration is done (T-024). gravelight/ has been edited since (playtest fixes, T-026); re-running "
                 "would discard them. Pass --force only if you mean to start over from the original project.")
    gl = os.path.join(DST, "gravelight")
    gd = os.path.join(DST, "data", "gravelight")
    for p in (gl, gd):
        if os.path.isdir(p):
            shutil.rmtree(p)
    total = 0
    for d in DIRS:
        s = os.path.join(SRC, d)
        if os.path.isdir(s):
            total += copy_tree(s, os.path.join(gl, d))
    total += copy_tree(os.path.join(SRC, "data"), gd)
    bus = os.path.join(SRC, "default_bus_layout.tres")
    if os.path.exists(bus):
        shutil.copy2(bus, os.path.join(DST, "default_bus_layout.tres"))
    # autoloads from the source project.godot, renamed and repathed
    src_proj = open(os.path.join(SRC, "project.godot"), encoding="utf-8").read()
    block = src_proj.split("[autoload]", 1)[1].split("\n[", 1)[0]
    entries = {}
    for line in block.strip().splitlines():
        if "=" not in line or line.startswith(";"):
            continue
        name, val = line.split("=", 1)
        name = dict(RENAMES).get(name.strip(), name.strip())
        entries[name] = path_re.sub(lambda m: "res://gravelight/%s/" % m.group(1), val.strip())
    proj_path = os.path.join(DST, "project.godot")
    proj = open(proj_path, encoding="utf-8").read()
    head, rest = proj.split("[autoload]", 1)
    auto, tail = (rest.split("\n[", 1) + [""])[:2]
    keep = [l for l in auto.strip().splitlines() if l.split("=", 1)[0].strip() not in entries]
    new_auto = "\n".join(keep + ["%s=%s" % (k, entries[k]) for k in AUTOLOAD_ORDER if k in entries]
                         + ["%s=%s" % (k, v) for k, v in entries.items() if k not in AUTOLOAD_ORDER])
    proj = head + "[autoload]\n\n" + new_auto + "\n\n[" + tail
    if "[layer_names]" not in proj:
        layers = src_proj.split("[layer_names]", 1)[1].split("\n[", 1)[0]
        proj += "\n[layer_names]\n" + layers.rstrip() + "\n"
    open(proj_path, "w", encoding="utf-8", newline="\n").write(proj)
    apply_patches()
    print("copied %d files into gravelight/ and data/gravelight/; %d autoloads registered" % (total, len(entries)))


if __name__ == "__main__":
    main()
