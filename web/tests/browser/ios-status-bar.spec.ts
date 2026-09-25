import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("installed iOS Home paints status backing in the header rather than a fixed layer", async ({ page }) => {
  // Browser emulation validates our CSS only; it cannot emulate the OS shadow.
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

  const strip = page.locator(".wyn-ios-status-fill");
  await expect(strip).toHaveCSS("display", "none");
  await expect(page.locator(".wyn-home")).toHaveCSS("backdrop-filter", "none");
  const homePadding = await page.locator(".wyn-home").evaluate((el) => parseFloat(getComputedStyle(el).paddingTop));
  expect(homePadding).toBeLessThanOrEqual(20);
  await expect(page.locator(".wyn-home")).toHaveCSS("background-image", "none");

  // The selected cover remains behind black-translucent iOS system chrome.
  await page.evaluate(() => {
    const profile = document.createElement("section");
    profile.className = "wyn-profile-beta1";
    document.body.appendChild(profile);
    document.documentElement.classList.add("wyn-status-cover-route");
  });
  await expect(strip).toHaveCSS("display", "none");
  await expect(page.locator(".wyn-home")).toHaveCSS("background-image", "none");
});

test("status-area workaround keeps iOS profile and other mobile layouts unchanged", () => {
  const file = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");
  const css = file("app/profile-web-beta1.css");
  const layout = file("app/layout.tsx");
  const runtime = file("components/app-navigation-runtime.tsx");

  expect(layout).toContain('className="wyn-ios-status-fill"');
  expect(layout).toContain('statusBarStyle:"black-translucent"');
  expect(css).toContain("body:not(:has(.wyn-profile-beta1)) > .wyn-ios-status-fill");
  expect(css).toContain("height: env(safe-area-inset-top, 0px)");
  expect(css).toContain(".wyn-profile-beta1 .wyn-profile-cover");
  expect(css).not.toContain("body:not(:has(.wyn-profile-beta1))::before");
  expect(runtime).toContain('classList.toggle("wyn-pwa-standalone", mode.matches || iosInstalled)');
});

test("installed iOS keeps non-profile headers crisp but leaves the profile cover full-bleed", async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperties(navigator, {
      standalone: { configurable: true, value: true },
      userAgent: { configurable: true, value: "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148" },
    });
  });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  await expect.poll(() => page.evaluate(() =>
    document.documentElement.classList.contains("wyn-ios-standalone"),
  )).toBe(true);
  const strip = page.locator(".wyn-ios-status-fill");
  await expect(strip).toHaveCSS("display", "none");
  await expect(page.locator(".wyn-home")).toHaveCSS("backdrop-filter", "none");
  await page.evaluate(() => {
    const header = document.createElement("header");
    header.className = "route-header";
    document.body.append(header);
    const chat = document.createElement("section");
    chat.className = "wyn-chat-inbox";
    chat.innerHTML = '<header class="flutter-chat-header"></header>';
    document.body.append(chat);
    const conversation = document.createElement("header");
    conversation.className = "conversation-modern-header";
    document.body.append(conversation);
    const detail = document.createElement("header");
    detail.className = "detail-floating-header";
    document.body.append(detail);
  });
  await expect(page.locator(".route-header")).toHaveCSS("backdrop-filter", "none");
  await expect(page.locator(".route-header")).toHaveCSS("background-color", "rgb(255, 255, 255)");
  await expect(page.locator(".wyn-chat-inbox .flutter-chat-header")).toHaveCSS("backdrop-filter", "none");
  await expect(page.locator(".wyn-chat-inbox .flutter-chat-header")).toHaveCSS("background-color", "rgb(255, 255, 255)");
  await expect(page.locator(".conversation-modern-header")).toHaveCSS("backdrop-filter", "none");
  await expect(page.locator(".detail-floating-header")).toHaveCSS("backdrop-filter", "none");
  // The compact fix must not inject a second artificial 44px spacer.
  // Compare with the *actual* browser safe area; iPhone 13's native inset
  // can itself exceed 44px, so a fixed upper bound would be incorrect.
  const safeTop = await page.evaluate(() => {
    const probe = document.createElement("div");
    probe.style.cssText = "position:absolute;visibility:hidden;padding-top:env(safe-area-inset-top, 0px)";
    document.body.append(probe);
    const value = parseFloat(getComputedStyle(probe).paddingTop) || 0;
    probe.remove();
    return value;
  });
  for (const selector of [".route-header", ".conversation-modern-header", ".detail-floating-header"]) {
    const padding = await page.locator(selector).evaluate((el) => parseFloat(getComputedStyle(el).paddingTop));
    expect(padding).toBeLessThanOrEqual(safeTop + 9);
  }

  await page.evaluate(() => document.documentElement.classList.add("wyn-status-cover-route"));
  await expect(strip).toHaveCSS("display", "none");
  await page.evaluate(() => document.documentElement.classList.remove("wyn-status-cover-route"));
  await expect(strip).toHaveCSS("display", "none");
});

test("Profile's black-translucent cover metadata and existing cover geometry survive the status fix", () => {
  const read = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");
  const layout = read("app/layout.tsx");
  const css = read("app/profile-web-beta1.css");
  const runtime = read("components/app-navigation-runtime.tsx");
  expect(layout).toContain('statusBarStyle:"black-translucent"');
  expect(css).toContain("height: calc(clamp(150px, 38vw, 210px) + env(safe-area-inset-top, 0px))");
  expect(css).toContain("body:not(:has(.wyn-profile-beta1)) > .wyn-ios-status-fill");
  expect(css).toContain("html:not(.wyn-status-cover-route)");
  expect(css).toContain("display: none !important;");
  expect(css).not.toContain("--wyn-ios-shadow-clearance: 44px");
  expect(css).toContain("padding-top: min(env(safe-area-inset-top, 0px), 20px)");
  expect(runtime).toContain('classList.toggle("wyn-status-cover-route", coverRoute)');
});
