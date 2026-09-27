import { expect, test, type Page } from "@playwright/test";

// WYN-189: Thai / English (released to every account 2026-09-27).
const KEY = "wynos.lang.v1";

async function storeChoice(page: Page, choice: "th" | "en" | null) {
  await page.addInitScript(([key, value]) => {
    try {
      if (value) localStorage.setItem(key, value);
      else localStorage.removeItem(key);
    } catch {}
  }, [KEY, choice] as const);
}

async function switchTo(page: Page, language: "th" | "en") {
  await page.evaluate(([key, value]) => {
    localStorage.setItem(key, value);
    window.dispatchEvent(new CustomEvent("wynos:language-change", { detail: value }));
  }, [KEY, language] as const);
}

test.describe("first visit follows the phone language", () => {
  test.use({ locale: "en-US" });

  test("an English phone sees the welcome screen in English", async ({ page }) => {
    await storeChoice(page, null);
    await page.goto("/welcome");
    await expect(page.getByText("Create a new account")).toBeVisible();
    await expect(page.getByText("Sign in with Google")).toBeVisible();
    await expect(page.locator("html")).toHaveAttribute("lang", "en");
    await expect(page).toHaveTitle("Wynos — Welcome");
    await expect(page.locator("html")).not.toHaveAttribute("data-i18n-pending", /.*/);
  });

  test("a saved Thai choice wins over an English phone", async ({ page }) => {
    await storeChoice(page, "th");
    await page.goto("/welcome");
    await expect(page.getByText("สร้างบัญชีใหม่")).toBeVisible();
    await expect(page.locator("html")).toHaveAttribute("lang", "th");
  });

  test("the birth-year picker shows Gregorian years in English", async ({ page }) => {
    await storeChoice(page, "en");
    await page.goto("/signup/step-1");
    const year = page.locator('select[data-i18n-years="buddhist"]');
    await expect(year.locator('option[value="2000"]')).toHaveText("2000");
    await expect(year).toHaveAttribute("aria-label", "Year");
  });

  test("streamed pages hydrate cleanly in English", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await storeChoice(page, null);
    await page.goto("/dev/trending-fixture?state=list");
    await page.goto("/dev/search-url-fixture?q=wynos");
    await page.waitForLoadState("networkidle");
    expect(errors.filter((message) => /hydrat/i.test(message))).toEqual([]);
  });
});

test("a Thai phone sees Thai", async ({ page }) => {
  await storeChoice(page, null);
  await page.goto("/welcome");
  await expect(page.getByText("สร้างบัญชีใหม่")).toBeVisible();
  await expect(page.locator("html")).toHaveAttribute("lang", "th");
});

test("switching language changes the app text live and leaves people's posts as written", async ({ page }) => {
  await storeChoice(page, "en");
  await page.goto("/dev/home-fixture");
  const tabs = page.getByRole("tablist").first();
  await expect(tabs.getByText("For You")).toBeVisible();
  const firstPost = page.locator("article").first();
  const postText = await firstPost.innerText();
  expect(postText).toMatch(/[฀-๿]/);

  await switchTo(page, "th");
  await expect(tabs.getByText("สำหรับคุณ")).toBeVisible();
  await expect(page.locator("html")).toHaveAttribute("lang", "th");

  await switchTo(page, "en");
  await expect(tabs.getByText("For You")).toBeVisible();
  expect(await firstPost.innerText()).toBe(postText);
});
