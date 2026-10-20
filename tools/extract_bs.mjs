// Extracts every top-level data table from the Bolt & Sprocket web build into /data/bs_source/*.json.
// Usage: node tools/extract_bs.mjs [path/to/index.html]   (default: reference/bs_web/index.html)
// Parses the <script type="module"> block with acorn, walks top-level const/let/var declarations, and
// statically evaluates literal initialisers (objects, arrays, strings, numbers, template strings, simple
// arithmetic, spreads and references to other already-extracted tables). Functions are replaced by
// {"__fn__": "<name or arrow>", "__src__": "<first 160 chars>"} so behaviour can be described in prose.
// Writes data/bs_source/_report.json (what was extracted, what was skipped and why).
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as acorn from "./node_modules/acorn/dist/acorn.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const src = fs.readFileSync(process.argv[2] || path.join(root, "reference/bs_web/index.html"), "utf8");
const outDir = path.join(root, "data/bs_source");
fs.mkdirSync(outDir, { recursive: true });

const open = src.indexOf('<script type="module">');
const close = src.indexOf("</script>", open);
const code = src.slice(open + '<script type="module">'.length, close);
const ast = acorn.parse(code, { ecmaVersion: "latest", sourceType: "module", locations: true });

let lenient = false;            // pass 3: unresolved refs/calls become {__ref__}/{__call__} stubs
const env = new Map();          // name -> evaluated value (for references between tables)
const report = { extracted: {}, skipped: {}, functions: [] };
class Unsupported extends Error {}

function ev(n) {
  switch (n.type) {
    case "Literal": return n.regex ? { __regex__: n.raw } : n.value;
    case "TemplateLiteral":
      return n.quasis.map((q, i) => q.value.cooked + (i < n.expressions.length ? tpl(n.expressions[i]) : "")).join("");
    case "ArrayExpression": {
      const out = [];
      for (const e of n.elements) {
        if (e === null) out.push(null);
        else if (e.type === "SpreadElement") out.push(...asArray(ev(e.argument)));
        else out.push(ev(e));
      }
      return out;
    }
    case "ObjectExpression": {
      const o = {};
      for (const p of n.properties) {
        if (p.type === "SpreadElement") { Object.assign(o, ev(p.argument)); continue; }
        const k = p.computed ? String(ev(p.key)) : (p.key.type === "Identifier" ? p.key.name : String(p.key.value));
        o[k] = p.value.type.includes("Function") ? fnStub(p.value, k) : ev(p.value);
      }
      return o;
    }
    case "UnaryExpression": {
      const v = ev(n.argument);
      if (n.operator === "-") return -v;
      if (n.operator === "+") return +v;
      if (n.operator === "!") return !v;
      if (n.operator === "void") return null;
      throw new Unsupported("unary " + n.operator);
    }
    case "BinaryExpression": {
      const a = ev(n.left), b = ev(n.right);
      switch (n.operator) {
        case "+": return a + b; case "-": return a - b; case "*": return a * b; case "/": return a / b;
        case "%": return a % b; case "**": return a ** b; case "|": return a | b; case "&": return a & b;
        case "<<": return a << b; case ">>": return a >> b;
      }
      throw new Unsupported("binary " + n.operator);
    }
    case "ConditionalExpression":
      if (lenient) return { __expr__: code.slice(n.start, n.end).replace(/\s+/g, " ").slice(0, 160) };
      throw new Unsupported("conditional");
    case "Identifier":
      if (n.name === "undefined") return null;
      if (n.name === "Infinity") return 1e308;
      if (env.has(n.name)) return env.get(n.name);
      if (lenient) return { __ref__: n.name };
      throw new Unsupported("ref " + n.name);
    case "MemberExpression": {
      if (n.object.type === "Identifier" && n.object.name === "Math") {
        const k = n.property.name; if (k in Math) return Math[k];
      }
      const o = ev(n.object);
      const k = n.computed ? ev(n.property) : n.property.name;
      if (o != null && k in Object(o)) return o[k];
      if (lenient) return { __expr__: code.slice(n.start, n.end).replace(/\s+/g, " ").slice(0, 160) };
      throw new Unsupported("member");
    }
    case "CallExpression": {
      // Math.x(...) with literal args, and Object.freeze(x)
      const c = n.callee;
      if (c.type === "MemberExpression" && c.object.name === "Math" && typeof Math[c.property.name] === "function")
        return Math[c.property.name](...n.arguments.map(ev));
      if (c.type === "MemberExpression" && c.object.name === "Object" && c.property.name === "freeze") return ev(n.arguments[0]);
      if (lenient) return { __call__: code.slice(n.start, n.end).replace(/\s+/g, " ").slice(0, 160) };
      throw new Unsupported("call");
    }
    case "ArrowFunctionExpression": case "FunctionExpression": return fnStub(n);
    case "NewExpression":
      if (n.callee.name === "Set" || n.callee.name === "Map") return n.arguments.length ? ev(n.arguments[0]) : [];
      throw new Unsupported("new " + (n.callee.name || "?"));
    case "ParenthesizedExpression": return ev(n.expression);
  }
  throw new Unsupported(n.type);
}
function tpl(e) { try { return String(ev(e)); } catch { return "${" + code.slice(e.start, e.end) + "}"; } }
function asArray(v) { return Array.isArray(v) ? v : Object.values(v); }
function fnStub(n, name) {
  const s = code.slice(n.start, n.end).replace(/\s+/g, " ");
  return { __fn__: name || "anonymous", __src__: s.slice(0, 160) };
}

const decls = [];
for (const st of ast.body) {
  const d = st.type === "ExportNamedDeclaration" ? st.declaration : st;
  if (d && d.type === "VariableDeclaration") for (const v of d.declarations) decls.push(v);
  if (d && d.type === "FunctionDeclaration") report.functions.push({ name: d.id.name, line: d.loc.start.line + 700 });
}
// Nested tables (e.g. Loop Riot's, declared inside its mode function) are collected too.
const topLevel = new Set(decls);
(function walk(n) {
  if (!n || typeof n.type !== "string") return;
  if (n.type === "VariableDeclarator" && !topLevel.has(n) && n.id.type === "Identifier" && /^[A-Z][A-Z0-9_]{2,}$/.test(n.id.name)) decls.push(n);
  for (const k in n) {
    const v = n[k];
    if (Array.isArray(v)) v.forEach(walk); else if (v && typeof v.type === "string" && k !== "loc") walk(v);
  }
})(ast);
// Passes 1-2 strict (so references between tables resolve), pass 3 lenient (stubs for code references).
for (let pass = 0; pass < 3; pass++) {
  lenient = pass === 2;
  for (const v of decls) {
    if (!v.init || v.id.type !== "Identifier") continue;
    const name = v.id.name;
    if (env.has(name)) continue;
    const t = v.init.type;
    if (!["ObjectExpression", "ArrayExpression", "Literal", "TemplateLiteral", "UnaryExpression", "BinaryExpression", "CallExpression", "NewExpression", "Identifier", "MemberExpression"].includes(t)) continue;
    try {
      const val = ev(v.init);
      env.set(name, val);
      delete report.skipped[name];
    } catch (e) {
      report.skipped[name] = { reason: e.message, line: v.loc.start.line + 700, type: t };
    }
  }
}
// Write every object/array table (small scalars go into _scalars.json).
const scalars = {};
for (const [name, val] of env) {
  if (val !== null && typeof val === "object") {
    fs.writeFileSync(path.join(outDir, name + ".json"), JSON.stringify(val, null, 2));
    const count = Array.isArray(val) ? val.length : Object.keys(val).length;
    report.extracted[name] = { entries: count, bytes: JSON.stringify(val).length };
  } else scalars[name] = val;
}
fs.writeFileSync(path.join(outDir, "_scalars.json"), JSON.stringify(scalars, null, 2));
fs.writeFileSync(path.join(outDir, "_report.json"), JSON.stringify(report, null, 2));
console.log(`extracted ${Object.keys(report.extracted).length} tables, ${Object.keys(scalars).length} scalars, ` +
  `${Object.keys(report.skipped).length} skipped, ${report.functions.length} top-level functions`);
