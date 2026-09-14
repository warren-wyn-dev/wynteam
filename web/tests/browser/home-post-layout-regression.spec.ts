import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const css = () => readFileSync(join(root, "app/founder-parity-lock.css"), "utf8");

test("Home post keeps avatar and author in one grid row", () => {
  const lock = css();
  expect(lock).toContain(".parity-feed-post.audit-feed-post {\n  display: grid !important;");
  expect(lock).toContain(".audit-feed-post > .post-content {\n  display: contents;");
  expect(lock).toContain(".parity-feed-post.audit-feed-post > .avatar-button {\n  grid-column: 1;");
  expect(lock).toContain(".audit-feed-post .post-header.audit-author-row");
  expect(lock).toContain("grid-column: 2;");
});

test("Home caption stays under author while media and actions span the card", () => {
  const lock = css();
  expect(lock).toMatch(/\.audit-feed-post \.audit-caption \{[\s\S]*?grid-column: 2;/);
  expect(lock).toMatch(/\.audit-feed-post \.audit-media-wrap,[\s\S]*?grid-column: 1 \/ -1;/);
  expect(lock).toMatch(/\.audit-feed-post \.audit-action-row \{[\s\S]*?grid-column: 1 \/ -1;/);
});

test("Post author links never fall back to browser underlines", () => {
  const lock = css();
  expect(lock).toContain("text-decoration: none !important;");
});
