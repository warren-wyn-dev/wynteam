import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

async function simulateInstalledIphone(page: import("@playwright/test").Page) {
  await page.addInitScript(() => {
    Object.defineProperties(navigator, {
      standalone: { configurable: true, value: true },
      userAgent: {
        configurable: true,
        value: "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
      },
    });
  });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  await expect.poll(() => page.evaluate(() =>
    document.documentElement.classList.contains("wyn-ios-standalone"),
  )).toBe(true);
}

test("installed iPhone Home has a plain white header with no web status overlay or extra inset", async ({ page }) => {
  // Emulation tests CSS, not the real iOS clock or installation metadata cache.
  await simulateInstalledIphone(page);
  await expect(page.locator(".wyn-ios-status-fill")).toHaveCount(0);
  await expect(page.locator(".wyn-home")).toHaveCSS("background-image", "none");
  await expect(page.locator(".wyn-home")).toHaveCSS("backdrop-filter", "none");
  await expect(page.locator(".wyn-home")).toHaveCSS("padding-top", "0px");
  await expect(page.locator(".wyn-home")).toHaveCSS("background-color", "rgb(255, 255, 255)");
  const rootBackground = await page.evaluate(() => getComputedStyle(document.documentElement).backgroundColor);
  expect(rootBackground).toBe("rgb(255, 255, 255)");
});

test("installed iPhone route and Chat headers use compact non-overlapping geometry", async ({ page }) => {
  await simulateInstalledIphone(page);
  await page.evaluate(() => {
    const route = document.createElement("header");
    route.className = "route-header";
    document.body.append(route);
    const inbox = document.createElement("section");
    inbox.className = "wyn-chat-inbox";
    inbox.innerHTML = '<header class="flutter-chat-header"></header>';
    document.body.append(inbox);
    const conversation = document.createElement("header");
    conversation.className = "conversation-modern-header";
    document.body.append(conversation);
    const detail = document.createElement("header");
    detail.className = "detail-floating-header";
    document.body.append(detail);
  });
  for (const selector of [".route-header", ".wyn-chat-inbox .flutter-chat-header", ".conversation-modern-header", ".detail-floating-header"]) {
    await expect(page.locator(selector)).toHaveCSS("background-image", "none");
    await expect(page.locator(selector)).toHaveCSS("backdrop-filter", "none");
    await expect(page.locator(selector)).toHaveCSS("background-color", "rgb(255, 255, 255)");
  }
  await expect(page.locator(".route-header")).toHaveCSS("padding-top", "0px");
  await expect(page.locator(".detail-floating-header")).toHaveCSS("padding-top", "0px");
  await expect(page.locator(".wyn-chat-inbox .flutter-chat-header")).toHaveCSS("height", "68px");
  await expect(page.locator(".wyn-chat-inbox .flutter-chat-header")).toHaveCSS("padding-top", "6px");
  await expect(page.locator(".conversation-modern-header")).toHaveCSS("padding-top", "8px");
});

test("installed iPhone Profile starts its user-selected cover beneath the native status bar", async ({ page }) => {
  await simulateInstalledIphone(page);
  await page.evaluate(() => {
    const profile = document.createElement("section");
    profile.className = "wyn-profile-beta1";
    profile.innerHTML = '<div class="wyn-profile-hero"><div class="wyn-profile-cover"></div><div class="wyn-profile-topbar"></div></div>';
    document.body.append(profile);
  });
  const width = await page.locator(".wyn-profile-beta1 .wyn-profile-cover").evaluate(el => el.getBoundingClientRect().width);
  const expectedHeight = Math.max(150, Math.min(width * .38, 210));
  const actualHeight = await page.locator(".wyn-profile-beta1 .wyn-profile-cover").evaluate(el => el.getBoundingClientRect().height);
  expect(actualHeight).toBeCloseTo(expectedHeight, 0);
  await expect(page.locator(".wyn-profile-beta1 .wyn-profile-topbar")).toHaveCSS("top", "0px");
  await expect(page.locator(".wyn-profile-beta1 .wyn-profile-topbar")).toHaveCSS("height", "58px");
  await expect(page.locator(".wyn-profile-beta1 .wyn-profile-topbar")).toHaveCSS("padding-top", "0px");
});

test("metadata and CSS use Apple's default white status mode without old translucent workarounds", () => {
  const read = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");
  const layout = read("app/layout.tsx");
  const css = read("app/profile-web-beta1.css");
  const runtime = read("components/app-navigation-runtime.tsx");
  expect(layout).toContain('statusBarStyle:"default"');
  expect(layout).toContain('viewportFit:"cover"');
  expect(layout).not.toContain('statusBarStyle:"black-translucent"');
  expect(layout).not.toContain('className="wyn-ios-status-fill"');
  expect(css).not.toContain(".wyn-ios-status-fill");
  expect(css).not.toContain("#8f9bad");
  expect(css).not.toContain("--wyn-ios-header-blend");
  expect(css).not.toContain("wyn-status-cover-route");
  expect(css).toContain("height: clamp(150px, 38vw, 210px);");
  expect(runtime).toContain('classList.toggle("wyn-ios-standalone"');
  expect(runtime).not.toContain("wyn-status-cover-route");
});
