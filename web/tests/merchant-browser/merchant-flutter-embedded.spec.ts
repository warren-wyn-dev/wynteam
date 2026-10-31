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
async function signedIn(page: Page, expiresIn = 3600) {
  await mockAPIs(page);
  await page.addInitScript(({ userId, slot, expiresIn }) => {
    if (sessionStorage.getItem("zoky-fixture-signout") === "1") return;
    const expiresAt = Math.floor(Date.now() / 1000) + expiresIn;
    const jwt = `${btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }))}.${btoa(JSON.stringify({ sub: userId, aud: "authenticated", exp: expiresAt, role: "authenticated" }))}.synthetic-signature`;
    localStorage.setItem("wynos.active-account-storage.v1", slot);
    localStorage.setItem(slot, JSON.stringify({
      access_token: jwt, refresh_token: "synthetic-refresh-token", token_type: "bearer",
      expires_in: 3600, expires_at: expiresAt,
      user: { id: userId, aud: "authenticated", role: "authenticated", email: "merchant@example.test", app_metadata: {}, user_metadata: {}, created_at: "2026-01-01T00:00:00Z", is_anonymous: false },
    }));
  }, { userId, slot, expiresIn });
}
async function fakeEngine(page: Page, autoReady = true) {
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
              if (${autoReady}) queueMicrotask(() => window.dispatchEvent(new CustomEvent('zoky-merchant-startup', {
                detail: { viewId: id, phase: 'content-ready', elapsedMs: 1, fontWarmupMs: 0, fontWarmupTimedOut: false },
              })));
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
  await expect.poll(() => page.locator('.wm-auth-brand img').evaluate((img: HTMLImageElement) => img.complete && img.naturalWidth > 0)).toBe(true);
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
    const browser = window as unknown as { zokyMerchant: { request: (method: string, args: string) => Promise<string> }; __merchantFixture: { initialized: unknown[]; config: unknown } };
    return { keys: Object.keys(browser.zokyMerchant).sort(), stores: JSON.parse(await browser.zokyMerchant.request("stores", "{}")), initialized: browser.__merchantFixture.initialized, config: browser.__merchantFixture.config };
  });
  expect(result.config).toEqual({ entrypointBaseUrl: "/merchant-flutter/", assetBase: "/merchant-flutter/", canvasKitBaseUrl: "/merchant-flutter/canvaskit/", forceSingleThreadedSkwasm: true });
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

test("Flutter keeps edge swipes and document scrolling within its own view", async ({ page }, testInfo) => {
  await signedIn(page); await fakeEngine(page);
  await page.goto("/merchant/flutter");
  const view = page.locator("[data-synthetic-flutter-view]");
  await expect(view).toHaveCount(1);
  await expect(page.locator("html")).toHaveCSS("overflow-y", "hidden");
  await expect(page.locator("body")).toHaveCSS("overscroll-behavior-y", "none");
  await page.screenshot({ path: testInfo.outputPath("merchant-viewport-contained.png"), fullPage: true });
  const backCalls = await view.evaluate((element) => {
    const original = window.history.back;
    let calls = 0;
    window.history.back = () => { calls++; };
    try {
      const touch = (clientX: number) => new Touch({ identifier: 1, target: element, clientX, clientY: 200 });
      element.dispatchEvent(new TouchEvent("touchstart", { bubbles: true, touches: [touch(8)] }));
      element.dispatchEvent(new TouchEvent("touchmove", { bubbles: true, touches: [touch(130)] }));
      element.dispatchEvent(new TouchEvent("touchend", { bubbles: true, touches: [], changedTouches: [touch(130)] }));
      return calls;
    } finally {
      window.history.back = original;
    }
  });
  expect(backCalls).toBe(0);
  // Guests must regain normal document scrolling after the Flutter host leaves.
  await page.evaluate((slot) => {
    sessionStorage.setItem("zoky-fixture-signout", "1");
    localStorage.removeItem(slot);
  }, slot);
  await page.goto("/merchant/login");
  await expect(page.getByRole("heading", { name: "เข้าสู่ระบบร้านค้าของคุณ" })).toBeVisible();
  await expect(page.locator("[data-merchant-flutter-host]")).toHaveCount(0);
  await expect(page.locator("body")).not.toHaveCSS("overflow-y", "hidden");
  await expect(page.locator("body")).not.toHaveCSS("overscroll-behavior-y", "none");
  await page.screenshot({ path: testInfo.outputPath("merchant-guest-scroll-restored.png"), fullPage: true });
});

test("an authorized engine starts while its bridge chunk is still downloading", async ({ page }) => {
  await signedIn(page);
  await fakeEngine(page);
  let bridgeChunks = 0;
  let releaseBridge!: () => void;
  const bridgePending = new Promise<void>(resolve => { releaseBridge = resolve; });
  // Turbopack's named async-loader stub is an initial hydration prerequisite.
  // Release that stub, but hold its declared payload chunks to delay the actual
  // bridge download without blocking the independent authorized parent itself.
  await page.route("**/*merchant-flutter-authenticated*.js", async route => {
    const response = await route.fetch();
    const source = await response.text();
    const chunks = [...source.matchAll(/"(static\/chunks\/[^"\n]+\.js)"/g)].map(match => match[1]);
    expect(chunks.length).toBeGreaterThan(0);
    for (const chunk of chunks) {
      await page.route(`**/_next/${chunk}`, async payload => {
        bridgeChunks++;
        await bridgePending;
        await payload.continue();
      });
    }
    await route.fulfill({ response, body: source });
  });
  try {
    await page.goto("/merchant/flutter", { waitUntil: "domcontentloaded" });
    await expect.poll(() => bridgeChunks).toBeGreaterThan(0);
    await expect.poll(() => page.evaluate(() => {
      const browser = window as unknown as { __merchantFixture?: { initialized: unknown[] } };
      return browser.__merchantFixture?.initialized.length ?? 0;
    })).toBe(1);
    expect(await page.evaluate(() => "zokyMerchant" in window)).toBe(false);
    await expect(page.locator("[data-synthetic-flutter-view]")).toHaveCount(0);
  } finally {
    releaseBridge();
  }
  await expect(page.locator("[data-synthetic-flutter-view]")).toHaveCount(1);
  await expect(page.getByRole("status")).toHaveCount(0);
});

test("bundle load failure shows recovery and a link to the working legacy route", async ({ page }, testInfo) => {
  await signedIn(page);
  await page.route("**/merchant-flutter/flutter_bootstrap.js", (route) => route.fulfill({ status: 404, contentType: "text/plain", body: "missing fixture bundle" }));
  await page.goto("/merchant/flutter");
  await expect(page.getByRole("main", { name: "Zoky Merchant" }).getByRole("alert")).toContainText("เปิด Zoky Merchant ไม่สำเร็จ");
  await expect(page.getByRole("button", { name: "ลองโหลดใหม่" })).toBeVisible();
  await expect(page.getByRole("link", { name: "เปิดหน้าร้านเดิม" })).toHaveAttribute("href", "/merchant?legacy=1");
  await page.screenshot({ path: testInfo.outputPath("merchant-flutter-wrapper-error.png"), fullPage: true });
});

test("the wrapper reveals only its matching content-ready view", async ({ page }) => {
  await signedIn(page); await fakeEngine(page, false);
  await page.goto('/merchant/flutter');
  await expect(page.locator('[data-synthetic-flutter-view]')).toHaveCount(1);
  const host = page.locator('[data-merchant-flutter-host]');
  await expect(host).toHaveAttribute('aria-hidden', 'true');
  await expect(host).toHaveAttribute('inert', '');
  await expect(page.getByRole('status')).toBeVisible();
  const signal = async (viewId: number) => page.evaluate(viewId => {
    window.dispatchEvent(new CustomEvent('zoky-merchant-startup', {
      detail: { viewId, phase: 'content-ready', elapsedMs: 12, fontWarmupMs: 10, fontWarmupTimedOut: false },
    }));
  }, viewId);
  await signal(99);
  await expect(page.getByRole('status')).toBeVisible();
  await expect(host).toHaveAttribute('aria-hidden', 'true');
  await signal(1);
  await expect(page.getByRole('status')).toHaveCount(0);
  await expect(host).toHaveAttribute('aria-hidden', 'false');
  await expect(host).not.toHaveAttribute('inert', '');
});


test("login form paints during a slow session check and unlocks after it completes", async ({ page }) => {
  await signedIn(page, -60);
  let refreshRequests = 0;
  let releaseRefresh!: () => void;
  const waiting = new Promise<void>(resolve => { releaseRefresh = resolve; });
  await page.route("**/auth/v1/token**", async route => {
    refreshRequests++;
    await waiting;
    await route.fulfill({ status: 400, contentType: "application/json", body: JSON.stringify({ code: "refresh_token_not_found", message: "Synthetic expired session" }) });
  });
  let bootstrapRequests = 0;
  await page.route("**/merchant-flutter/flutter_bootstrap.js", route => { bootstrapRequests++; return route.abort(); });
  try {
    await page.goto("/merchant/login");
    await expect(page.getByRole("heading", { name: "เข้าสู่ระบบร้านค้าของคุณ" })).toBeVisible();
    await expect.poll(() => refreshRequests).toBeGreaterThan(0);
    await expect(page.getByLabel("อีเมล", { exact: true })).toBeVisible();
    await expect(page.getByLabel("อีเมล", { exact: true })).toBeDisabled();
    await expect(page.getByRole("button", { name: "กำลังตรวจสอบบัญชี…", exact: true })).toBeDisabled();
    expect(bootstrapRequests).toBe(0);
  } finally {
    releaseRefresh();
  }
  await expect(page.getByLabel("อีเมล", { exact: true })).toBeEnabled();
  await expect(page.getByRole("button", { name: "เข้าสู่ระบบ", exact: true })).toBeEnabled();
});
