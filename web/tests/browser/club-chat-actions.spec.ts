import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

test("WYN-135 Club chat uses the developer-only gate; Beta1 actions are unchanged", () => {
  const source = readFileSync(join(process.cwd(), "components/club-detail-golden.tsx"), "utf8");
  expect(source).toContain('useBeta2Feature("clubChatActions", client, userId)');
  expect(source).toContain('beta2 ? setMenuMessage(message)');
  expect(source).toContain('beta2 ? ",edited_at,pinned_at" : ""');
});

test.describe("local developer-only fixture", () => {
  test.skip(Boolean(process.env.PLAYWRIGHT_BASE_URL), "The fixture cannot be accessed in production");

  test("staff pin/unpin stays within the current channel", async ({ page }) => {
    await page.goto("/dev/club-chat-actions-fixture?role=owner");
    await page.getByRole("button", { name: "ตัวเลือกข้อความตัวอย่าง" }).click();
    await page.getByRole("button", { name: "ปักหมุดข้อความ" }).click();
    await expect(page.getByRole("button", { name: /hello club chat/ })).toHaveCount(1);
    await page.getByRole("button", { name: "ตัวเลือกข้อความตัวอย่าง" }).click();
    await page.getByRole("button", { name: "เลิกปักหมุด" }).click();
    await expect(page.getByRole("button", { name: /hello club chat/ })).toHaveCount(0);
  });

  test("author can edit text and search it in the current channel", async ({ page }) => {
    await page.goto("/dev/club-chat-actions-fixture?role=member");
    await page.getByRole("button", { name: "ตัวเลือกข้อความตัวอย่าง" }).click();
    await expect(page.getByRole("button", { name: "ปักหมุดข้อความ" })).toHaveCount(0);
    await page.getByRole("button", { name: "แก้ไขข้อความ" }).click();
    await page.getByRole("textbox", { name: "ข้อความที่แก้ไข" }).fill("new club update");
    await page.getByRole("button", { name: "บันทึก", exact: true }).click();
    await expect(page.getByTestId("content")).toContainText("new club update");
    await page.getByRole("button", { name: "ค้นหาข้อความ", exact: true }).click();
    await page.getByRole("textbox", { name: "ค้นหาข้อความในห้องนี้" }).fill("new club");
    await page.getByRole("button", { name: "ค้นหา", exact: true }).click();
    await page.getByRole("button", { name: /new club update/ }).click();
    await expect(page.getByTestId("jumped")).toHaveText("m1");
  });

  test("ordinary member cannot manage another author's messages", async ({ page }) => {
    await page.goto("/dev/club-chat-actions-fixture?role=member&mine=0");
    await page.getByRole("button", { name: "ตัวเลือกข้อความตัวอย่าง" }).click();
    const dialog = page.getByRole("dialog", { name: "ตัวเลือกข้อความ" });
    await expect(dialog.getByRole("button", { name: "แก้ไขข้อความ" })).toHaveCount(0);
    await expect(dialog.getByRole("button", { name: "ปักหมุดข้อความ" })).toHaveCount(0);
    await dialog.getByRole("button", { name: "รายงานข้อความ" }).click();
    await expect(page.getByText("รายงานแล้ว")).toBeVisible();
  });
});
