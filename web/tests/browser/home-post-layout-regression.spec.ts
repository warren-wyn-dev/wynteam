import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const css = () => readFileSync(join(root, "app/home.css"), "utf8");

test("Home post keeps the Flutter avatar/content two-column contract", () => {
  const home = css();
  expect(home).toMatch(/\.wyn-post \{[\s\S]*?display: grid;/);
  expect(home).toContain("grid-template-columns: 44px minmax(0, 1fr)");
  expect(home).toContain("padding: 3px 0 3px 16px");
  expect(home).toMatch(/\.wyn-post-body \{[\s\S]*?grid-column: 2;/);
  expect(home).toMatch(/\.wyn-post-avatar \{[\s\S]*?margin-top: 16px;/);
});

test("caption media and actions remain in the right content column", () => {
  const home = css();
  expect(home).toMatch(/\.wyn-post-caption \{[\s\S]*?margin: 0 16px 0 0;[\s\S]*?translateY\(-3px\)/);
  expect(home).toMatch(/\.wyn-post-media \{[\s\S]*?margin-top: 0;/);
  expect(home).toMatch(/\.wyn-post-actions \{[\s\S]*?margin: 0 16px 0 0;/);
  expect(home).not.toMatch(/\.wyn-post-media \{[\s\S]{0,160}?grid-column: 1 \/ -1;/);
  expect(home).not.toMatch(/\.wyn-post-actions \{[\s\S]{0,160}?grid-column: 1 \/ -1;/);
});

test("Post author links never fall back to browser underlines", () => {
  const home = css();
  expect(home).toContain("text-decoration: none !important;");
});

test("exactly one canonical stylesheet defines the Home post card (no competing override layer)", () => {
  const layout = readFileSync(join(root, "app/layout.tsx"), "utf8");
  // WYN-158: Home's card geometry used to be redefined across founder-
  // parity-lock/home-golden-final/parity-audit/pixel-parity-final/
  // system-parity-lock (5 files) with slightly different values each
  // time. app/home.css is now the only file allowed to define
  // `.wyn-post`; a second definition anywhere is the same drift risk
  // this test exists to catch.
  const otherCssFiles = [
    "founder-parity-lock.css",
    "parity-audit.css",
    "pixel-parity-final.css",
    "system-parity-lock.css",
    "system-parity-final.css",
    "parity-final.css",
    "phase2.css",
    "phase3.css",
  ];
  for (const file of otherCssFiles) {
    const content = readFileSync(join(root, "app", file), "utf8");
    expect(content, `${file} must not redefine .wyn-post`).not.toContain(".wyn-post ");
    expect(content, `${file} must not redefine .wyn-post {`).not.toContain(".wyn-post {");
  }
  expect(layout).toContain('import "./home.css";');
});
