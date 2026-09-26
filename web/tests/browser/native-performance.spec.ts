import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("the existing compact mobile post image requests a content-column-sized source", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 780 });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const image = page.locator(".wyn-post-media-item").first();
  // Next.js deliberately omits sizes/srcSet for this fixture's data: SVG.
  // Verify the responsive sizes contract at the actual component source.
  const carousel = readFileSync(path.join(process.cwd(), "components/home/post-media-carousel.tsx"), "utf8");
  expect(carousel).toContain("(max-width: 680px) calc(100vw - 72px), 600px");
  await expect(image).toHaveAttribute("loading", "lazy");
  const frame = await image.boundingBox();
  expect(frame).not.toBeNull();
  expect(frame!.width).toBeLessThan(390);
});

// Source guard for the actual authenticated Home feed: fixture-only browser
// tests cannot observe its Supabase fetch pipeline without user credentials.
test("background feed tabs wait for idle and respect mobile data saving", () => {
  const home = readFileSync(path.join(process.cwd(), "components/home/home-screen.tsx"), "utf8");
  expect(home).toContain("requestIdleCallback(warmOtherTabs");
  expect(home).toContain("hints?.saveData");
  expect(home).toContain('hints?.effectiveType === "2g"');
  expect(home).toContain('document.visibilityState !== "visible"');
  expect(home).toContain("window.cancelIdleCallback(handle)");
});

test("production web has field performance capture, privacy-safe failure tags and a retry screen", () => {
  const read = (file: string) => readFileSync(path.join(process.cwd(), file), "utf8");
  const layout = read("app/layout.tsx");
  const monitor = read("components/client-error-monitor.tsx");
  const health = read("lib/client-health.ts");
  const fallback = read("app/error.tsx");
  expect(layout).toContain("<Analytics />");
  expect(layout).toContain("<SpeedInsights />");
  expect(layout).toContain("<ClientErrorMonitor />");
  expect(monitor).toContain('window.addEventListener("error"');
  expect(monitor).toContain('window.addEventListener("unhandledrejection"');
  expect(health).toContain('track("beta1_client_failure", { kind, area })');
  expect(health).not.toContain("error.message");
  expect(health).not.toContain("error.stack");
  expect(health).not.toContain("userId");
  expect(fallback).toContain("reset");
  expect(fallback).toContain('role="alert"');
});
