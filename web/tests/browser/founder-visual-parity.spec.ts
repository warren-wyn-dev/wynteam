import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = join(process.cwd());
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("current Flutter HomeDropCard geometry cannot drift", () => {
  const layout = read("app/layout.tsx");
  const lock = read("app/founder-parity-lock.css");
  const home = read("components/parity-home-final.tsx");
  const card = read("components/golden-drop-card.tsx");

  expect(layout).toContain('import "./founder-parity-lock.css";');
  expect(layout).toContain('import "./system-parity-lock.css";');
  expect(layout.lastIndexOf('import "./system-parity-lock.css";')).toBeGreaterThan(
    layout.lastIndexOf('import "./founder-parity-lock.css";'),
  );

  // app/lib/features/home/presentation/widgets/home_card_metrics.dart:
  // edge 16, avatar 44, avatarTop 16, avatar/content gap 8, content x=68,
  // outer vertical rhythm 3 and a 3px caption paint lift.
  expect(lock).toContain("grid-template-columns: 44px minmax(0, 1fr)");
  expect(lock).toContain("column-gap: 8px");
  expect(lock).toContain("padding: 3px 0 3px 16px");
  expect(lock).toContain("margin-top: 16px");
  expect(lock).toContain("grid-column: 2");
  expect(lock).toContain("display: block");
  expect(lock).toContain("transform: translateY(-3px)");
  expect(lock).toContain("margin-right: 16px");
  expect(lock).toContain("calc((100% - 16px) * 0.82)");
  expect(lock).toContain("text-decoration: none !important");
  expect(lock).toContain("color: #1d9bf0");

  expect(home).toContain('size={44}');
  expect(home).toContain("<RichPostText");
  expect(card).toContain("<RichPostText");
});

test("post detail keeps the Founder activity and text contract", () => {
  const detail = read("components/post-detail-route.tsx");
  expect(detail).toContain('className="detail-caption"');
  expect(detail).toContain("<RichPostText");
  expect(detail).toContain('type ActivityTab = "likes" | "redrops";');
  expect(detail).toContain("กิจกรรมโพสต์");
});
