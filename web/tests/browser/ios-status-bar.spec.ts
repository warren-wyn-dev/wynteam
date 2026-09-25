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
  // Derive the simulated device safe-area instead of assuming it is 0px.
  const safeInset = await page.evaluate(() => {
    const probe = document.createElement("div");
    probe.style.paddingTop = "env(safe-area-inset-top, 0px)";
    document.body.append(probe);
    const inset = parseFloat(getComputedStyle(probe).paddingTop);
    probe.remove();
    return inset;
  });
  expect(homePadding).toBeCloseTo(safeInset + 20, 0);
  const gradient = await page.locator(".wyn-home").evaluate((el) => getComputedStyle(el).backgroundImage);
  expect(gradient).toContain("linear-gradient(");
  expect(gradient).toContain("rgb(100, 116, 139)");
  expect(gradient).not.toContain("rgb(16, 17, 20)");

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
  // Ensure native shadow clearance applies to all top-bar controls.
  for (const selector of [".route-header", ".wyn-chat-inbox .flutter-chat-header", ".conversation-modern-header", ".detail-floating-header"]) {
    const padding = await page.locator(selector).evaluate((el) => parseFloat(getComputedStyle(el).paddingTop));
    // Chat and conversation intentionally add 6px or 8px to the shared inset.
    const safeInset = await page.evaluate(() => {
      const probe = document.createElement("div");
      probe.style.paddingTop = "env(safe-area-inset-top, 0px)";
      document.body.append(probe);
      const inset = parseFloat(getComputedStyle(probe).paddingTop);
      probe.remove();
      return inset;
    });
    expect(padding).toBeGreaterThanOrEqual(safeInset + 20);
    expect(padding).toBeLessThanOrEqual(safeInset + 32);
  }
  const inboxHeight = await page.locator(".wyn-chat-inbox .flutter-chat-header").evaluate((el) => parseFloat(getComputedStyle(el).height));
  const inset = await page.evaluate(() => {
    const probe = document.createElement("div");
    probe.style.paddingTop = "env(safe-area-inset-top, 0px)";
    document.body.append(probe);
    const value = parseFloat(getComputedStyle(probe).paddingTop);
    probe.remove();
    return value;
  });
  expect(inboxHeight).toBeGreaterThanOrEqual(inset + 88);
  expect(inboxHeight).toBeLessThanOrEqual(inset + 100);

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
  expect(css).toContain("background-image: linear-gradient(");
  expect(css).toContain("--wyn-ios-shadow-clearance: 20px");
  expect(css).toContain("padding-top: var(--wyn-ios-header-offset)");
  expect(css).toContain("--wyn-ios-status-surface: #64748b");
  expect(css).toContain("background-color: var(--wyn-ios-status-surface, #64748b)");
  expect(css).not.toContain("background-color: var(--wyn-ios-status-surface, #101114)");
  expect(css).toContain("--wyn-ios-shadow-end: env(safe-area-inset-top, 0px)");
  expect(runtime).toContain('classList.toggle("wyn-status-cover-route", coverRoute)');
});
