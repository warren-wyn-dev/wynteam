import { expect, test, type Page } from "@playwright/test";
import { waitForSettledRoute } from "./route-settled";

const STORE_ID = "10000000-0000-4000-8000-000000000001";
const MENU_ID = "10000000-0000-4000-8000-000000000002";
const GUEST_BASKET_KEY = "wynos-food-guest-basket-v1";
const STORE_NAME = "ครัวทดสอบการสั่งอาหาร";
const MENU_NAME = "ข้าวผัดทดสอบ";

const catalog = [{
  id: STORE_ID,
  slug: "navigation-test-kitchen",
  name: STORE_NAME,
  description: "ร้านจำลองสำหรับทดสอบการเปลี่ยนหน้า",
  address: "มหาสารคาม",
  cover_path: null,
  logo_path: null,
  delivery_fee: 10,
  is_open: true,
  menu: [{
    id: MENU_ID,
    store_id: STORE_ID,
    category: "อาหารจานเดียว",
    name: MENU_NAME,
    description: "เมนูจำลอง ไม่ได้สั่งอาหารจริง",
    price: 50,
    image_path: null,
    sold_out_until: null,
    daily_stock_limit: null,
    options: [
      {
        id: "spice",
        name: "ระดับความเผ็ด",
        required: true,
        max_select: 1,
        choices: [{ id: "mild", name: "เผ็ดน้อย", price: 0 }],
      },
      {
        id: "size",
        name: "ขนาด",
        required: true,
        max_select: 1,
        choices: [
          { id: "regular", name: "ธรรมดา", price: 0 },
          { id: "large", name: "พิเศษ", price: 10 },
        ],
      },
    ],
  }],
}];

async function mockGuestCatalog(page: Page) {
  const audit = { pageErrors: [] as string[], unexpectedRequests: [] as string[], catalogReads: 0 };
  page.on("pageerror", (error) => audit.pageErrors.push(error.message));
  // Intercept the whole Supabase boundary, including a mistakenly introduced
  // private endpoint. These guest journeys must never reach a live database.
  await page.route(/\/(?:auth|rest|storage|functions|realtime)\/v1(?:\/|$)/, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (request.method() === "OPTIONS") {
      await route.fulfill({
        status: 204,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-headers": "*",
          "access-control-allow-methods": "GET, POST, OPTIONS",
        },
      });
      return;
    }
    if (url.pathname === "/rest/v1/rpc/food_public_catalog" && request.method() === "POST") {
      audit.catalogReads += 1;
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(catalog) });
      return;
    }
    audit.unexpectedRequests.push(`${request.method()} ${url.pathname}`);
    await route.fulfill({
      status: 403,
      contentType: "application/json",
      body: JSON.stringify({ message: "Unexpected Supabase request in guest navigation test" }),
    });
  });
  return audit;
}

async function openFreshFoodSession(page: Page) {
  await page.goto("/food");
  await expect(page.getByRole("button", { name: new RegExp(STORE_NAME) })).toBeVisible();
  // Do not seed the splash-seen flag. The original crash happened after the
  // first launch splash removed a head node that React had adopted.
  await expect(page.locator("html")).not.toHaveAttribute("data-fx-splash", "seen");
  await expect(page.locator("html")).toHaveAttribute("data-fx-splash-ready", "");
  await expect(page.locator(".fx-splash")).toBeHidden();
}

async function expectLogin(page: Page) {
  await expect(page).toHaveURL(/\/food\/login$/);
  await expect(page.getByRole("heading", { name: "เข้าสู่ระบบ ZOKY", exact: true })).toBeVisible();
  await expect(page.locator('input[type="email"]')).toHaveCount(1);
  await waitForSettledRoute(page.locator('input[type="email"]'));
  await expect(page.locator('input[type="password"]')).toBeVisible();
  await expect(page).toHaveTitle("เข้าสู่ระบบ — ZOKY");
}

test.describe("ZOKY first-session navigation", () => {
  // page.route cannot intercept requests taken over by an installed worker.
  // Each test otherwise uses Playwright's clean default storage/context.
  test.use({ serviceWorkers: "block" });

  test("the first splash does not break top login, signup, or browser back", async ({ page }) => {
    const audit = await mockGuestCatalog(page);
    await openFreshFoodSession(page);

    await page.getByRole("link", { name: "เข้าสู่ระบบ", exact: true }).click();
    await expectLogin(page);
    await page.getByRole("link", { name: "สมัคร ZOKY", exact: true }).click();
    await expect(page).toHaveURL(/\/food\/signup$/);
    await expect(page.getByRole("heading", { name: "สมัคร ZOKY", exact: true })).toBeVisible();
    await expect(page.locator('input[type="email"]')).toHaveCount(1);
    await waitForSettledRoute(page.locator('input[type="email"]'));
    await expect(page.locator('input[type="password"]')).toHaveCount(2);

    await page.goBack();
    await expectLogin(page);
    expect(audit.catalogReads).toBeGreaterThan(0);
    expect(audit.unexpectedRequests).toEqual([]);
    expect(audit.pageErrors).toEqual([]);
  });

  test("a guest can select required options and keep a two-item basket through login navigation", async ({ page }) => {
    const audit = await mockGuestCatalog(page);
    await openFreshFoodSession(page);
    await page.getByRole("button", { name: new RegExp(STORE_NAME) }).click();
    await expect(page.getByRole("heading", { name: STORE_NAME, exact: true })).toBeVisible();
    await page.getByRole("button", { name: new RegExp(`^${MENU_NAME}`) }).click();

    const item = page.getByRole("dialog", { name: MENU_NAME, exact: true });
    await expect(item).toBeVisible();
    await expect(item.getByRole("button", { name: "เลือกตัวเลือกที่จำเป็นก่อน", exact: true })).toBeDisabled();
    await item.getByRole("radio", { name: "เผ็ดน้อย", exact: true }).click();
    await expect(item.getByRole("radio", { name: "เผ็ดน้อย", exact: true })).toBeChecked();
    await expect(item.getByRole("button", { name: "เลือกตัวเลือกที่จำเป็นก่อน", exact: true })).toBeDisabled();
    await item.getByRole("radio", { name: /^พิเศษ/ }).click();
    await expect(item.getByRole("radio", { name: /^พิเศษ/ })).toBeChecked();
    await item.getByRole("button", { name: "เพิ่มจำนวน", exact: true }).click();
    await item.getByPlaceholder("เช่น ไม่ใส่ผัก, แยกน้ำจิ้ม").fill("ไม่ใส่ต้นหอม");
    await item.getByRole("button", { name: /เพิ่มลงตะกร้า.*฿120/ }).click();
    await expect(item).toBeHidden();

    await page.getByRole("button", { name: /ดูตะกร้า 2 รายการ ฿120/ }).click();
    const cart = page.getByRole("dialog", { name: "ตะกร้าอาหาร", exact: true });
    await expect(cart).toBeVisible();
    await expect(cart.getByText(MENU_NAME, { exact: true })).toBeVisible();
    await expect(cart.getByText("เผ็ดน้อย · พิเศษ", { exact: true })).toBeVisible();
    await expect(cart.getByText("หมายเหตุ · ไม่ใส่ต้นหอม", { exact: true })).toBeVisible();
    await expect(cart.locator('.fx-stepper [aria-live="polite"]')).toHaveText("2");
    await expect(cart.getByText("ยอดอาหารโดยประมาณ ฿120", { exact: true })).toBeVisible();

    const savedBasket = await page.evaluate((key) => JSON.parse(sessionStorage.getItem(key) ?? "null"), GUEST_BASKET_KEY);
    expect(savedBasket).toEqual({
      storeId: STORE_ID,
      lines: [{
        menu_item_id: MENU_ID,
        quantity: 2,
        note: "ไม่ใส่ต้นหอม",
        selected_options: [
          { group_id: "spice", group_name: "ระดับความเผ็ด", choice_id: "mild", choice_name: "เผ็ดน้อย", price: 0 },
          { group_id: "size", group_name: "ขนาด", choice_id: "large", choice_name: "พิเศษ", price: 10 },
        ],
      }],
    });
    await cart.getByRole("button", { name: "เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ", exact: true }).click();
    await expectLogin(page);
    expect(await page.evaluate((key) => JSON.parse(sessionStorage.getItem(key) ?? "null"), GUEST_BASKET_KEY)).toEqual(savedBasket);

    // Browser back remounts guest browsing: verify the saved basket still
    // renders, rather than checking storage alone or submitting a real order.
    await page.goBack();
    await page.getByRole("button", { name: /ดูตะกร้า 2 รายการ ฿120/ }).click();
    await expect(cart.getByText(MENU_NAME, { exact: true })).toBeVisible();
    await expect(cart.getByText("เผ็ดน้อย · พิเศษ", { exact: true })).toBeVisible();
    await expect(cart.locator('.fx-stepper [aria-live="polite"]')).toHaveText("2");
    await expect(cart.getByText("ยอดอาหารโดยประมาณ ฿120", { exact: true })).toBeVisible();
    expect(audit.catalogReads).toBeGreaterThan(0);
    expect(audit.unexpectedRequests).toEqual([]);
    expect(audit.pageErrors).toEqual([]);
  });
});
