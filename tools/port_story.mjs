// Ports every written line of the Bolt & Sprocket web build from /data/bs_source (extract_bs.mjs output) into
// the remake's story data under /data/bs/story/, giving every line a stable VO line ID.
// Usage: node tools/port_story.mjs
// Output files: speakers, cutscenes, story_beats, quests, memos, barks, blartz, ads, zonga, loop_riot,
// arena, settings_text, plus lines_index.json (line id -> {who, text}) used by the VOManager.
// Line text is copied verbatim. Edits to existing lines are made later, in the data files, and logged in
// docs/STORY_CHANGES.md.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const S = (n) => JSON.parse(fs.readFileSync(path.join(root, "data/bs_source", n + ".json"), "utf8"));
const out = path.join(root, "data/bs/story");
fs.mkdirSync(out, { recursive: true });
const index = {};
const put = (id, who, text) => {
  if (index[id]) throw new Error("duplicate line id " + id);
  index[id] = { who, text };
  return { id, who, text };
};
const write = (name, v) => fs.writeFileSync(path.join(out, name + ".json"), JSON.stringify(v, null, 2));
const pad = (n) => String(n).padStart(2, "0");

// ---- speakers + voices
const voices = S("VOICE_PROFILES");
const npcVoice = S("NPC_VOICE");
const speakers = S("SPEAKERS");
for (const [k, v] of Object.entries(speakers)) v.voice = voices[k] || null;
write("speakers", { speakers, voice_profiles: voices, npc_voice: npcVoice });

// ---- cutscenes (dialogue in order; staging steps kept as notes for the remake's cutscene player)
const titles = {};
for (const [id, title, group] of S("CUTSCENE_INDEX")) titles[id] = { title, group };
const cutscenes = {};
for (const [id, cs] of Object.entries(S("CUTSCENES"))) {
  let n = 0;
  const steps = [];
  for (const st of cs.steps || []) {
    if (st.type === "dlg") steps.push({ type: "line", ...put(`cs.${id}.${pad(++n)}`, st.who, st.text) });
    else {
      const note = { type: st.type };
      for (const [k, v] of Object.entries(st)) {
        if (k === "type") continue;
        note[k] = v && typeof v === "object" && (v.__fn__ || v.__call__) ? (v.__src__ || v.__call__) : v;
      }
      steps.push(note);
    }
  }
  cutscenes[id] = { title: titles[id]?.title || id, gallery_group: titles[id]?.group || null, steps };
}
write("cutscenes", cutscenes);

// ---- in-level story beats (STORY: holo calls, mid-level conversations)
const beats = {};
for (const [id, lines] of Object.entries(S("STORY"))) {
  beats[id] = { title: titles[id]?.title || id, lines: lines.map((l, i) => put(`st.${id}.${pad(i + 1)}`, l.who, l.text)) };
}
write("story_beats", beats);

// ---- quests
// The web build reuses three quest ids (q6a/q6b on planets 9 and 7, q3b twice on planet 2), so their saved
// progress collided. The remake gives each a unique id and keeps the original as source_id (DECISIONS.md).
const QUEST_ID_FIX = { "9:q6a": "q9a", "9:q6b": "q9b", "7:q6a": "q7a", "7:q6b": "q7b", "2:q3b:Art Criticism": "q3c" };
const quests = S("QUESTS").map((q0) => {
  const fix = QUEST_ID_FIX[`${q0.planet}:${q0.id}:${q0.name}`] || QUEST_ID_FIX[`${q0.planet}:${q0.id}`];
  const q = fix ? { ...q0, id: fix, source_id: q0.id } : q0;
  const o = { ...q };
  for (const phase of ["intro", "prog", "done"]) {
    if (Array.isArray(q[phase])) o[phase] = q[phase].map((l, i) => put(`q.${q.id}.${phase}.${pad(i + 1)}`, l.who, l.text));
  }
  return o;
});
write("quests", quests);

// ---- memos (+ where they were placed)
const memos = S("MEMOS").map((m, i) => ({ id: `memo.${pad(i + 1)}`, title: m.t, body: m.b, planet: (S("MEMO_PLANETS") || [])[i] ?? null }));
for (const m of memos) index[m.id] = { who: "memo", text: m.title + " — " + m.body };
write("memos", { memos, spots: S("MEMO_SPOTS"), planets: S("MEMO_PLANETS") });

// ---- barks (Sprocket ambient, super, splash/out-of-bounds, mall PA)
const lineList = (prefix, who, arr) => arr.map((t, i) => put(`${prefix}.${pad(i + 1)}`, who, t));
const barks = {};
for (const [cat, arr] of Object.entries(S("BARKS"))) barks[cat] = lineList(`bark.${cat}`, "sprocket", arr);
const sup = S("SUPER_BARKS");
const superB = Array.isArray(sup) ? { all: lineList("super", "sprocket", sup) } :
  Object.fromEntries(Object.entries(sup).map(([k, v]) => [k, Array.isArray(v) ? lineList(`super.${k}`, "sprocket", v) : v]));
const splash = S("SPLASH_QUIPS");
const splashB = Array.isArray(splash) ? lineList("splash", "sprocket", splash) :
  Object.fromEntries(Object.entries(splash).map(([k, v]) => [k, Array.isArray(v) ? lineList(`splash.${k}`, "sprocket", v) : put(`splash.${k}`, "sprocket", v)]));
const pa = S("GALLERIA_PA");
write("barks", { sprocket: barks, super_sprocket: superB, out_of_bounds: splashB,
  galleria_pa: Array.isArray(pa) ? lineList("pa.galleria", "pa", pa) : pa });

// ---- Blartz (shop pitches, denies, buys, tips, per-item lines)
const bl = S("BLARTZ_LINES");
const blartz = Object.fromEntries(Object.entries(bl).map(([k, v]) => [k, Array.isArray(v) ? lineList(`blartz.${k}`, "blartz", v) : v]));
const items = S("BLARTZ_ITEM_LINES");
blartz.items = Object.fromEntries(Object.entries(items).map(([k, v]) =>
  [k, Array.isArray(v) ? lineList(`blartz.item.${k}`, "blartz", v) : put(`blartz.item.${k}`, "blartz", v)]));
write("blartz", blartz);

// ---- ads (billboards, Loop Riot boards, the weapon-ad vignette ids, K.A.R.E.N.)
write("ads", { billboards: S("AD_LINES"), loop_riot_boards: S("LR_ADS"), weapon_ad_vignettes: S("WEAPON_AD"),
  extra_vignettes: ["ad_karen"], note: "Vignette dialogue lives in cutscenes.json under the same ids." });

// ---- Zonga
const zj = S("SPONSOR_JOKES");
write("zonga", { stages: S("ZONGA_STAGES"), bot_names: S("BOT_NAMES"),
  sponsor_jokes: Array.isArray(zj) ? lineList("zonga.sponsor", "glambot", zj) : zj });

// ---- Loop Riot
const notices = S("NOTICES");
const quips = S("QUIPS");
write("loop_riot", {
  crew: S("CREW"), ai_profiles: S("AI_PROFILES"), leagues: S("LEAGUES"), ranks: S("RANKS"), decks: S("DECKS"),
  notices: Array.isArray(notices) ? notices.map((n, i) => (typeof n === "string" ? put(`lr.notice.${pad(i + 1)}`, "notice", n) : n)) : notices,
  quips: Object.fromEntries(Object.entries(quips).map(([k, v]) => [k, Array.isArray(v) ? lineList(`lr.quip.${k}`, k, v) : v])),
  flips: S("FLIPS"), grabs: S("GRAB_NAMES"), grinds: S("GRIND_NAMES"), ads: S("LR_ADS"),
});

// ---- arena / prix / cosmetics / settings text
write("arena", { challenges: S("CHALLENGES"), pools: S("ARENA_POOLS"), boss_rush: S("BOSS_RUSH"), tracks: S("TRACKS"), rivals: S("RIVAL_ROSTER") });
write("cosmetics", { paints: S("PAINTS"), hats: S("HATS"), mallet_skins: S("MSKINS") });
write("settings_text", S("SETTINGS_DEF"));

write("lines_index", index);
const n = Object.keys(index).length;
console.log(`ported ${n} lines: ${Object.keys(cutscenes).length} cutscenes, ${Object.keys(beats).length} story beats, ` +
  `${quests.length} quests, ${memos.length} memos`);
