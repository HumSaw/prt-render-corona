#!/usr/bin/env node
/*
  Static test harness for the PRT Render - Corona MAXScript suite.
  Checks (per file):
    T1  Balanced parentheses outside strings/comments
    T2  No duplicate local `fn` definitions inside the rollout
    T3  Every local `fn` referenced inside the rollout is defined BEFORE first use
        (MAXScript resolves undeclared names to globals at parse time)
    T4  Every declared UI control is referenced at least twice
        (declaration + at least one use) -> detects dead UI
    T5  Required safety patterns present (stopRequested set by btnStop,
        try/catch guard around the render queue, element-state restore)
    T6  Cross-version consistency: rollout body identical across all files
    T7  Header/createDialog height consistency (no stale "930" claim)
  Exit code 0 = all pass, 1 = failures.
*/
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const dir = join(dirname(fileURLToPath(import.meta.url)), "..");
const files = readdirSync(dir).filter((f) => f.endsWith(".ms")).sort();
let failures = 0;
const fail = (file, test, msg) => {
  failures++;
  console.log(`FAIL [${test}] ${file}: ${msg}`);
};
const pass = (file, test) => console.log(`ok   [${test}] ${file}`);

// Strip strings and comments, preserving line structure.
function stripNoise(src) {
  let out = "";
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === '"') {
      out += '""';
      i++;
      while (i < src.length && src[i] !== '"') {
        if (src[i] === "\\") i++;
        if (src[i] === "\n") out += "\n";
        i++;
      }
      i++;
    } else if (c === "-" && src[i + 1] === "-") {
      while (i < src.length && src[i] !== "\n") i++;
    } else if (c === "/" && src[i + 1] === "*") {
      i += 2;
      while (i < src.length && !(src[i] === "*" && src[i + 1] === "/")) {
        if (src[i] === "\n") out += "\n";
        i++;
      }
      i += 2;
    } else {
      out += c;
      i++;
    }
  }
  return out;
}

const bodies = {};

for (const file of files) {
  const raw = readFileSync(join(dir, file), "utf8");
  const src = stripNoise(raw);

  // T1: balanced parens
  let depth = 0;
  let minDepth = 0;
  for (const ch of src) {
    if (ch === "(") depth++;
    else if (ch === ")") depth--;
    if (depth < minDepth) minDepth = depth;
  }
  if (depth !== 0 || minDepth < 0)
    fail(file, "T1", `unbalanced parens (final depth ${depth}, min ${minDepth})`);
  else pass(file, "T1");

  // Collect fn definitions with their offsets
  const fnDefs = new Map();
  const fnRe = /\bfn\s+([A-Za-z_][A-Za-z0-9_]*)/g;
  let m;
  while ((m = fnRe.exec(src))) {
    if (!fnDefs.has(m[1])) fnDefs.set(m[1], []);
    fnDefs.get(m[1]).push(m.index);
  }

  // T2: duplicates
  let dup = false;
  for (const [name, offs] of fnDefs)
    if (offs.length > 1) {
      dup = true;
      fail(file, "T2", `duplicate fn '${name}' (${offs.length} defs)`);
    }
  if (!dup) pass(file, "T2");

  // T3: defined-before-use for local fns
  let fwd = false;
  for (const [name, offs] of fnDefs) {
    const defOff = offs[0];
    const useRe = new RegExp(`\\b${name}\\b`, "g");
    let u;
    while ((u = useRe.exec(src))) {
      const isDef = offs.some((o) => Math.abs(u.index - o - 3) <= name.length + 4 && u.index > o);
      if (u.index < defOff && !src.slice(Math.max(0, u.index - 4), u.index).includes("fn ")) {
        fwd = true;
        const line = src.slice(0, u.index).split("\n").length;
        fail(file, "T3", `'${name}' used at line ~${line} before definition`);
        break;
      }
      if (isDef) continue;
    }
  }
  if (!fwd) pass(file, "T3");

  // T4: dead UI controls
  const ctrlRe =
    /^\s*(button|pickButton|checkbox|spinner|dropdownList|editText|label|multiListBox|progressBar|radiobuttons|groupBox)\s+([A-Za-z_][A-Za-z0-9_]*)/gm;
  let deadUi = false;
  const decorative = new Set(); // labels/groupBoxes are allowed to be decl-only
  while ((m = ctrlRe.exec(src))) {
    const [, kind, name] = m;
    if (kind === "label" || kind === "groupBox") continue;
    const count = (src.match(new RegExp(`\\b${name}\\b`, "g")) || []).length;
    if (count < 2) {
      deadUi = true;
      fail(file, "T4", `control '${name}' (${kind}) declared but never used`);
    }
  }
  if (!deadUi) pass(file, "T4");

  // T5: safety patterns
  const t5checks = [
    [/on\s+btnStop\s+pressed\s+do[\s\S]{0,400}?stopRequested\s*=\s*true/, "btnStop sets stopRequested"],
    [/fn\s+restoreElementOutputs/, "element-state restore function present"],
    [/renderQueueGuarded|catch[\s\S]{0,200}btnRender\.enabled\s*=\s*true/, "render queue UI-recovery guard"],
  ];
  let t5fail = false;
  for (const [re, desc] of t5checks) {
    if (!re.test(src)) {
      t5fail = true;
      fail(file, "T5", `missing safety pattern: ${desc}`);
    }
  }
  if (!t5fail) pass(file, "T5");

  // T7: stale height comment
  if (/height\s*\(?930\)?|matches the rollout height \(930\)/.test(raw))
    fail(file, "T7", "stale '930' height claim in header");
  else pass(file, "T7");

  // body for T6
  const bodyStart = raw.indexOf("global PRT_Corona_Renderer");
  bodies[file] = raw.slice(bodyStart);
}

// T6: cross-version identical bodies
const ref = bodies[files[0]];
let t6fail = false;
for (const file of files.slice(1)) {
  if (bodies[file] !== ref) {
    t6fail = true;
    const a = ref.split("\n");
    const b = bodies[file].split("\n");
    let firstDiff = -1;
    for (let i = 0; i < Math.max(a.length, b.length); i++)
      if (a[i] !== b[i]) {
        firstDiff = i;
        break;
      }
    fail(file, "T6", `body differs from ${files[0]} starting at body line ${firstDiff + 1}`);
  }
}
if (!t6fail) console.log(`ok   [T6] all ${files.length} bodies identical`);

console.log(failures === 0 ? "\nALL CHECKS PASSED" : `\n${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
