import { expect, test, type Page } from "@playwright/test";

// WYN-159 (Beta2, developer-only): Threads-style chat. The fixture renders the
// real ConversationThread / MessageActionMenu with sample messages.
test.skip(Boolean(process.env.PLAYWRIGHT_BASE_URL), "dev-server-only fixture");

async function hold(page: Page, index: number) {
  const box = await page.locator(".message-bubble").nth(index).boundingBox();
  if (!box) throw new Error("bubble not rendered");
  await page.mouse.move(box.x + 20, box.y + 10);
  await page.mouse.down();
  await page.waitForTimeout(600);
  await page.mouse.up();
}

test("Web Beta1 thread is unchanged when the Beta2 feature is off", async ({ page }) => {
  await page.goto("/dev/chat-threads-fixture");
  await expect(page.locator(".message-row")).toHaveCount(7);
  await expect(page.locator('.message-row[class*="group-"]')).toHaveCount(0);
  await expect(page.locator(".message-meta time")).toHaveCount(7);
});

test("messages from one sender within a minute are grouped with one avatar", async ({ page }) => {
  await page.goto("/dev/chat-threads-fixture?threads=1");
  const rows = page.locator(".message-row");
  await expect(rows.nth(0)).toHaveClass(/group-first/);
  await expect(rows.nth(1)).toHaveClass(/group-middle/);
  await expect(rows.nth(2)).toHaveClass(/group-last/);
  await expect(rows.nth(3)).toHaveClass(/group-single/);
  await expect(rows.nth(0).locator(".route-avatar")).toHaveCount(0);
  await expect(rows.nth(2).locator(".route-avatar")).toHaveCount(1);
  // Time is hidden until tapped; one receipt, under the latest outgoing message.
  await expect(page.locator(".message-meta time")).toHaveCount(0);
  await expect(page.locator(".message-read-status")).toHaveCount(1);
  await page.locator(".message-bubble").nth(1).click();
  await expect(page.locator(".message-meta time")).toHaveCount(1);
  await expect(page.locator(".message-delete")).toHaveCount(0);
});

test("holding your own message opens reactions and the full menu", async ({ page }) => {
  await page.goto("/dev/chat-threads-fixture?threads=1");
  await hold(page, 6);
  await expect(page.locator(".message-reaction-bar button")).toHaveCount(6);
  await expect(page.locator(".message-action-menu button")).toHaveText(["ตอบกลับ", "แก้ไข", "ส่งต่อ", "คัดลอก", "ลบสำหรับคุณ", "ยกเลิกการส่ง", "เพิ่มเติม"]);
  await page.locator(".message-action-menu button.more").click();
  await expect(page.locator(".message-action-menu button")).toHaveText(["กลับ", "ปักหมุด"]);
});

test("someone else's message: no edit or unsend, report under more", async ({ page }) => {
  await page.goto("/dev/chat-threads-fixture?threads=1");
  await hold(page, 4);
  await expect(page.locator(".message-action-menu button")).toHaveText(["ตอบกลับ", "ส่งต่อ", "คัดลอก", "ลบสำหรับคุณ", "เพิ่มเติม"]);
  await page.locator(".message-action-menu button.more").click();
  await expect(page.locator(".message-action-menu button")).toHaveText(["กลับ", "เลิกปักหมุด", "รายงาน"]);
});

test("a reaction shows under the message and the same emoji again removes it", async ({ page }) => {
  await page.goto("/dev/chat-threads-fixture?threads=1");
  await hold(page, 6);
  await page.locator(".message-reaction-bar button", { hasText: "👍" }).click();
  const last = page.locator(".message-row").nth(6);
  await expect(last.locator(".message-reactions")).toHaveText("👍");
  await hold(page, 6);
  await page.locator(".message-reaction-bar button", { hasText: "👍" }).click();
  await expect(last.locator(".message-reactions")).toHaveCount(0);
});
