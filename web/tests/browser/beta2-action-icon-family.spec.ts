import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const read = (file: string) => readFileSync(path.join(process.cwd(), file), "utf8");

test("WYNOS Outline Clean action icons share one rounded visual language", () => {
  const heart = read("components/ui/animated-heart.tsx");
  const icons = read("components/ui/post-action-icons.tsx");
  const share = read("components/ui/wynos-share-icon.tsx");

  expect(heart).toContain("M12 20.45c-.25 0-.5-.08-.7-.23");
  expect(heart).toContain('strokeLinecap="round"');
  expect(heart).toContain('strokeLinejoin="round"');

  expect(icons).toContain("M12 3.6c5.02 0 9 3.48 9 7.8s-3.98 7.8-9 7.8");
  expect(icons).toContain("M7.8 18.15c-.42 1.08-1.18 1.85-2.3 2.3");
  expect(icons).not.toContain("L3 21");
  expect(icons).not.toContain("1.9-5.7");

  expect(icons).toContain("M4.4 9V7.9A2.9 2.9 0 0 1 7.3 5h10.4");
  expect(icons).toContain("M19.6 15v1.1A2.9 2.9 0 0 1 16.7 19H6.3");
  expect(icons).not.toContain("M3 12a9 9");

  expect(icons).toContain("M7.5 3.25h9c1.1 0 2 .9 2 2v14.9");
  expect(icons).toContain('fill={saved ? "currentColor" : "none"}');

  expect(share).toContain("M12 15.5V3.5");
  expect(share).toContain("M4.75 11.75v7.1");
});

test("Outline Clean preserves the approved Feed action sizes and hit targets", () => {
  const actions = read("components/home/post-actions.tsx");
  const beta2 = read("app/beta2-home-polish.css");
  const home = read("app/home.css");

  expect(actions).toContain("<AnimatedHeart size={22} strokeWidth={2} liked={liked} />");
  expect(actions).toContain("<CommentIcon size={24} strokeWidth={2} />");
  expect(actions).toContain("<RepostIcon size={22} strokeWidth={2} />");
  expect(actions).toContain("<WynosShareIcon size={22} />");
  expect(actions).toContain("<AnimatedBookmark size={22} strokeWidth={2} saved={saved} />");

  expect(beta2).toContain("stroke-width: 1.75;");
  expect(home).toMatch(/\.wyn-action-save \{[\s\S]*?margin-left: auto;/);
  expect(home).toMatch(/\.wyn-action-button::before \{[\s\S]*?height: 44px;/);
});
