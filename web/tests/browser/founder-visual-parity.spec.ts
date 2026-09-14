import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = join(process.cwd());
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("current Flutter HomeDropCard geometry cannot drift", () => {
  const layout = read("app/layout.tsx");
  const home = read("app/home.css");
  const lock = read("app/founder-parity-lock.css");
  const card = read("components/home/home-post-card.tsx");

  expect(layout).toContain('import "./home.css";');
  expect(layout).toContain('import "./founder-parity-lock.css";');
  expect(layout.lastIndexOf('import "./home.css";')).toBeGreaterThan(
    layout.lastIndexOf('import "./founder-parity-lock.css";'),
  );

  // app/lib/features/home/presentation/widgets/home_card_metrics.dart:
  // edge 16, avatar 44, avatarTop 16, avatar/content gap 8, content x=68,
  // outer vertical rhythm 3 and a 3px caption paint lift.
  expect(home).toContain("grid-template-columns: 44px minmax(0, 1fr)");
  expect(home).toContain("column-gap: 8px");
  expect(home).toContain("padding: 3px 0 3px 16px");
  expect(home).toContain("margin-top: 16px");
  expect(home).toContain("grid-column: 2");
  expect(home).toContain("transform: translateY(-3px)");
  expect(home).toContain("margin: 0 16px 0 0");
  expect(home).toContain("calc((100% - 16px) * 0.82)");
  expect(home).toContain("text-decoration: none !important");
  expect(lock).toContain("color: #1d9bf0");

  expect(card).toContain('size={44}');
  expect(card).toContain("<RichPostText");
});

test("post detail keeps the Founder activity and text contract", () => {
  const detail = read("components/post-detail-route.tsx");
  expect(detail).toContain('className="detail-caption"');
  expect(detail).toContain("<RichPostText");
  expect(detail).toContain('type ActivityTab = "likes" | "redrops";');
  expect(detail).toContain("กิจกรรมโพสต์");
});
