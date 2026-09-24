import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const source = (name: string) => readFileSync(join(process.cwd(), name), "utf8");

test("Food customer preview is strictly developer-only and has no real orders or payments", () => {
  const gate = source("components/food/wynos-food-preview-route.tsx");
  expect(gate).toContain('client.rpc("is_developer_account")');
  expect(gate).toContain('!error && data === true ? "allowed" : "denied"');
  expect(gate).toContain('if (access !== "allowed")');
  expect(gate).toContain('router.replace("/")');
  const demo = source("components/food/food-demo-app.tsx");
  expect(demo).not.toContain(".from(");
  expect(demo).not.toContain(".invoke(");
  expect(demo).not.toContain("fetch(");
  expect(demo).toContain("จำลองการสั่งซื้อ");
  const fixture = source("app/dev/food-fixture/page.tsx");
  expect(fixture).toContain('if (process.env.NODE_ENV === "production") redirect("/")');
  expect(source("app/food/page.tsx")).toContain("index: false");
});

test.describe("WYNOS Food mobile customer UX demo", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/dev/food-fixture", { waitUntil: "domcontentloaded" });
    await expect(page.getByTestId("wynos-food-customer-demo")).toBeVisible();
  });

  test("home, search, multiple stores and restaurant detail are navigable", async ({ page }) => {
    await expect(page.getByText("DEVELOPER PREVIEW")).toBeVisible();
    await expect(page.locator(".wfd-card")).toHaveCount(2);
    await page.getByRole("button", { name: /ค้นหาร้านอาหาร เมนู/ }).click();
    await page.getByRole("textbox", { name: "ค้นหาร้านอาหารหรือเมนู" }).fill("ไก่ทอด");
    await expect(page.locator(".wfd-listing")).toHaveCount(3);
    await page.getByRole("button", { name: /ไก่ทอดเดโม่/ }).first().click();
    await expect(page.getByRole("heading", { name: "ไก่ทอดเดโม่" })).toBeVisible();
    await page.getByRole("button", { name: "ดูรายละเอียด ไก่ทอดกรอบ" }).click();
    await expect(page.getByRole("heading", { name: "ไก่ทอดกรอบ" })).toBeVisible();
  });

  test("item customization, multi-store cart and no-payment checkout simulation", async ({ page }) => {
    await page.getByRole("button", { name: /ตำแซ่บเดโม่/ }).first().click();
    await page.getByRole("button", { name: "ดูรายละเอียด ตำป่า" }).click();
    await page.getByLabel("เผ็ดมาก", { exact: true }).check();
    await page.getByLabel("ขนมจีน", { exact: false }).check();
    await page.getByRole("button", { name: /เพิ่มลงตะกร้า/ }).click();
    await expect(page.getByRole("heading", { name: /ตะกร้าสินค้า/ })).toBeVisible();
    await expect(page.locator(".wfd-cart-group")).toHaveCount(2);
    await page.getByRole("button", { name: /ไปชำระเงิน/ }).click();
    await expect(page.getByRole("heading", { name: "ชำระเงิน (ทดลอง)" })).toBeVisible();
    await page.getByRole("textbox", { name: "รหัสคูปอง" }).fill("DEMO20");
    await page.getByRole("button", { name: "ใช้", exact: true }).click();
    await page.getByRole("button", { name: /จำลองการสั่งซื้อ/ }).click();
    await expect(page.getByText("สถานะคำสั่งซื้อ")).toBeVisible();
    await page.getByRole("button", { name: /จำลองสถานะถัดไป/ }).click();
    await expect(page.getByText("กำลังทำอาหาร")).toBeVisible();
  });

  test("favorites, profile, history and social navigation remain available", async ({ page }) => {
    await page.getByRole("button", { name: "ร้านโปรด" }).click();
    await expect(page.getByRole("heading", { name: "ร้านโปรด" })).toBeVisible();
    await page.getByRole("button", { name: "โปรไฟล์" }).click();
    await expect(page.getByRole("heading", { name: "โปรไฟล์และตั้งค่า" })).toBeVisible();
    await page.getByRole("button", { name: /ประวัติการสั่งซื้อ/ }).click();
    await expect(page.getByRole("heading", { name: "ประวัติการสั่งซื้อ" })).toBeVisible();
    await expect(page.getByText("WF-000123")).toBeVisible();
  });
});
