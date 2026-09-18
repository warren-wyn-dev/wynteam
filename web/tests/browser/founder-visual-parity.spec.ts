import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = join(process.cwd());
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("approved Founder Home mockup geometry cannot drift", () => {
  const layout = read("app/layout.tsx");
  const home = read("app/home.css");
  const lock = read("app/founder-parity-lock.css");
  const card = read("components/home/home-post-card.tsx");
  const actions = read("components/home/post-actions.tsx");
  const tabs = read("components/home/home-tabs.tsx");
  const author = read("components/home/post-author-row.tsx");

  expect(layout).toContain('import "./home.css";');
  expect(layout).toContain('import "./founder-parity-lock.css";');
  expect(layout.lastIndexOf('import "./home.css";')).toBeGreaterThan(
    layout.lastIndexOf('import "./founder-parity-lock.css";'),
  );

  expect(home).toContain("height: 44px");
  expect(home).toContain("grid-template-columns: 40px minmax(0, 1fr)");
  expect(home).toContain("column-gap: 14px");
  expect(home).toContain("padding: 14px 16px 0");
  expect(home).toContain("margin-top: 2px");
  expect(home).toContain("margin: 0 0 3px 25px");
  expect(home).toContain("grid-column: 2");
  expect(home).toContain("transform: none");
  expect(home).toContain("margin: 6px 0 0");
  expect(home).toContain("calc((100% - 16px) * 0.82)");
  expect(home).toContain("text-decoration: none !important");
  expect(home).toContain("background: #efeff1");
  expect(home).toContain(".wyn-post-follow-pill.is-following");
  expect(home).toContain("width: 120px");
  expect(home).toContain("padding-top: min(env(safe-area-inset-top), 47px);");
  expect(home).toContain(".wyn-action-save");
  expect(tabs).toContain("wyn-home-tab-indicator");
  expect(tabs).not.toContain('background: active ? "var(--wyn-surface)"');
  expect(author).toContain('"กำลังติดตาม"');
  expect(lock).toContain("color: #1d9bf0");

  expect(card).toContain('size={40}');
  expect(card).toContain("viewer.savedDropIds.has(row.id)");
  expect(card).toContain("<RichPostText");
  expect(card).toContain("รีโพสต์โดย {row.redropper_username");
  expect(actions).toContain("<Bookmark");
});

test("post detail keeps the Founder activity and text contract", () => {
  const detail = read("components/post-detail-route.tsx");
  expect(detail).toContain('className="detail-caption"');
  expect(detail).toContain("<RichPostText");
  expect(detail).toContain('type ActivityTab = "likes" | "redrops";');
  expect(detail).toContain("กิจกรรมโพสต์");
});
