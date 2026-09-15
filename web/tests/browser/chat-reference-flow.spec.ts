import { expect, test } from "@playwright/test";

test("chat list rows route to their own conversation ids", async ({ page }) => {
  await page.goto("/chat");
  await expect(page.locator('[data-conversation-id="ton-tech"]')).toContainText("ต้น สายเทค");
  await expect(page.locator('[data-conversation-id="mind-coffee"]')).toContainText("มายด์ กาแฟรัก");

  await page.locator('[data-conversation-id="ton-tech"]').click();
  await expect(page).toHaveURL(/\/chat\/ton-tech$/);
  await expect(page.locator('.chat-conversation-scroll[data-conversation-id="ton-tech"]')).toBeVisible();

  await page.goto("/chat");
  await page.locator('[data-conversation-id="mind-coffee"]').click();
  await expect(page).toHaveURL(/\/chat\/mind-coffee$/);
  await expect(page.locator('.chat-conversation-scroll[data-conversation-id="mind-coffee"]')).toBeVisible();
});

test("conversation route param selects the matching person", async ({ page }) => {
  await page.goto("/chat/ton-tech");
  await expect(page.locator('.chat-conversation-topbar .t')).toHaveText("ต้น สายเทค");
  await page.goto("/chat/mind-coffee");
  await expect(page.locator('.chat-conversation-topbar .t')).toHaveText("มายด์ กาแฟรัก");
});

test("only read message status uses the WYNOS red", async ({ page }) => {
  await page.goto("/chat/ton-tech");
  const sent = page.locator('[data-message-status="sent"]');
  await expect(sent).toContainText("ส่งแล้ว");
  await expect(sent).toHaveCSS("color", "rgb(154, 154, 154)");

  await page.goto("/chat/mind-coffee");
  const read = page.locator('[data-message-status="read"]');
  await expect(read).toContainText("อ่านแล้ว");
  await expect(read).toHaveCSS("color", "rgb(224, 32, 61)");
});
