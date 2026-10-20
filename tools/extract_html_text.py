"""Extracts player-facing text from the web build's HTML markup (menu screens, race lobby, settings copy,
HUD labels): every text node and title/placeholder/aria-label attribute outside <script>/<style>.
Usage: python tools/extract_html_text.py  ->  data/bs/story/html_text.json  [{id, screen, text, src_line}]
The screen is the id of the nearest enclosing element that has one (e.g. "race", "shop")."""
import json, os, re
from html.parser import HTMLParser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "reference", "bs_web", "index.html")
VOID = {"br", "img", "input", "meta", "link", "hr", "source", "area", "col", "embed", "wbr", "base", "param", "track"}


class P(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []   # [tag, id]
        self.skip = 0
        self.out = []
        self.n = {}

    def _screen(self):
        for tag, eid in reversed(self.stack):
            if eid:
                return eid
        return "page"

    def _add(self, text):
        text = re.sub(r"\s+", " ", text).strip()
        if len(text) < 2 or not re.search(r"[A-Za-z]", text):
            return
        sc = self._screen()
        self.n[sc] = self.n.get(sc, 0) + 1
        self.out.append({"id": "html.%s.%03d" % (sc, self.n[sc]), "screen": sc, "text": text, "src_line": self.getpos()[0]})

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in ("script", "style"):
            self.skip += 1
        if tag not in VOID:
            self.stack.append((tag, a.get("id")))
        if not self.skip:
            for k in ("title", "placeholder", "aria-label", "data-tip"):
                if a.get(k):
                    self._add(a[k])

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.skip = max(0, self.skip - 1)
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break

    def handle_data(self, data):
        if not self.skip:
            self._add(data)


p = P()
p.feed(open(SRC, encoding="utf-8").read())
dst = os.path.join(ROOT, "data", "bs", "story", "html_text.json")
json.dump(p.out, open(dst, "w", encoding="utf-8", newline="\n"), indent=2, ensure_ascii=False)
print("extracted %d html text items across %d screens" % (len(p.out), len(p.n)))
