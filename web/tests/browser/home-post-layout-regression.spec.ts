import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const css = () => readFileSync(join(root, "app/home.css"), "utf8");

test("Home post keeps the approved avatar/content two-column contract", () => {
  const home = css();
  expect(home).toMatch(/\.wyn-post \{[\s\S]*?display: grid;/);
  expect(home).toContain("grid-template-columns: 44px minmax(0, 1fr)");
  expect(home).toContain("padding: 12px 16px 0");
  expect(home).toMatch(/\.wyn-post-body \{[\s\S]*?grid-column: 2;/);
  expect(home).toMatch(/\.wyn-post-avatar \{[\s\S]*?margin-top: 6px;/);
});

test("caption media and actions remain compact in the right content column", () => {
  const home = css();
  expect(home).toMatch(/\.wyn-post-caption \{[\s\S]*?margin: 3px 0 0;[\s\S]*?transform: none;/);
  expect(home).toMatch(/\.wyn-post-media \{[\s\S]*?margin-top: 6px;/);
  expect(home).toMatch(/\.wyn-post-actions \{[\s\S]*?margin: 4px 0 12px;/);
  expect(home).not.toMatch(/\.wyn-post-media \{[\s\S]{0,160}?grid-column: 1 \/ -1;/);
  expect(home).not.toMatch(/\.wyn-post-actions \{[\s\S]{0,160}?grid-column: 1 \/ -1;/);
});

test("Post author links never fall back to browser underlines", () => {
  const home = css();
  expect(home).toContain("text-decoration: none !important;");
});

test("exactly one canonical stylesheet defines the Home post card (no competing override layer)", () => {
  const layout = readFileSync(join(root, "app/layout.tsx"), "utf8");
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
