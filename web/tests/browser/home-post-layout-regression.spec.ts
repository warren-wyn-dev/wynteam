import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const css = () => readFileSync(join(root, "app/founder-parity-lock.css"), "utf8");

test("Home post keeps the Flutter avatar/content two-column contract", () => {
  const lock = css();
  expect(lock).toContain(".parity-feed-post.audit-feed-post {\n  display: grid !important;");
  expect(lock).toContain("grid-template-columns: 44px minmax(0, 1fr)");
  expect(lock).toContain("padding: 3px 0 3px 16px");
  expect(lock).toContain(".audit-feed-post > .post-content {\n  grid-column: 2;");
  expect(lock).toContain("display: block;");
  expect(lock).toMatch(/\.parity-feed-post\.audit-feed-post > \.avatar-button \{[\s\S]*?margin-top: 16px;/);
});

test("caption media and actions remain in the right content column", () => {
  const lock = css();
  expect(lock).toMatch(/\.audit-feed-post \.audit-caption \{[\s\S]*?margin: 0 16px 0 0;[\s\S]*?translateY\(-3px\)/);
  expect(lock).toMatch(/\.audit-feed-post \.audit-media-wrap,[\s\S]*?margin-top: 0;/);
  expect(lock).toMatch(/\.audit-feed-post \.audit-action-row \{[\s\S]*?margin: 0 16px 0 0;/);
  expect(lock).not.toMatch(/\.audit-feed-post \.audit-media-wrap,[\s\S]{0,160}?grid-column: 1 \/ -1;/);
  expect(lock).not.toMatch(/\.audit-feed-post \.audit-action-row \{[\s\S]{0,160}?grid-column: 1 \/ -1;/);
});

test("Post author links never fall back to browser underlines", () => {
  const lock = css();
  expect(lock).toContain("text-decoration: none !important;");
});
