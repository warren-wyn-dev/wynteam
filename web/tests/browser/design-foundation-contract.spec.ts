import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const read = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");

test("Design System foundation declares roles without rewriting existing component styles", () => {
  const css = read("app/design-system.css");
  const baseline = read("app/globals.css");
  const doc = read("docs/web-beta1-design-system-foundation-20260926.md");

  expect(css).toContain("--wyn-color-link: #0969da");
  expect(css).toContain("--wyn-color-link-vivid: #1d9bf0");
  expect(css).toContain("--wyn-color-like: var(--wyn-like, #ff3b30)");
  expect(css).toContain("--wyn-color-danger: var(--wyn-accent)");
  expect(css).toContain("--wyn-touch-target-min: 44px");
  expect(css).toContain("--wyn-size-icon-action: 22px");
  expect(css).toContain("--wyn-size-icon-comment: 24px");
  expect(css).toContain("--wyn-size-icon-nav: 28px");
  expect(css).toContain("--wyn-color-link: #5eb1ff");
  // Already-approved values must not drift when the new names are declared.
  expect(baseline).toContain("--wyn-like: #ff3b30");
  expect(css).toContain("--wyn-bg: #ffffff");
  expect(css).toContain("--wyn-font-input: 16px");
  expect(css).toContain("--wyn-control-height: 50px");
  expect(css).toContain("--wyn-control-height-compact: 44px");
  expect(doc).toContain("This is a **tokens-and-contract-only** change");
});

test("light and dark semantic blue are readable without changing the actual Feed UI", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "light" });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const tokens = () => page.evaluate(() => {
    const root = getComputedStyle(document.documentElement);
    return {
      link: root.getPropertyValue("--wyn-color-link").trim(),
      vivid: root.getPropertyValue("--wyn-color-link-vivid").trim(),
      touch: root.getPropertyValue("--wyn-touch-target-min").trim(),
      like: root.getPropertyValue("--wyn-color-like").trim(),
    };
  });
  expect(await tokens()).toEqual({
    link: "#0969da",
    vivid: "#1d9bf0",
    touch: "44px",
    like: "#ff3b30",
  });

  await page.emulateMedia({ colorScheme: "dark" });
  expect(await tokens()).toEqual({
    link: "#5eb1ff",
    vivid: "#5eb1ff",
    touch: "44px",
    like: "#ff3b30",
  });
});
