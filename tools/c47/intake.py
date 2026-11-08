#!/usr/bin/env python3
"""T-211: the paperwork for a downloaded C-47 after tools/c47/build.sh built it (the licence gate and the credits).

    python -I tools/c47/intake.py <id> <inbox folder> <out folder>

Writes <out>/SOURCE.txt (the owner's page link from the inbox's SOURCE.txt, the known title / author / licence for
the four candidate models of UPDATE 12 section 5.1, a credit line) and <out>/LICENSE.txt. tools/assets_manifest.py
then puts the credit line in data/credits_art.json, which the Credits screen shows.
"""
import datetime
import os
import re
import sys

KNOWN = {
    "c47-manilov-ap": ("C47", "manilov.ap", "https://sketchfab.com/3d-models/c47-c4fb0f24d55f4866a9669aa952dceaf3", "CC-BY 4.0"),
    "c47-dakota-kn645-mgg8": ("Douglas C-47B Dakota IV KN645", "mgg8", "https://sketchfab.com/3d-models/35da2958566f421593bcc2dac9c3b762", "CC0"),
    "c47-skytrain-spark-customs": ("Douglas C-47 Skytrain", "Spark_Customs", "https://sketchfab.com/3d-models/bd01ee417416492f919a4b988f03bc8b", "CC-BY 4.0"),
    "dc3-manilov-ap": ("Dc3", "manilov.ap", "https://sketchfab.com/3d-models/1668ac86c20b4c3eb2a04d22959a87e1", "CC-BY 4.0"),
}
LICENSE_URL = {"CC-BY 4.0": "https://creativecommons.org/licenses/by/4.0/", "CC0": "https://creativecommons.org/publicdomain/zero/1.0/"}


def main(asset_id, inbox, out):
    title, author, url, lic = KNOWN.get(asset_id, (asset_id, "unknown", "", "CC-BY 4.0"))
    page = url
    src_in = os.path.join(inbox, "SOURCE.txt")
    if os.path.exists(src_in):
        m = re.search(r"https?://\S*sketchfab\.com\S*", open(src_in, encoding="utf-8", errors="replace").read())
        if m:
            page = m.group(0).rstrip(").,")
    today = datetime.date.today().isoformat()
    if lic == "CC0":
        credit = '"%s" by %s (%s), CC0 (public domain). Modified.' % (title, author, page)
    else:
        credit = '"%s" by %s (%s), licensed under %s. Modified.' % (title, author, page, lic)
    files = sorted(f for f in os.listdir(out) if not f.endswith(".import") and f not in ("SOURCE.txt", "LICENSE.txt"))
    src = ("Title: %s\nAuthor: %s\nSource: %s\nLicense: %s (%s)\nCredit line: %s\n"
           "Format: GLB (the Sketchfab download) rebuilt by tools/c47/build_c47.py into the intact and the crashed GRAVELIGHT ONE: "
           "normalized to the 29.0 m span and the map's hull section, cut and posed by data/gravelight/c47_wreck.json, our markings "
           "(fictional serial KQ913, GRAVELIGHT ONE) projected on, our cabin and cockpit added, LODs and an impostor\n"
           "Downloaded: by Devin Blair (Sketchfab, assets/user_supplied/u12/c47/%s); converted %s by tools/c47/build.sh (T-211)\n"
           "Files used: %s\nGame use: GRAVELIGHT ONE, Map 0's crashed C-47 (C47Wreck) and the in-flight cutscene's (C47Intact)\n") % (
        title, author, page, lic, LICENSE_URL[lic], credit, asset_id, today, ", ".join(files))
    with open(os.path.join(out, "SOURCE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    if lic == "CC0":
        text = "CC0 1.0 Universal (public domain dedication)\n%s\n\n%s by %s, %s\n" % (LICENSE_URL[lic], title, author, page)
    else:
        text = ("Creative Commons Attribution 4.0 International (CC BY 4.0)\n%s\n\n%s by %s, %s\n"
                "Attribution is given in the game's Credits screen (data/credits_art.json) and docs/ASSETS.md. Modified.\n") % (
            LICENSE_URL[lic], title, author, page)
    with open(os.path.join(out, "LICENSE.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("[c47] paperwork for %s: %s" % (asset_id, credit))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2], sys.argv[3])
