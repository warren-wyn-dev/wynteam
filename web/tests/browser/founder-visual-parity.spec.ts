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
  expect(lock).toContain("grid-template-columns: 44px minmax(0, 1fr)");
  expect(lock).toContain("column-gap: 8px");
  expect(lock).toContain("padding: 3px 0 3px 16px");
  expect(lock).toContain("margin-top: 16px");
  expect(lock).toContain("transform: translateY(-3px)");
  expect(lock).toContain("color: #1d9bf0");
  expect(lock).toContain("calc((100% - 16px) * 0.82)");
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
