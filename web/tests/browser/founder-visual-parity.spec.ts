import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = join(process.cwd());
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("founder-approved Home geometry and rich post text cannot drift", () => {
  const layout = read("app/layout.tsx");
  const lock = read("app/founder-parity-lock.css");
  const home = read("components/parity-home-final.tsx");
  const card = read("components/golden-drop-card.tsx");

  expect(layout.trimEnd()).toContain('import "./founder-parity-lock.css";');
  expect(layout.lastIndexOf('import "./founder-parity-lock.css";')).toBeGreaterThan(
    layout.lastIndexOf('import "./club-post-card-web.css";'),
  );

  // Approved post anatomy: avatar/author same row, caption under the author,
  // media + interaction row spanning the full post width.
  expect(lock).toContain("display: grid !important");
  expect(lock).toContain("grid-template-columns: 44px minmax(0, 1fr)");
  expect(lock).toContain("column-gap: 8px");
  expect(lock).toContain(".audit-feed-post > .post-content");
  expect(lock).toContain("display: contents");
  expect(lock).toContain("grid-column: 2");
  expect(lock).toContain("grid-column: 1 / -1");
  expect(lock).toContain("padding: 8px 16px 8px");
  expect(lock).toContain("text-decoration: none !important");
  expect(lock).toContain("color: #1d9bf0");
  expect(lock).toContain("flex: 0 0 82%");

  expect(home).toContain('size={44}');
  expect(home).toContain("<RichPostText");
  expect(card).toContain("<RichPostText");
});

test("post detail keeps the shared founder text treatment", () => {
  const detail = read("components/post-detail-route.tsx");
  expect(detail).toContain('className="detail-caption"');
  expect(detail).toContain("<RichPostText");
  expect(detail).toContain('type ActivityTab = "likes" | "redrops";');
  expect(detail).toContain("กิจกรรมโพสต์");
});
