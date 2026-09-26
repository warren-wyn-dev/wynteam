import { expect, test } from "@playwright/test";

// A new active storage slot in another tab must never leave the old tab's
// long-lived Supabase singleton and QueryClient displaying the prior account.
test("switching accounts in another tab reloads the old tab", async ({ context, page }) => {
  test.skip(Boolean(process.env.PLAYWRIGHT_BASE_URL), "Requires the local dev auth fixture");
  await page.goto("/dev/auth-reopen-fixture", { waitUntil: "networkidle" });
  await expect(page.getByRole("button", { name: "Read session-check count" })).toBeVisible();

  const other = await context.newPage();
  await other.goto("/dev/auth-reopen-fixture", { waitUntil: "networkidle" });
  await expect(other.getByRole("button", { name: "Read session-check count" })).toBeVisible();

  const reloaded = page.waitForEvent("load");
  // Model a real switch: clear shared persisted data before publishing the
  // active slot. No credentials or live Supabase account are needed here.
  await other.evaluate(() => {
    localStorage.removeItem("wynos-query-cache");
    localStorage.setItem("wynos.active-account-storage.v1", "wynos.account.cross-tab-test");
  });
  await reloaded;
  await expect(page.getByRole("button", { name: "Read session-check count" })).toBeVisible();
  const navigationType = await page.evaluate(
    () => performance.getEntriesByType("navigation")[0]?.toJSON()?.type,
  );
  expect(navigationType).toBe("reload");
  await other.close();
});
