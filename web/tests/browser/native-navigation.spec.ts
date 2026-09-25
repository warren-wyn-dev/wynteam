import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("the five-tab dock remains visible while scrolling the mobile Feed", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 600 });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const nav = page.getByRole("navigation", { name: "เมนูหลัก" });
  await expect(nav.getByRole("link")).toHaveCount(5);
  await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(40);
  await expect(nav).toBeInViewport();
  await expect(nav).toHaveCSS("position", "fixed");
});

// The other two root destinations use the same repeat-tap callback as
// Home and have registered route-local refresh listeners.
test("Club and Chat root tabs handle repeat-tap refresh without reloading", () => {
  const file = (name: string) => readFileSync(path.join(process.cwd(), "components", name), "utf8");
  expect(file("bottom-navigation.tsx")).toContain('onClick={handleActiveTabTap(clubActive, "/clubs")}');
  expect(file("bottom-navigation.tsx")).toContain('onClick={handleActiveTabTap(chatActive, "/chat")}');
  expect(file("clubs-routes.tsx")).toContain("useRouteRefreshListener(pull.refresh)");
  // /chat/page.tsx renders ChatInboxParityRoute, which already uses
  // React Query's user-keyed cache rather than the legacy ChatInboxInner.
  const root = readFileSync(path.join(process.cwd(), "app/chat/page.tsx"), "utf8");
  expect(root).toContain("ChatInboxParityRoute");
  expect(file("chat-inbox-parity.tsx")).toContain("useRouteRefreshListener(refreshInbox)");
  expect(file("chat-inbox-parity.tsx")).toContain('refetchOnMount: "always"');
  expect(file("chat-inbox-parity.tsx")).toContain("queryKey: [\"chat-inbox\", userId]");
});
