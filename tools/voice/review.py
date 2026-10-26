#!/usr/bin/env python3
"""The voice review page (UPDATE 06 B5.9, T-101): voice_review/index.html, a local page listing every line with the
selected take, the alternate takes, the transcript-vs-script match, buttons to pick another take (or the TTS), the
coverage per actor and character, and the uncertain matches. Generated; git-ignored (it points at private takes).

  tools/voice.sh review        rebuild the page and serve it on http://127.0.0.1:8765 (choices save straight to
                               data/voice/selections.json; then tools/voice.sh import applies them)
  python tools/voice/review.py --build-only
Opened as a plain file the page still works; it then offers selections.json as a download to put in data/voice/.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voicelib as V  # noqa: E402

PAGE = os.path.join(V.REVIEW_DIR, "index.html")


def gather() -> dict:
    cast = V.load_cast()
    lines = V.collect_all()
    by_actor = V.lines_by_actor(lines, cast)
    rd = V.load_json(os.path.join(V.WORK_DIR, "review_data.json"), {})
    files = {**V.load_manifest("gl").get("files", {}), **V.load_manifest("bs").get("files", {})}
    takes: dict[str, list] = {}
    for t in rd.get("takes", []):
        takes.setdefault(t["file_id"], []).append(t)
    rows = []
    for ln in lines:
        m = files.get(ln.file_id, {})
        src = m.get("source", "tts" if (ln.game == "bs" or m) else "none")
        actors = V.actors_for(cast, ln.game, ln.char)
        game_audio = "../" + ln.res_path[len("res://"):] if (ln.game == "gl" and m) or src not in ("tts", "none") else ""
        tts_audio = ""
        if src != "tts" and m.get("tts"):
            tts_audio = "../gravelight/audio/vo_tts/%s/%s.ogg" % (ln.res_path.split("/")[-2], ln.file_id)
        elif src == "tts" and ln.game == "gl" and m:
            tts_audio = game_audio
        rows.append({"id": ln.file_id, "game": ln.game, "char": ln.char, "name": V.character_label(cast, ln.game, ln.char),
                     "actors": actors, "text": V.spoken_text(ln.text), "delivery": ln.delivery, "source": src,
                     "actor": m.get("actor", ""), "take": m.get("take", ""), "audio": game_audio, "tts": tts_audio,
                     "takes": sorted(takes.get(ln.file_id, []), key=lambda t: -t["score"])})
    cov_actor = {}
    for a, al in by_actor.items():
        ids = {ln.file_id for ln in al}
        rec = sum(1 for i in ids if files.get(i, {}).get("source") == "human" and a in files[i].get("actor", "").split("+"))
        cov_actor[a] = {"name": V.actor_name(cast, a), "recorded": rec, "total": len(ids),
                        "takes": sum(1 for i in ids if i in takes), "consent": rd.get("consent", {}).get(a)}
    cov_char = {}
    for ln in lines:
        k = "%s:%s" % (ln.game, ln.char)
        c = cov_char.setdefault(k, {"name": V.character_label(cast, ln.game, ln.char), "recorded": 0, "ai": 0, "total": 0})
        c["total"] += 1
        s = files.get(ln.file_id, {}).get("source", "")
        if s == "human":
            c["recorded"] += 1
        elif s.startswith("ai_"):
            c["ai"] += 1
    uncertain = [t for t in rd.get("takes", []) if t.get("uncertain")]
    return {"rows": rows, "cov_actor": cov_actor, "cov_char": cov_char, "uncertain": uncertain,
            "unmatched": rd.get("unmatched", []), "blocked": rd.get("blocked", {}), "selections": V.load_json(V.SELECTIONS_PATH),
            "generated": rd.get("generated", ""), "total": len(lines)}


def build() -> str:
    data = gather()
    V.gdignore(V.REVIEW_DIR)
    blob = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
    with open(PAGE, "w", encoding="utf-8", newline="\n") as f:
        f.write(TEMPLATE.replace("/*DATA*/null", blob))
    return PAGE


TEMPLATE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Voice review</title>
<style>
:root{--bg:#16130f;--panel:#211c16;--ink:#eee6d8;--dim:#a39886;--line:#3a3127;--acc:#e0a24a;--ok:#7fbf6a;--warn:#e07a4a;--ai:#8aa6e8}
@media (prefers-color-scheme: light){:root:not([data-theme="dark"]){--bg:#f6f1e7;--panel:#fffaf0;--ink:#231d15;--dim:#6c6152;--line:#dccfb8;--acc:#9a5a10;--ok:#3d7a2a;--warn:#b04a1a;--ai:#3556a8}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 system-ui,Segoe UI,sans-serif}
header{position:sticky;top:0;background:var(--panel);border-bottom:1px solid var(--line);padding:10px 16px;z-index:2;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
h1{font-size:17px;margin:0 12px 0 0}h2{font-size:15px;margin:22px 0 8px}main{padding:0 16px 60px;max-width:1300px;margin:auto}
input,select,button{font:inherit;background:var(--bg);color:var(--ink);border:1px solid var(--line);border-radius:6px;padding:4px 8px}
button{cursor:pointer}button.on{border-color:var(--acc);color:var(--acc)}
table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid var(--line);padding:6px;vertical-align:top;text-align:left}
th{color:var(--dim);font-weight:600;font-size:12px}.id{font-family:ui-monospace,Consolas,monospace;font-size:12px;white-space:nowrap}
.dim{color:var(--dim)}.human{color:var(--ok)}.tts{color:var(--dim)}.ai{color:var(--ai)}.warn{color:var(--warn)}
.bar{height:8px;background:var(--line);border-radius:4px;overflow:hidden;min-width:120px}.bar i{display:block;height:100%;background:var(--ok)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:8px}.card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:8px 10px}
audio{height:30px;max-width:240px;vertical-align:middle}.take{margin:3px 0}.pill{font-size:11px;border:1px solid var(--line);border-radius:10px;padding:0 6px;margin-left:4px}
#status{margin-left:auto;color:var(--dim)}.wrap{overflow-x:auto}#rows td:nth-child(2){min-width:260px}
</style></head><body>
<header><h1>Voice review</h1>
<input id="q" placeholder="search id or text" size="22">
<select id="fa"><option value="">every actor</option></select>
<select id="fc"><option value="">every character</option></select>
<select id="fs"><option value="">any status</option><option value="human">recorded (human)</option><option value="takes">has takes</option><option value="uncertain">uncertain</option><option value="tts">computer voice</option><option value="ai">AI</option></select>
<button id="save">Save choices</button><span id="status"></span></header>
<main>
<p class="dim" id="gen"></p>
<div id="blocked"></div>
<h2>Coverage per actor</h2><div class="grid" id="cova"></div>
<h2>Coverage per character</h2><div class="grid" id="covc"></div>
<h2>Uncertain matches <span class="dim" id="nunc"></span></h2><div class="wrap"><table id="unc"></table></div>
<h2>Unmatched speech <span class="dim" id="nunm"></span></h2><div class="wrap"><table id="unm"></table></div>
<h2>Every line <span class="dim" id="nrows"></span></h2><div class="wrap"><table id="rows"></table></div>
</main>
<script>
const D=/*DATA*/null;
const sel=Object.assign({},D.selections||{});let dirty=false;
const esc=s=>String(s??"").replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const pct=(a,b)=>b?Math.round(100*a/b):0;
const served=location.protocol.startsWith("http");
function srcClass(s){return s==="human"?"human":(s||"").startsWith("ai_")?"ai":"tts"}
document.getElementById("gen").textContent=`${D.total} spoken lines. Takes analysed ${D.generated||"(no import yet)"}. `+(served?"Choices save to data/voice/selections.json; run tools/voice.sh import to apply them.":"Opened as a file: Save downloads selections.json; put it in data/voice/ and run tools/voice.sh import.");
const bl=Object.entries(D.blocked||{});if(bl.length)document.getElementById("blocked").innerHTML='<p class="warn">Not shipped (no consent / not cast): '+bl.map(([a,w])=>esc(a)+" — "+esc(w)).join("; ")+"</p>";
const fa=document.getElementById("fa"),fc=document.getElementById("fc");
document.getElementById("cova").innerHTML=Object.entries(D.cov_actor).sort((x,y)=>(y[1].takes-x[1].takes)||x[0].localeCompare(y[0])).map(([a,c])=>{fa.insertAdjacentHTML("beforeend",`<option value="${esc(a)}">${esc(c.name)}</option>`);
 const cs=c.consent?(c.consent.ok?`<span class="human">consent ${esc(c.consent.date)}</span>`+(c.consent.ai_cloning?' <span class="ai">AI cloning: opted in</span>':''):`<span class="warn">no consent</span>`):'<span class="dim">no recordings yet</span>';
 return `<div class="card"><b>${esc(c.name)}</b> <span class="dim id">${esc(a)}</span><div class="bar"><i style="width:${pct(c.recorded,c.total)}%"></i></div>${c.recorded} / ${c.total} recorded (${pct(c.recorded,c.total)}%), ${c.takes} with takes<br>${cs}</div>`}).join("");
document.getElementById("covc").innerHTML=Object.entries(D.cov_char).sort().map(([k,c])=>{fc.insertAdjacentHTML("beforeend",`<option value="${esc(k)}">${esc(c.name)}</option>`);
 return `<div class="card"><b>${esc(c.name)}</b> <span class="dim id">${esc(k)}</span><div class="bar"><i style="width:${pct(c.recorded,c.total)}%"></i></div>${c.recorded} / ${c.total} human`+(c.ai?`, <span class="ai">${c.ai} AI</span>`:"")+`</div>`}).join("");
document.getElementById("nunc").textContent=`(${D.uncertain.length})`;
document.getElementById("unc").innerHTML="<tr><th>line</th><th>take</th><th>heard</th><th>why</th><th></th></tr>"+D.uncertain.map(t=>`<tr><td class="id">${esc(t.file_id)}</td><td><audio controls preload="none" src="../${esc(t.preview)}"></audio><div class="dim id">${esc(t.take)}</div></td><td>${esc(t.transcript)}</td><td class="warn">${esc(t.why)}</td><td><button onclick="pick('${esc(t.file_id)}','${esc(t.take)}')">use it</button></td></tr>`).join("");
document.getElementById("nunm").textContent=`(${D.unmatched.length})`;
document.getElementById("unm").innerHTML="<tr><th>actor</th><th>file</th><th>at</th><th>heard</th><th>closest line</th></tr>"+D.unmatched.map(u=>`<tr><td>${esc(u.actor)}</td><td class="id">${esc(u.src)}</td><td>${u.start}–${u.end} s</td><td>${esc(u.transcript)}</td><td class="id">${esc(u.best)} ${Math.round(100*u.score)}%</td></tr>`).join("");
function pick(id,take){sel[id]=take==="auto"?undefined:{take,by:"review",at:new Date().toISOString().slice(0,10)};if(take==="auto")delete sel[id];dirty=true;status(`${id}: ${take}`);render()}
function status(s){document.getElementById("status").textContent=(dirty?"unsaved · ":"")+s}
function rowHtml(r){const s=sel[r.id];const chosen=s?(s.take||s):"";
 const takes=r.takes.map(t=>`<div class="take"><audio controls preload="none" src="../${esc(t.preview)}"></audio> <span class="${t.uncertain?"warn":"dim"}">${Math.round(100*t.text_score)}% text · score ${t.score.toFixed(2)}</span>${(chosen===t.take)||(!chosen&&r.take.split("+").includes(t.take))?'<span class="pill human">selected</span>':` <button onclick="pick('${esc(r.id)}','${esc(t.take)}')">use</button>`}<div class="dim id">${esc(t.take)} · “${esc(t.transcript)}”</div></div>`).join("");
 const ttsb=r.takes.length?` <button class="${chosen==="tts"?"on":""}" onclick="pick('${esc(r.id)}','tts')">use computer voice</button> <button onclick="pick('${esc(r.id)}','auto')">auto</button>`:"";
 return `<tr><td class="id">${esc(r.id)}<div class="dim">${esc(r.name)}</div></td><td>${esc(r.text)}<div class="dim">${esc(r.delivery)} · ${esc(r.actors.join(", "))}</div></td><td class="${srcClass(r.source)}">${esc(r.source)}${r.actor?"<div class='dim'>"+esc(r.actor)+"</div>":""}${r.source.startsWith("ai_")?'<div class="ai">AI-generated</div>':""}</td><td>${r.audio?`<audio controls preload="none" src="${esc(r.audio)}"></audio>`:'<span class="dim">no file</span>'}${r.tts&&r.tts!==r.audio?`<div class="dim">TTS: <audio controls preload="none" src="${esc(r.tts)}"></audio></div>`:""}</td><td>${takes||'<span class="dim">no takes</span>'}${ttsb}</td></tr>`}
let shown=200;
function render(){const q=document.getElementById("q").value.toLowerCase(),a=fa.value,c=fc.value,s=document.getElementById("fs").value;
 const rs=D.rows.filter(r=>(!q||r.id.toLowerCase().includes(q)||r.text.toLowerCase().includes(q))&&(!a||r.actors.includes(a))&&(!c||`${r.game}:${r.char}`===c)&&
  (!s||(s==="human"&&r.source==="human")||(s==="takes"&&r.takes.length)||(s==="uncertain"&&r.takes.some(t=>t.uncertain))||(s==="tts"&&r.source==="tts")||(s==="ai"&&r.source.startsWith("ai_"))));
 document.getElementById("nrows").textContent=`(${rs.length})`;
 document.getElementById("rows").innerHTML="<tr><th>line</th><th>script</th><th>in game</th><th>playing now</th><th>takes</th></tr>"+rs.slice(0,shown).map(rowHtml).join("")+(rs.length>shown?`<tr><td colspan="5"><button onclick="shown+=300;render()">show more (${rs.length-shown} left)</button></td></tr>`:"")}
["q","fa","fc","fs"].forEach(i=>document.getElementById(i).addEventListener("input",()=>{shown=200;render()}));
document.getElementById("save").onclick=async()=>{const body=JSON.stringify(sel,null,1);
 if(served){try{const r=await fetch("/api/selections",{method:"POST",headers:{"Content-Type":"application/json"},body});if(!r.ok)throw new Error(await r.text());dirty=false;status("saved to data/voice/selections.json");return}catch(e){status("save failed: "+e.message+" (downloading instead)")}}
 const a=document.createElement("a");a.href=URL.createObjectURL(new Blob([body],{type:"application/json"}));a.download="selections.json";a.click();dirty=false;status("downloaded selections.json: put it in data/voice/")};
window.addEventListener("beforeunload",e=>{if(dirty){e.preventDefault();e.returnValue=""}});
render();
</script></body></html>
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--build-only", action="store_true")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--no-browser", action="store_true")
    a = ap.parse_args()
    page = build()
    print("built", page)
    if a.build_only:
        return 0
    import review_server
    return review_server.serve(a.port, not a.no_browser)


if __name__ == "__main__":
    sys.exit(main())
