import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

test("WYN-135 Club chat uses the developer-only gate; Beta1 actions are unchanged", () => {
  const source = readFileSync(join(process.cwd(), "components/club-detail-golden.tsx"), "utf8");
  expect(source).toContain('useBeta2Feature("clubChatActions", client, userId)');
  expect(source).toContain('beta2 ? setMenuMessage(message)');
  expect(source).toContain('beta2 ? ",edited_at,pinned_at" : ""');
  expect(source).toContain("const request = ++reloadSequence.current");
  expect(source).toContain("const jumpRequest = ++jumpSequence.current");
  expect(source).toContain("const isCurrentJump = () => jumpRequest === jumpSequence.current");
  expect(source).toContain("if (!isCurrentJump()) return;");
  expect(source).toContain("jumpSequence.current += 1; setChannelId(id)");
  expect(source).toContain("activeView.current.beta2 === beta2");
  expect(source).toContain("window.setInterval");
  expect(source).toContain('if (!beta2 || !channelId || membership?.status !== "approved") return');
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

  test("search results from an old input cannot replace the newer query", async ({ page }) => {
    await page.goto("/dev/club-chat-actions-fixture?role=owner&slow=1");
    await page.getByRole("button", { name: "ค้นหาข้อความ", exact: true }).click();
    const query = page.getByRole("textbox", { name: "ค้นหาข้อความในห้องนี้" });
    await query.fill("hello");
    await page.getByRole("button", { name: "ค้นหา", exact: true }).click();
    await query.fill("rules");
    await page.getByRole("button", { name: "ค้นหา", exact: true }).click();
    await expect(page.getByRole("button", { name: /please read the rules/ })).toBeVisible();
    await page.waitForTimeout(650); // Let the older "hello" request arrive last.
    await expect(page.getByRole("button", { name: /hello club chat/ })).toHaveCount(0);
    await expect(query).toHaveValue("rules");
  });

  test("short Thai searches return only messages in the open channel", async ({ page }) => {
    await page.goto("/dev/club-chat-actions-fixture?role=member");
    await page.getByRole("button", { name: "ค้นหาข้อความ", exact: true }).click();
    const query = page.getByRole("textbox", { name: "ค้นหาข้อความในห้องนี้" });
    for (const term of ["ดี", "ไป"]) {
      await query.fill(term);
      await page.getByRole("button", { name: "ค้นหา", exact: true }).click();
      await expect(page.getByRole("button", { name: /สวัสดีครับ ไปไหนกัน/ })).toHaveCount(1);
      await expect(page.getByRole("button", { name: /สวัสดีจากห้องอื่น/ })).toHaveCount(0);
    }
  });

  test("pinned-message read failures can be retried without clearing channel search", async ({ page }) => {
    await page.goto("/dev/club-chat-actions-fixture?role=owner&pin-error=1");
    const pinError = page.locator(".golden-club-pin-error");
    await expect(pinError).toContainText("โหลดข้อความที่ปักหมุดไม่สำเร็จ");

    await page.getByRole("button", { name: "ค้นหาข้อความ", exact: true }).click();
    await page.getByRole("textbox", { name: "ค้นหาข้อความในห้องนี้" }).fill("rules");
    await page.getByRole("button", { name: "ค้นหา", exact: true }).click();
    await expect(page.getByRole("button", { name: /please read the rules/ })).toBeVisible();
    await expect(pinError).toBeVisible();

    await pinError.getByRole("button", { name: "ลองอีกครั้ง" }).click();
    // The error is cleared synchronously on click, so prove the retry
    // actually completed by waiting for a known pinned message to load.
    await expect(page.locator(".golden-club-pinned-list").getByRole("button", { name: /retry pin loaded/ })).toBeVisible();
    await expect(pinError).toHaveCount(0);
    await expect(page.getByRole("button", { name: /please read the rules/ })).toBeVisible();
  });

  test("mobile search clears an in-flight request and keeps the search keyboard hint", async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 812 });
    await page.goto("/dev/club-chat-actions-fixture?role=member&slow=1");
    await page.getByRole("button", { name: "ค้นหาข้อความ", exact: true }).click();
    const query = page.getByRole("textbox", { name: "ค้นหาข้อความในห้องนี้" });
    await expect(query).toHaveAttribute("inputmode", "search");
    await expect(query).toHaveAttribute("enterkeyhint", "search");
    await query.fill("hello");
    await page.getByRole("button", { name: "ค้นหา", exact: true }).click();

    const clear = page.getByRole("button", { name: "ล้างคำค้นหา" });
    await expect.poll(async () => (await clear.boundingBox())?.height ?? 0).toBeGreaterThanOrEqual(44);
    await clear.click();
    await expect(query).toHaveValue("");
    await expect(clear).toHaveCount(0);
    await page.waitForTimeout(650); // Late "hello" must not restore cleared results.
    await expect(page.getByRole("button", { name: /hello club chat/ })).toHaveCount(0);

    await query.fill("rules");
    await page.getByRole("button", { name: "ค้นหา", exact: true }).click();
    await expect(page.getByRole("button", { name: /please read the rules/ })).toBeVisible();
  });

  test("mobile search and pin controls offer 44px touch targets", async ({ page }) => {
    await page.goto("/dev/club-chat-actions-fixture?role=owner");
    const search = page.getByRole("button", { name: "ค้นหาข้อความ", exact: true });
    await expect.poll(async () => (await search.boundingBox())?.height ?? 0).toBeGreaterThanOrEqual(44);
    await page.getByRole("button", { name: "ตัวเลือกข้อความตัวอย่าง" }).click();
    await page.getByRole("button", { name: "ปักหมุดข้อความ" }).click();
    const pin = page.getByRole("button", { name: /hello club chat/ });
    await expect.poll(async () => (await pin.boundingBox())?.height ?? 0).toBeGreaterThanOrEqual(44);
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
