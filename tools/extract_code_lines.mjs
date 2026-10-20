// Extracts the player-facing text that the web build shows or speaks from CODE rather than from data tables:
// boss barks (speak / showBark), banners (showBanner / bossStart / arenaEnd), hints (showHint), the Zonga
// announcer and kill feed, Blartz shop pitches, signs and checkpoints, Loop Riot taglines.
// Usage: node tools/extract_code_lines.mjs   -> data/bs/story/code_lines.json
// Each line: { id: "code.<enclosing function>.<nn>", who, kind, text, src_line }. Template literals keep their
// substitutions as {expression}. tools/port_story.mjs merges these into lines_index.json.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as acorn from "./node_modules/acorn/dist/acorn.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const src = fs.readFileSync(path.join(root, "reference/bs_web/index.html"), "utf8");
const open = src.indexOf('<script type="module">');
const code = src.slice(open + '<script type="module">'.length, src.indexOf("</script>", open));
const lineOffset = src.slice(0, open).split("\n").length - 1;
const ast = acorn.parse(code, { ecmaVersion: "latest", sourceType: "module", locations: true });

// call name -> how to read it: speaker (fixed id) or speakerArg (index of the speaker argument), kind
const CALLS = {
  speak: { speakerArg: 0, kind: "voice" },
  showBark: { speakerArg: 1, defaultWho: "sprocket", kind: "bark" },
  ANNOUNCER: { who: "glambot", kind: "voice" },
  shopPitch: { who: "blartz", kind: "voice" },
  showBanner: { who: "banner", kind: "ui" },
  bossStart: { who: "banner", kind: "ui" },
  arenaEnd: { who: "banner", kind: "ui" },
  showHint: { who: "hint", kind: "ui" },
  zFeed: { who: "zonga_feed", kind: "ui" },
  tagline: { who: "loop_riot", kind: "ui" },
  textSign: { who: "sign", kind: "world", onlyArg: 0 },
  signBoard: { who: "sign", kind: "world" },
  addCheckpoint: { who: "sign", kind: "world", onlyArg: 3 },
  spawnDenizen: { speakerArg: 2, kind: "bark", onlyArg: 4 },   // ambient residents (who = denizen kind)
};
const WHO_BY_NAME = { "SPROCKET": "sprocket", "SUPER SPROCKET": "sprocket", "GLAMBOT PRIME": "glambot", "BLARTZ": "blartz", "BOLT": "bolt" };

const text = (n) => {
  if (n.type === "Literal" && typeof n.value === "string") return n.value;
  if (n.type === "TemplateLiteral")
    return n.quasis.map((q, i) => q.value.cooked + (i < n.expressions.length ? "{" + code.slice(n.expressions[i].start, n.expressions[i].end) + "}" : "")).join("");
  return null;
};
// every string inside an argument (arrays of alternatives, ternaries, concatenations)
const strings = (n, acc = []) => {
  if (!n || typeof n.type !== "string") return acc;
  const t = text(n);
  if (t !== null) { if (/[A-Za-z]{2}/.test(t)) acc.push(t); return acc; }
  if (["ArrowFunctionExpression", "FunctionExpression"].includes(n.type)) return acc;
  for (const k in n) {
    const v = n[k];
    if (k === "loc") continue;
    if (Array.isArray(v)) v.forEach((x) => strings(x, acc)); else if (v && typeof v.type === "string") strings(v, acc);
  }
  return acc;
};

const out = [];
const perFn = Object.create(null);
(function walk(n, fn) {
  if (!n || typeof n.type !== "string") return;
  let here = fn;
  if (n.type === "FunctionDeclaration" && n.id) here = n.id.name;
  if (n.type === "VariableDeclarator" && n.id.type === "Identifier" && n.init && /Function/.test(n.init.type)) here = n.id.name;
  if (n.type === "MethodDefinition" || (n.type === "Property" && /Function/.test(n.value?.type))) here = (n.key.name || n.key.value || here);
  if (n.type === "CallExpression") {
    const name = n.callee.type === "Identifier" ? n.callee.name : n.callee.property?.name;
    const spec = Object.hasOwn(CALLS, name) ? CALLS[name] : null;
    if (spec) {
      let who = spec.who || spec.defaultWho;
      const args = n.arguments.slice();
      if (spec.speakerArg !== undefined && args[spec.speakerArg]) {
        const w = text(args[spec.speakerArg]);
        if (w) who = WHO_BY_NAME[w] || w.toLowerCase();
        args.splice(spec.speakerArg, 1);
      }
      const use = spec.onlyArg !== undefined ? (n.arguments[spec.onlyArg] ? [n.arguments[spec.onlyArg]] : []) : args;
      for (const a of use) {
        for (const t of strings(a)) {
          const key = here || "top";
          perFn[key] = (perFn[key] || 0) + 1;
          out.push({ id: `code.${key}.${String(perFn[key]).padStart(2, "0")}`, who: who || "ui", kind: spec.kind, call: name,
            text: t, src_line: n.loc.start.line + lineOffset });
        }
      }
    }
  }
  for (const k in n) {
    const v = n[k];
    if (k === "loc") continue;
    if (Array.isArray(v)) v.forEach((x) => walk(x, here)); else if (v && typeof v.type === "string") walk(v, here);
  }
})(ast, null);

fs.writeFileSync(path.join(root, "data/bs/story/code_lines.json"), JSON.stringify(out, null, 2));
const by = Object.create(null);
for (const l of out) by[l.call] = (by[l.call] || 0) + 1;
console.log(`extracted ${out.length} code-spoken lines:`, JSON.stringify(by));
