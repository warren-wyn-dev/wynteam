import { expect, test } from "@playwright/test";

/**
 * WYNOS Web Beta1, item 9: every follow/unfollow button now shares one
 * label function. "กำลังติดตาม" ("currently following") used to be the
 * label for an already-following button — it reads like an in-progress
 * action on a tappable element, indistinguishable from the system still
 * working. A pending request now shows "กำลังดำเนินการ…" (a real busy
 * state, previously missing entirely — the button just went disabled with
 * no visible change), and a completed follow shows the unambiguous
 * "ติดตามแล้ว" instead.
 */
test("idle (not following) shows ติดตาม", async ({ page }) => {
  await page.goto("/dev/follow-button-fixture", { waitUntil: "networkidle" });
  await expect(page.locator("#state-idle")).toHaveText("ติดตาม");
});

test("a pending request shows a busy state, not silence", async ({ page }) => {
  await page.goto("/dev/follow-button-fixture", { waitUntil: "networkidle" });
  await expect(page.locator("#state-busy")).toHaveText("กำลังดำเนินการ…");
});

test("a completed follow shows ติดตามแล้ว, not the ambiguous กำลังติดตาม", async ({ page }) => {
  await page.goto("/dev/follow-button-fixture", { waitUntil: "networkidle" });
  await expect(page.locator("#state-following")).toHaveText("ติดตามแล้ว");
  await expect(page.locator("#state-following")).not.toContainText("กำลังติดตาม");
});

test("a pending follow request (private account) shows ขอติดตามแล้ว", async ({ page }) => {
  await page.goto("/dev/follow-button-fixture", { waitUntil: "networkidle" });
  await expect(page.locator("#state-requested")).toHaveText("ขอติดตามแล้ว");
});

test("busy always wins over the following state (e.g. mid-unfollow)", async ({ page }) => {
  await page.goto("/dev/follow-button-fixture", { waitUntil: "networkidle" });
  await expect(page.locator("#state-busy-while-following")).toHaveText("กำลังดำเนินการ…");
});
