import { expect, test } from "@playwright/test";

/**
 * WYNOS Web Beta1, item 11: Edit Profile's new external-website field
 * normalizes/validates the URL client-side (normalizeExternalUrl(), web/
 * lib/external-link.ts) before it's ever sent to the server — the server
 * independently re-validates via a DB trigger (see
 * supabase/tests/wyn_187_profile_external_link_validation_test.sh), since
 * a raw REST call can always bypass this.
 */
test.beforeEach(async ({ page }) => {
  await page.goto("/dev/external-link-fixture", { waitUntil: "networkidle" });
});

test("a bare domain gets https:// prepended", async ({ page }) => {
  await expect(page.locator("#case-plain-domain")).toHaveText("https://example.com/");
});

test("an https:// URL with a path is preserved", async ({ page }) => {
  await expect(page.locator("#case-https")).toHaveText("https://example.com/alice");
});

test("an http:// URL is accepted as-is", async ({ page }) => {
  await expect(page.locator("#case-http")).toHaveText("http://example.com/");
});

test("a javascript: URI is rejected", async ({ page }) => {
  await expect(page.locator("#case-javascript")).toHaveText("null");
});

test("a javascript:// URI (with slashes) is still rejected", async ({ page }) => {
  await expect(page.locator("#case-javascript-slashes")).toHaveText("null");
});

test("an empty/whitespace-only input means \"remove the link\" (null)", async ({ page }) => {
  await expect(page.locator("#case-empty")).toHaveText("null");
});

test("a bare word with no dot is rejected, not stored as a fake domain", async ({ page }) => {
  await expect(page.locator("#case-bare-word")).toHaveText("null");
});

test("surrounding whitespace is trimmed", async ({ page }) => {
  await expect(page.locator("#case-whitespace-padding")).toHaveText("https://example.com/");
});
