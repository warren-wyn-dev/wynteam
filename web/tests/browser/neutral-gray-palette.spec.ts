import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";

const root = process.cwd();
const css = (name: string) => readFile(path.join(root, "app", name), "utf8");

test("light mode uses white, neutral gray and neutral black across shared surfaces", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "light" });
  const styles = await Promise.all([
    "globals.css", "phase3.css", "parity-completion.css", "parity-closure.css",
    "golden-drop-card.css", "design-system.css", "drawer-v2.css", "skeleton.css",
  ].map(css));
  await page.setContent(
    "<style>" + styles.join("\n") + "</style>" +
    '<div class="flutter-search-header"><div class="search-route-form"></div></div>' +
    '<aside class="wynos-drawer-v2"><div class="drawer-menu-row"><span class="drawer-menu-icon"></span></div></aside>' +
    '<button class="recommendation-follow soft">กำลังติดตาม</button>' +
    '<div class="wyn-skeleton"></div><span class="golden-drop-avatar"></span>'
  );
  const actual = await page.evaluate(() => {
    const root = getComputedStyle(document.documentElement);
    const bg = (selector: string) => getComputedStyle(document.querySelector(selector)!).backgroundColor;
    return {
      paper: root.getPropertyValue("--paper").trim(),
      ink: root.getPropertyValue("--ink").trim(),
      graphite: root.getPropertyValue("--graphite").trim(),
      hairline: root.getPropertyValue("--hairline").trim(),
      surface: root.getPropertyValue("--surface").trim(),
      wynSurface: root.getPropertyValue("--wyn-surface").trim(),
      search: bg(".flutter-search-header .search-route-form"),
      drawerIcon: bg(".wynos-drawer-v2 .drawer-menu-icon"),
      following: bg(".recommendation-follow.soft"),
      skeleton: bg(".wyn-skeleton"),
      mediaFallback: bg(".golden-drop-avatar"),
    };
  });
  expect(actual).toEqual({
    paper: "#ffffff", ink: "#171717", graphite: "#737373", hairline: "#e5e5e5",
    surface: "#f5f5f5", wynSurface: "#f5f5f5",
    search: "rgb(245, 245, 245)", drawerIcon: "rgb(245, 245, 245)",
    following: "rgb(245, 245, 245)", skeleton: "rgb(245, 245, 245)",
    mediaFallback: "rgb(245, 245, 245)",
  });
});

test("dark mode uses neutral black and charcoal without a warm cast", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "dark" });
  const styles = await Promise.all(["globals.css", "design-system.css", "parity-completion.css", "skeleton.css"].map(css));
  await page.setContent("<style>" + styles.join("\n") + "</style>" +
    '<div class="flutter-search-header"><div class="search-route-form"></div></div><div class="wyn-skeleton"></div>');
  const actual = await page.evaluate(() => {
    const root = getComputedStyle(document.documentElement);
    return {
      paper: root.getPropertyValue("--paper").trim(),
      ink: root.getPropertyValue("--ink").trim(),
      graphite: root.getPropertyValue("--graphite").trim(),
      wynSecondary: root.getPropertyValue("--wyn-text-secondary").trim(),
      surface: root.getPropertyValue("--surface").trim(),
      search: getComputedStyle(document.querySelector(".search-route-form")!).backgroundColor,
      skeleton: getComputedStyle(document.querySelector(".wyn-skeleton")!).backgroundColor,
    };
  });
  expect(actual).toEqual({
    paper: "#000000", ink: "#ffffff", graphite: "#a3a3a3",
    wynSecondary: "#a3a3a3", surface: "#111111",
    search: "rgb(17, 17, 17)", skeleton: "rgb(17, 17, 17)",
  });
});

test("shipped styles and install guide contain no legacy warm beige palette", async () => {
  const files = (await readdir(path.join(root, "app"))).filter((name) => name.endsWith(".css"));
  const contents = await Promise.all(files.map(css));
  const guide = await readFile(path.join(root, "public/add-to-home.html"), "utf8");
  const legacyWarm = /#(?:faf9f6|f1efe9|e8e6e0|c7c4bc|b7b4ac|8a8880|12120f)\b/i;
  for (let i = 0; i < files.length; i += 1) {
    expect(contents[i], files[i] + " retains a legacy warm color").not.toMatch(legacyWarm);
  }
  expect(guide).not.toMatch(legacyWarm);
  expect(guide).toContain("--paper:#FFFFFF");
  expect(guide).toContain("background:#F5F5F5");
});
