import { expect, test, type Page } from "@playwright/test";

// Synthetic sessions and API fixtures only. Never sign in to a real account.
const userId = "11111111-1111-4111-8111-111111111111";
const slot = "zoky.merchant.browser-fixture";

test.use({ serviceWorkers: "block" });
test.beforeEach(({}, testInfo) => {
  test.skip(!testInfo.project.name.startsWith("merchant-") && !process.env.NEXT_PUBLIC_SUPABASE_URL && !process.env.PLAYWRIGHT_BASE_URL,
    "Synthetic shared-auth coverage runs with the focused Merchant browser configuration.");
});

async function mockAPIs(page: Page) {
  await page.route("**/rest/v1/**", (route) => {
    const path = new URL(route.request().url()).pathname;
    const body = path.includes("/rpc/") ? "false" : "[]";
    return route.fulfill({ status: 200, contentType: "application/json", body });
  });
  await page.route("**/auth/v1/**", (route) => route.fulfill({ status: 200, contentType: "application/json", body: "{}" }));
}
async function signedIn(page: Page) {
  await mockAPIs(page);
  await page.addInitScript(({ userId, slot }) => {
    if (sessionStorage.getItem("zoky-fixture-signout") === "1") return;
    const expiresAt = Math.floor(Date.now() / 1000) + 3600;
    const jwt = `${btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }))}.${btoa(JSON.stringify({ sub: userId, aud: "authenticated", exp: expiresAt, role: "authenticated" }))}.synthetic-signature`;
    localStorage.setItem("wynos.active-account-storage.v1", slot);
    localStorage.setItem(slot, JSON.stringify({
      access_token: jwt, refresh_token: "synthetic-refresh-token", token_type: "bearer",
      expires_in: 3600, expires_at: expiresAt,
      user: { id: userId, aud: "authenticated", role: "authenticated", email: "merchant@example.test", app_metadata: {}, user_metadata: {}, created_at: "2026-01-01T00:00:00Z", is_anonymous: false },
    }));
  }, { userId, slot });
}
async function fakeEngine(page: Page) {
  await page.route("**/merchant-flutter/flutter_bootstrap.js", (route) => route.fulfill({
    status: 200, contentType: "text/javascript", body: `
      window.__merchantFixture = { added: [], removed: [], initialized: [] };
      window._flutter = { loader: { load: async ({ config, onEntrypointLoaded }) => {
        window.__merchantFixture.config = config;
        await onEntrypointLoaded({ initializeEngine: async (options) => {
          window.__merchantFixture.initialized.push(options);
          return { runApp: async () => ({
            addView: ({ hostElement }) => {
              const id = window.__merchantFixture.added.length + 1;
              const view = document.createElement('div');
              view.dataset.syntheticFlutterView = String(id);
              view.textContent = 'Synthetic Merchant view';
              hostElement.appendChild(view);
              window.__merchantFixture.added.push(id);
              return id;
            },
            removeView: (id) => {
              window.__merchantFixture.removed.push(id);
              sessionStorage.setItem('zoky-fixture-removed', JSON.stringify(window.__merchantFixture.removed));
              document.querySelector('[data-synthetic-flutter-view="' + id + '"]')?.remove();
            },
          }) };
        } });
      } } };
    `,
  }));
}

test("signed-out Merchant route redirects to the existing login without starting Flutter", async ({ page }) => {
  await mockAPIs(page);
  let bootstrapRequests = 0;
  await page.route("**/merchant-flutter/flutter_bootstrap.js", (route) => { bootstrapRequests++; return route.abort(); });
  await page.goto("/merchant/flutter");
  await expect(page).toHaveURL(/\/merchant\/login$/);
  await expect(page.getByRole("heading", { name: "เข้าสู่ระบบร้านค้าของคุณ" })).toBeVisible();
  expect(bootstrapRequests).toBe(0);
  await expect(page.getByRole('img', { name: 'ZOKY Merchant', exact: true })).toBeVisible();
  await expect.poll(() => page.locator('.wm-auth-brand img').evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth === 1140)).toBe(true);
  await expect.poll(() => page.locator('.wm-auth-brand').evaluate(element => {
    for (let current: Element | null = element; current; current = current.parentElement) {
      if (Number(getComputedStyle(current).opacity) < .999) return false;
    }
    return true;
  })).toBe(true);
  await expect(page.getByRole('button', { name: 'เข้าสู่ระบบ', exact: true })).toHaveCSS('background-color', 'rgb(214, 18, 86)');
  await expect(page.getByRole('link', { name: 'ลืมรหัสผ่าน?' })).toHaveCSS('color', 'rgb(107, 107, 118)');
  const email = page.getByLabel('อีเมล');
  await email.focus();
  await expect(email).toHaveCSS('border-color', 'rgb(214, 18, 86)');
  await email.blur();
  await expect(email).toHaveCSS('border-color', 'rgb(235, 235, 239)');
  await page.screenshot({ path: test.info().outputPath('merchant-official-logo-login.png'), fullPage: true });
});

test("authenticated wrapper mounts one removable view and exposes a token-free bridge", async ({ page }, testInfo) => {
  await signedIn(page); await fakeEngine(page);
  const exceptions: string[] = []; page.on("pageerror", (error) => exceptions.push(error.message));
  await page.goto("/merchant/flutter");
  await expect(page.locator("[data-synthetic-flutter-view]")).toHaveCount(1);
  await expect(page.getByRole("status")).toHaveCount(0);
  const result = await page.evaluate(async () => {
    const browser = window as unknown as { zokyMerchant: { request: (method: string, args: string) => Promise<string> }; __merchantFixture: { initialized: unknown[] } };
    return { keys: Object.keys(browser.zokyMerchant).sort(), stores: JSON.parse(await browser.zokyMerchant.request("stores", "{}")), initialized: browser.__merchantFixture.initialized };
  });
  expect(result.keys).toEqual(["dispose", "request"]);
  expect(result.stores).toEqual({ ok: true, data: [] });
  expect(result.initialized).toEqual([{ multiViewEnabled: true, assetBase: "/merchant-flutter/", canvasKitBaseUrl: "/merchant-flutter/canvaskit/" }]);
  await page.screenshot({ path: testInfo.outputPath("merchant-flutter-wrapper-synthetic.png"), fullPage: true });
  await page.evaluate((slot) => {
    sessionStorage.setItem("zoky-fixture-signout", "1");
    localStorage.removeItem(slot);
    const channel = new BroadcastChannel(slot);
    channel.postMessage({ event: "SIGNED_OUT", session: null });
    setTimeout(() => channel.close(), 100);
  }, slot);
  await expect(page).toHaveURL(/\/merchant\/login$/);
  await expect.poll(() => page.evaluate(() => sessionStorage.getItem("zoky-fixture-removed"))).toBe("[1]");
  expect(await page.evaluate(() => "zokyMerchant" in window)).toBe(false);
  expect(exceptions).toEqual([]);
});

test("bundle load failure shows recovery and a link to the working legacy route", async ({ page }, testInfo) => {
  await signedIn(page);
  await page.route("**/merchant-flutter/flutter_bootstrap.js", (route) => route.fulfill({ status: 404, contentType: "text/plain", body: "missing fixture bundle" }));
  await page.goto("/merchant/flutter");
  await expect(page.getByRole("main", { name: "Zoky Merchant" }).getByRole("alert")).toContainText("เปิด Zoky Merchant ไม่สำเร็จ");
  await expect(page.getByRole("button", { name: "ลองโหลดใหม่" })).toBeVisible();
  await expect(page.getByRole("link", { name: "เปิดหน้าร้านเดิม" })).toHaveAttribute("href", "/merchant");
  await page.screenshot({ path: testInfo.outputPath("merchant-flutter-wrapper-error.png"), fullPage: true });
});
