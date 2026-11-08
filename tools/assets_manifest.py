#!/usr/bin/env python3
"""Asset manifest (UPDATE_05A section 3 "Credits", T-087). Safe under `python -I`; standard library only.

    python -I tools/assets_manifest.py [--check]

Walks assets/third_party/**/SOURCE.txt, then
  * rewrites the generated block of docs/ASSETS.md between `<!-- assets:begin -->` and `<!-- assets:end -->`
    (everything outside the markers is hand-written and kept), and
  * writes data/credits_art.json, which the in-game Credits screen reads at runtime (MenuCredits), so the
    credits can never drift from the paperwork.
--check: exit 1 (and say what differs) instead of writing, when either file is stale.

SOURCE.txt is `Key: value` per line (Devin's format). Required: Title, Author(s), Source (or Source URL / URL),
License, Credit line. Optional: File, Format, Downloaded, Files used, Game use, Notes, Modified. A folder with a
SOURCE.txt must also hold LICENSE.txt. The GUT test gravelight/tests/unit/test_assets_manifest.gd rebuilds the same
rows in GDScript and fails when the generated block or the JSON is out of date; test_license_gate.gd fails on any
file under assets/ (outside assets/user_supplied/) whose nearest SOURCE.txt is missing or not an allowed licence.
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THIRD = os.path.join(ROOT, "assets", "third_party")
ASSETS_MD = os.path.join(ROOT, "docs", "ASSETS.md")
CREDITS_JSON = os.path.join(ROOT, "data", "credits_art.json")
BEGIN = "<!-- assets:begin -->"
END = "<!-- assets:end -->"

# (regex on the License line, canonical name). Order matters: the first match wins. Mirrored in test_license_gate.gd.
LICENSES = [
    (r"cc0|public domain", "CC0"),
    (r"cc[- ]?by[- ]?4|attribution 4", "CC-BY 4.0"),
    (r"cc[- ]?by[- ]?3|attribution 3", "CC-BY 3.0"),
    (r"\bofl\b|open font", "OFL 1.1"),
    (r"\bmit\b", "MIT"),
    (r"apache", "Apache 2.0"),
    (r"unity asset store|asset store eula", "Unity Asset Store EULA"),
    (r"\bours\b|original work|in-house", "Ours"),
    # T-209: the owner's generated archive-reel clips; only under assets/user_supplied/cutscenes and assets/cutscene_reels
    # (test_license_gate.gd), and their commercial terms wait on the owner's check (their LICENSE.txt, NEEDS_DEVIN)
    (r"higgsfield", "Owner-generated (Higgsfield)"),
]
KEY_ALIASES = {"authors": "author", "source url": "source", "url": "source", "credit": "credit line", "licence": "license"}
REQUIRED = ["title", "author", "source", "license", "credit line"]
SKIP_FILES = {"SOURCE.txt", "LICENSE.txt"}


def parse_source(path):
    fields = {}
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if ":" not in line:
                continue
            k, v = line.split(":", 1)
            k = k.strip().lower()
            k = KEY_ALIASES.get(k, k)
            if k not in fields:
                fields[k] = v.strip()
    return fields


def canonical_license(text):
    t = (text or "").lower()
    for rx, name in LICENSES:
        if re.search(rx, t):
            return name
    return None


def folder_files(folder):
    out = []
    for dp, dns, fns in os.walk(folder):
        dns.sort()
        for fn in sorted(fns):
            if fn in SKIP_FILES or fn.endswith(".import") or fn.endswith(".uid") or fn == ".gdignore":
                continue
            p = os.path.join(dp, fn)
            out.append((os.path.relpath(p, folder).replace(os.sep, "/"), os.path.getsize(p)))
    return out


def collect():
    entries = []
    problems = []
    if not os.path.isdir(THIRD):
        return entries, problems
    for dp, dns, fns in os.walk(THIRD):
        dns.sort()
        if "SOURCE.txt" not in fns:
            continue
        rel = os.path.relpath(dp, THIRD).replace(os.sep, "/")
        fields = parse_source(os.path.join(dp, "SOURCE.txt"))
        missing = [k for k in REQUIRED if k not in fields]
        if missing:
            problems.append("%s/SOURCE.txt lacks %s" % (rel, ", ".join(missing)))
        if "LICENSE.txt" not in fns:
            problems.append("%s has no LICENSE.txt" % rel)
        lic = canonical_license(fields.get("license", ""))
        if lic is None:
            problems.append("%s: licence not recognised: %r" % (rel, fields.get("license", "")))
        files = folder_files(dp)
        parts = rel.split("/")
        entries.append({
            "folder": "assets/third_party/" + rel,
            "source": parts[0],
            "id": "/".join(parts[1:]) if len(parts) > 1 else "",
            "title": fields.get("title", ""),
            "author": fields.get("author", ""),
            "url": fields.get("source", ""),
            "license": lic or fields.get("license", ""),
            "license_text": fields.get("license", ""),
            "credit": fields.get("credit line", ""),
            "game_use": fields.get("game use", ""),
            "files": [f for f, _ in files],
            "bytes": sum(s for _, s in files),
        })
    entries.sort(key=lambda e: e["folder"])
    return entries, problems


def md_cell(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def render_block(entries):
    lines = [BEGIN,
             "## Third-party files (generated)",
             "",
             "Generated by `python -I tools/assets_manifest.py` from every `assets/third_party/**/SOURCE.txt`; do not edit by hand. "
             "Each folder also holds its `LICENSE.txt`. The same data drives the in-game Credits (\"Art credits\", from `data/credits_art.json`). "
             "Guns: `docs/WEAPON_MODELS.md`; intake flow: `tools/intake_guns.py`.",
             "",
             "| Folder | Title | Author | Licence | Credit line | Files |",
             "|---|---|---|---|---|---|"]
    for e in entries:
        kb = (e["bytes"] + 512) // 1024
        lines.append("| `%s` | %s | %s | %s | %s | %d files, %d KB |" % (
            e["folder"], md_cell(e["title"]), md_cell(e["author"]), md_cell(e["license"]), md_cell(e["credit"]), len(e["files"]), kb))
    if not entries:
        lines.append("| (none yet) | | | | | |")
    total_kb = (sum(e["bytes"] for e in entries) + 512) // 1024
    lines.append("")
    lines.append("%d third-party folders, %d KB in all." % (len(entries), total_kb))
    lines.append(END)
    return "\n".join(lines)


def credits_doc(entries):
    # one in-game line per distinct credit line; several assets sharing it list their titles after it
    groups = {}
    order = []
    for e in entries:
        key = e["credit"]
        if key not in groups:
            groups[key] = {"credit": key, "license": e["license"], "source": e["source"], "titles": [], "folders": []}
            order.append(key)
        groups[key]["titles"].append(e["title"])
        groups[key]["folders"].append(e["folder"])
    return {
        "_doc": "Generated by tools/assets_manifest.py from assets/third_party/**/SOURCE.txt; the Credits screen's 'Art credits' section is built from this at runtime. Do not edit.",
        "entries": [{k: e[k] for k in ("folder", "source", "id", "title", "author", "url", "license", "credit", "files")} for e in entries],
        "credit_lines": [groups[k] for k in order],
    }


def splice(md, block):
    if BEGIN in md and END in md:
        a = md.index(BEGIN)
        b = md.index(END) + len(END)
        return md[:a] + block + md[b:]
    return md.rstrip("\n") + "\n\n" + block + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    entries, problems = collect()
    for p in problems:
        print("PROBLEM:", p)
    block = render_block(entries)
    with open(ASSETS_MD, "r", encoding="utf-8") as f:
        md = f.read()
    new_md = splice(md, block)
    new_json = json.dumps(credits_doc(entries), indent=1, ensure_ascii=False) + "\n"
    old_json = ""
    if os.path.exists(CREDITS_JSON):
        with open(CREDITS_JSON, "r", encoding="utf-8") as f:
            old_json = f.read()
    stale = []
    if new_md != md:
        stale.append("docs/ASSETS.md")
    if new_json != old_json:
        stale.append("data/credits_art.json")
    if a.check:
        if stale:
            print("STALE:", ", ".join(stale), "(run: python -I tools/assets_manifest.py)")
            sys.exit(1)
        print("manifest current: %d folders" % len(entries))
        sys.exit(1 if problems else 0)
    with open(ASSETS_MD, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_md)
    os.makedirs(os.path.dirname(CREDITS_JSON), exist_ok=True)
    with open(CREDITS_JSON, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_json)
    print("wrote %s and %s: %d folders%s" % (os.path.relpath(ASSETS_MD, ROOT), os.path.relpath(CREDITS_JSON, ROOT), len(entries),
                                             " (" + ", ".join(stale) + " changed)" if stale else " (no change)"))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
