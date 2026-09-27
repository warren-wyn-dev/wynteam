import { expect, test, type Page } from "@playwright/test";

// WYN-188: Light / Dark / System theme (released to every account 2026-09-27).
const KEY = "wynos.theme.v1";

async function storeChoice(page: Page, choice: string | null) {
  await page.addInitScript(([key, value]) => {
    try {
      if (value) localStorage.setItem(key, value);
      else localStorage.removeItem(key);
    } catch {}
  }, [KEY, choice] as const);
}

const bodyBackground = (page: Page) => page.evaluate(() => getComputedStyle(document.body).backgroundColor);
const appliedTheme = (page: Page) => page.evaluate(() => document.documentElement.dataset.theme ?? null);

test.describe("an account that never chose a theme", () => {
  test("no data-theme; the page follows the phone exactly as before", async ({ page }) => {
    await storeChoice(page, null);
    await page.emulateMedia({ colorScheme: "dark" });
    await page.goto("/welcome");
    expect(await appliedTheme(page)).toBeNull();
    expect(await bodyBackground(page)).toBe("rgb(0, 0, 0)");
    await page.emulateMedia({ colorScheme: "light" });
    expect(await bodyBackground(page)).toBe("rgb(255, 255, 255)");
  });
});

test.describe("a chosen theme", () => {
  test("Dark applies before first paint even when the phone is light", async ({ page }) => {
    await storeChoice(page, "dark");
    await page.emulateMedia({ colorScheme: "light" });
    await page.goto("/welcome", { waitUntil: "domcontentloaded" });
    expect(await appliedTheme(page)).toBe("dark");
    expect(await bodyBackground(page)).toBe("rgb(0, 0, 0)");
    await expect(page.locator('meta[name="theme-color"]').first()).toHaveAttribute("content", "#000000");
  });

  test("Light wins over a dark phone, including the legacy dark rules", async ({ page }) => {
    await storeChoice(page, "light");
    await page.emulateMedia({ colorScheme: "dark" });
    await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });
    expect(await appliedTheme(page)).toBe("light");
    expect(await bodyBackground(page)).toBe("rgb(255, 255, 255)");
    const iconColor = await page.locator(".wyn-home-header").first().evaluate((el) => getComputedStyle(el).getPropertyValue("--wyn-home-icon-color").trim());
    expect(iconColor).toBe("#737780");
  });

  test("System resolves from the phone and follows it live", async ({ page }) => {
    await storeChoice(page, "system");
    await page.emulateMedia({ colorScheme: "light" });
    await page.goto("/dev/home-fixture");
    expect(await appliedTheme(page)).toBe("light");
    // The live listener is installed once the app hydrates (ThemeSync).
    await page.emulateMedia({ colorScheme: "dark" });
    await expect.poll(() => appliedTheme(page)).toBe("dark");
    await expect.poll(() => bodyBackground(page)).toBe("rgb(0, 0, 0)");
  });
});

test.describe("dark fixes reach the default (System) look too", () => {
  for (const choice of ["dark", null] as const) {
    test(`logo mark is visible on black (${choice ?? "nothing chosen, dark phone"})`, async ({ page }) => {
      await storeChoice(page, choice);
      await page.emulateMedia({ colorScheme: "dark" });
      await page.goto("/welcome");
      await expect(page.locator('img[src*="wynos_logo_mark"]').first()).toHaveCSS("filter", "invert(1)");
    });
  }

  test("Light keeps the logo as drawn on a dark phone", async ({ page }) => {
    await storeChoice(page, "light");
    await page.emulateMedia({ colorScheme: "dark" });
    await page.goto("/welcome");
    await expect(page.locator('img[src*="wynos_logo_mark"]').first()).toHaveCSS("filter", "none");
  });
});

// Every main screen stays readable in the dark theme: no visible text below
// 3:1 against its background (disabled controls are exempt under WCAG).
for (const route of [
  "/welcome",
  "/login",
  "/signup/step-1",
  "/dev/home-fixture",
  "/dev/quote-fixture",
  "/dev/search-url-fixture?q=wynos",
  "/dev/trending-fixture?state=list",
  "/dev/post-detail-keyboard-fixture",
  "/dev/follow-button-fixture",
  "/dev/composer-fixture",
]) {
  for (const choice of ["dark", null] as const) test(`${route} is readable in the dark theme${choice ? "" : " (nothing chosen, dark phone)"}`, async ({ page }) => {
    // The composer fixture is dev-server only (404 on hosted staging builds).
    test.skip(route === "/dev/composer-fixture" && Boolean(process.env.PLAYWRIGHT_BASE_URL), "dev-server-only fixture");
    await storeChoice(page, choice);
    await page.emulateMedia({ colorScheme: "dark" });
    await page.goto(route);
    await page.waitForLoadState("networkidle").catch(() => {});
    const failures = await page.evaluate(() => {
      const parse = (c: string) => {
        const m = c.match(/rgba?\(([^)]+)\)/);
        if (!m) return null;
        const p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number);
        return { r: p[0], g: p[1], b: p[2], a: p[3] ?? 1 };
      };
      const lum = ({ r, g, b }: { r: number; g: number; b: number }) => {
        const f = (v: number) => ((v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
      };
      const background = (el: Element | null) => {
        for (let e = el; e; e = e.parentElement) {
          const c = parse(getComputedStyle(e).backgroundColor);
          if (c && c.a > 0.5) return c;
        }
        return { r: 0, g: 0, b: 0, a: 1 };
      };
      const out: string[] = [];
      const seen = new Set<Element>();
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        const el = walker.currentNode.parentElement;
        const text = walker.currentNode.textContent?.trim();
        if (!el || !text || seen.has(el)) continue;
        seen.add(el);
        if (el.closest(":disabled, [aria-disabled='true'], [aria-hidden='true']")) continue;
        const style = getComputedStyle(el);
        const rect = el.getBoundingClientRect();
        if (style.visibility === "hidden" || rect.width === 0 || rect.height === 0 || Number(style.opacity) === 0) continue;
        const fg = parse(style.color);
        if (!fg) continue;
        const bg = background(el);
        const [a, b] = [lum(fg), lum(bg)];
        const ratio = (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
        if (ratio < 3) out.push(`${ratio.toFixed(2)}:1 "${text.slice(0, 24)}" ${style.color} on rgb(${bg.r},${bg.g},${bg.b})`);
      }
      return out;
    });
    expect(failures, failures.join("\n")).toEqual([]);
  });
}
