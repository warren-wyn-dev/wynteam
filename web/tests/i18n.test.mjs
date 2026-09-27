// WYN-189: English coverage and translation rules for lib/i18n.
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const root = new URL("..", import.meta.url).pathname;
const read = (path) => readFileSync(join(root, path), "utf8");
function transpile(path, modules = {}) {
  const out = ts.transpileModule(read(path), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const mod = { exports: {} };
  runInNewContext(out, { module: mod, exports: mod.exports, require: (name) => modules[name] });
  return mod.exports;
}
const en = transpile("lib/i18n/en.ts");
const { translateToEnglish } = transpile("lib/i18n/translator.ts", { "@/lib/i18n/en": en });

// Thai in the source that is not UI chrome: demo names, a CSS selector and
// the language picker's own-script name for Thai.
const NOT_UI = new Set(["ต้น", "ต้น สายเทค", "พลอย เดินทาง", "มายด์", "มายด์ กาแฟรัก", 'button[aria-label="เพิ่มเติม"]', "ไทย"]);

/** Every Thai string literal, JSX text and template in the shipped web app. */
function thaiInSource() {
  const THAI = /[฀-๿]/;
  const exact = new Map();
  const patterns = new Map();
  const files = [];
  const walk = (dir) => {
    for (const entry of readdirSync(join(root, dir), { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) {
        if (!/node_modules|(^|\/)dev$|fixture|components\/food|app\/food/.test(path)) walk(path);
      } else if (/\.tsx?$/.test(entry.name) && !/fixture/.test(entry.name) && !path.startsWith("lib/i18n/")) files.push(path);
    }
  };
  ["app", "components", "lib"].forEach(walk);
  const cook = (raw) => raw.split(/\r\n|\n|\r/).map((line, index, lines) => {
    let text = line.replace(/\t/g, " ");
    if (index > 0) text = text.replace(/^ +/, "");
    if (index < lines.length - 1) text = text.replace(/ +$/, "");
    return text;
  }).filter(Boolean).join(" ").replace(/&quot;/g, '"');
  const add = (map, text, file) => {
    text = text.trim();
    if (text && THAI.test(text) && !map.has(text)) map.set(text, file);
  };
  for (const file of files) {
    const src = read(file);
    if (!THAI.test(src)) continue;
    const sf = ts.createSourceFile(file, src, ts.ScriptTarget.Latest, true, file.endsWith("x") ? ts.ScriptKind.TSX : ts.ScriptKind.TS);
    const visit = (node) => {
      if (ts.isJsxText(node)) add(exact, cook(node.text), file);
      else if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) {
        if (!ts.isImportDeclaration(node.parent)) add(exact, node.text, file);
      } else if (ts.isTemplateExpression(node)) {
        let text = node.head.text;
        node.templateSpans.forEach((span, index) => { text += `{${index}}${span.literal.text}`; });
        add(patterns, text, file);
      }
      ts.forEachChild(node, visit);
    };
    visit(sf);
  }
  return { exact, patterns };
}

test("every Thai UI string in the web app has English (add it to lib/i18n/en.ts)", () => {
  const { exact, patterns } = thaiInSource();
  const known = new Set(en.EN_PATTERNS.map(([thai]) => thai));
  const missing = [
    ...[...exact].filter(([text]) => !NOT_UI.has(text) && !(text in en.EN_EXACT)).map(([text, file]) => `${file}: ${JSON.stringify(text)}`),
    ...[...patterns].filter(([text]) => !known.has(text)).map(([text, file]) => `${file}: template ${JSON.stringify(text)}`),
  ];
  assert.deepEqual(missing, []);
});

test("English templates keep every inserted value", () => {
  for (const [thai, english] of en.EN_PATTERNS) {
    const slots = (text) => [...text.matchAll(/\{\d+\}/g)].map((m) => m[0]).sort().join();
    assert.equal(slots(english), slots(thai), thai);
  }
});

test("exact strings, templates and whitespace", () => {
  assert.equal(translateToEnglish("กำลังโหลด…"), "Loading…");
  assert.equal(translateToEnglish("  ติดตาม "), "  Follow ");
  assert.equal(translateToEnglish("5 ชม."), "5h");
  assert.equal(translateToEnglish("น้ำฝน ถูกใจโพสต์ของคุณใน Coffee"), "น้ำฝน liked your post in Coffee");
  assert.equal(translateToEnglish("รูป 2 จาก 4"), "Photo 2 of 4");
});

test("a fragment after an inserted value reads in lower case", () => {
  assert.equal(translateToEnglish(" สมาชิก"), " members");
  assert.equal(translateToEnglish("สมาชิก"), "Members");
});

test("Thai dates become English dates", () => {
  assert.equal(translateToEnglish("26 ก.ย."), "Sep 26");
  assert.equal(translateToEnglish("26 กันยายน 2026"), "September 26, 2026");
  assert.equal(translateToEnglish("1 ม.ค. 2570"), "Jan 1, 2027");
});

test("people's own text and non-Thai text are left alone", () => {
  assert.equal(translateToEnglish("วันนี้ไปกินข้าวที่ไหนดี"), null);
  assert.equal(translateToEnglish("hello"), null);
  assert.equal(translateToEnglish(""), null);
});

test("the language boot script only hides the page for English", () => {
  const { LANGUAGE_BOOT_SCRIPT } = transpile("lib/i18n/language.ts");
  const run = (stored, languages) => {
    const attrs = new Map();
    const documentElement = { lang: "th", setAttribute: (k, v) => attrs.set(k, v), removeAttribute: (k) => attrs.delete(k) };
    runInNewContext(LANGUAGE_BOOT_SCRIPT, {
      localStorage: { getItem: () => stored },
      navigator: { languages, language: languages[0] },
      document: { documentElement },
      setTimeout: () => 0,
    });
    return { lang: documentElement.lang, pending: attrs.has("data-i18n-pending") };
  };
  assert.deepEqual(run(null, ["th-TH"]), { lang: "th", pending: false });
  assert.deepEqual(run(null, ["en-US"]), { lang: "en", pending: true });
  assert.deepEqual(run("th", ["en-US"]), { lang: "th", pending: false });
  assert.deepEqual(run("en", ["th-TH"]), { lang: "en", pending: true });
});
