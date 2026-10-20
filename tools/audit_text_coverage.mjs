// Coverage audit: lists every sentence-like string literal in the web build's script that is NOT present in
// any ported file under data/bs/story/. Run after extract_bs / extract_code_lines / port_story.
// Strings already in the raw tables (data/bs_source) count as covered. --emit writes everything else to
// data/bs/story/code_misc.json (id "misc.<enclosing function>.<nn>") so no player-facing text is lost.
// Usage: node tools/audit_text_coverage.mjs [--all] [--emit]
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as acorn from "./node_modules/acorn/dist/acorn.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const src = fs.readFileSync(path.join(root, "reference/bs_web/index.html"), "utf8");
const open = src.indexOf('<script type="module">');
const code = src.slice(open + 22, src.indexOf("</script>", open));
const off = src.slice(0, open).split("\n").length - 1;
const ast = acorn.parse(code, { ecmaVersion: "latest", sourceType: "module", locations: true });
const dir = path.join(root, "data/bs/story");
const blob = fs.readdirSync(dir).map((f) => fs.readFileSync(path.join(dir, f), "utf8")).join("\n");
const seen = new Set();
const missing = [];
const perFn = Object.create(null);
(function w(n, fn) {
  if (!n || typeof n.type !== "string") return;
  if (n.type === "FunctionDeclaration" && n.id) fn = n.id.name;
  if (n.type === "VariableDeclarator" && n.id.type === "Identifier" && n.init && /Function/.test(n.init.type)) fn = n.id.name;
  let t = null;
  if (n.type === "Literal" && typeof n.value === "string") t = n.value;
  if (n.type === "TemplateLiteral" && n.expressions.length === 0) t = n.quasis[0].value.cooked;
  // sentence-like: has a space, some lowercase words, isn't CSS/HTML/code
  if (t && t.length >= 14 && / [a-z]{2,}/.test(t) && !/[{};<>]|^\s*[#.]|px|rgba?\(|=>|function|\bvar\(/.test(t) && !seen.has(t)) {
    seen.add(t);
    if (!blob.includes(JSON.stringify(t).slice(1, -1))) {
      const key = fn || "top";
      perFn[key] = (perFn[key] || 0) + 1;
      missing.push({ id: `misc.${key}.${String(perFn[key]).padStart(2, "0")}`, line: n.loc.start.line + off, text: t });
    }
  }
  for (const k in n) {
    if (k === "loc") continue;
    const v = n[k];
    if (Array.isArray(v)) v.forEach((x) => w(x, fn)); else if (v && typeof v.type === "string") w(v, fn);
  }
})(ast, null);
if (process.argv.includes("--emit")) {
  fs.writeFileSync(path.join(dir, "code_misc.json"), JSON.stringify(missing.map((m) => ({ id: m.id, who: "ui", kind: "misc", text: m.text, src_line: m.line })), null, 2));
  console.log("wrote data/bs/story/code_misc.json");
}
console.log(`sentence-like literals: ${seen.size}, not yet ported: ${missing.length}`);
for (const m of missing.slice(0, process.argv.includes("--all") ? 1e9 : 40)) console.log(`  ${m.id} L${m.line}: ${m.text.slice(0, 110)}`);
