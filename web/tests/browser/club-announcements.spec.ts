import { expect, test, type Page } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

// WYN-137 (Beta2): Club announcements tab, against an in-memory client.
async function open(page: Page, query: string) {
  await page.goto(`/dev/club-announcements-fixture?${query}`, { waitUntil: "domcontentloaded" });
  const tab = page.getByRole("region", { name: "ประกาศ" });
  await expect(tab).toBeVisible();
  // Server HTML is visible before React attaches handlers.
  await expect.poll(() => tab.evaluate((el) => Object.keys(el).some((key) => key.startsWith("__reactFiber$")))).toBe(true);
  return tab;
}

test("the Club page shows the tab only through the Beta2 gate", () => {
  const page = readFileSync(join(process.cwd(), "components/club-detail-golden.tsx"), "utf8");
  expect(page).toContain('useBeta2Feature("clubAnnouncements", client, userId)');
  expect(page).toContain('{announcementsOn ? <button className={tab === "announcements"');
  expect(page).toContain('tab === "announcements" && announcementsOn ?');
});

test.describe("fixture", () => {
  test.skip(Boolean(process.env.PLAYWRIGHT_BASE_URL), "dev-server-only fixture");

  test("staff post an announcement; it appears first and the members are told", async ({ page }) => {
    const tab = await open(page, "role=owner");
    await expect(tab.locator(".club-announcement-card")).toHaveCount(2);
    await tab.getByRole("button", { name: "เขียนประกาศถึงสมาชิก" }).click();
    const sheet = page.getByRole("dialog", { name: "เขียนประกาศ" });
    await expect(sheet.getByText("ประกาศจะแสดงในแท็บประกาศของ Club")).toBeVisible();
    await expect(sheet.getByRole("button", { name: "ส่งประกาศ", exact: true })).toBeDisabled();
    await sheet.getByRole("textbox", { name: "ข้อความประกาศ" }).fill("งดกิจกรรมวันอาทิตย์นี้");
    await sheet.getByRole("button", { name: "ส่งประกาศ", exact: true }).click();
    await expect(sheet).toBeHidden();
    await expect(tab.locator(".club-announcement-card").first()).toContainText("งดกิจกรรมวันอาทิตย์นี้");
    await expect(page.getByText("ประกาศแล้ว", { exact: true })).toBeVisible();
  });

  test("the author edits their own announcement and it is marked edited", async ({ page }) => {
    const tab = await open(page, "role=owner");
    const mine = tab.locator(".club-announcement-card").filter({ hasText: "นัดถ่ายรูป" });
    await expect(mine.getByText("แก้ไขแล้ว")).toHaveCount(0);
    await mine.getByRole("button", { name: "ตัวเลือกประกาศ" }).click();
    await page.getByRole("button", { name: "แก้ไขประกาศ" }).click();
    const sheet = page.getByRole("dialog", { name: "แก้ไขประกาศ" });
    await sheet.getByRole("textbox", { name: "ข้อความประกาศ" }).fill("เลื่อนเป็น 10 โมง");
    await sheet.getByRole("button", { name: "บันทึก", exact: true }).click();
    const edited = tab.locator(".club-announcement-card").filter({ hasText: "เลื่อนเป็น 10 โมง" });
    await expect(edited.getByText("แก้ไขแล้ว")).toBeVisible();
  });

  test("an owner can delete a moderator's announcement but not edit it", async ({ page }) => {
    const tab = await open(page, "role=owner");
    const theirs = tab.locator(".club-announcement-card").filter({ hasText: "กติกาใหม่" });
    await theirs.getByRole("button", { name: "ตัวเลือกประกาศ" }).click();
    await expect(page.getByRole("button", { name: "แก้ไขประกาศ" })).toHaveCount(0);
    page.once("dialog", (dialog) => void dialog.accept());
    await page.getByRole("button", { name: "ลบประกาศ" }).click();
    await expect(tab.locator(".club-announcement-card")).toHaveCount(1);
  });

  test("a moderator manages only their own announcements", async ({ page }) => {
    // In the fixture the viewer is always the owner's account; as a
    // moderator viewer, the other author's card has no options.
    const tab = await open(page, "role=moderator");
    const other = tab.locator(".club-announcement-card").filter({ hasText: "กติกาใหม่" });
    await expect(other.getByRole("button", { name: "ตัวเลือกประกาศ" })).toHaveCount(0);
    await expect(tab.getByRole("button", { name: "เขียนประกาศถึงสมาชิก" })).toBeVisible();
  });

  test("members read announcements but cannot post or manage them", async ({ page }) => {
    const tab = await open(page, "role=member");
    await expect(tab.locator(".club-announcement-card")).toHaveCount(2);
    await expect(tab.getByRole("button", { name: "เขียนประกาศถึงสมาชิก" })).toHaveCount(0);
    const mine = tab.locator(".club-announcement-card").filter({ hasText: "นัดถ่ายรูป" });
    // A demoted author can still delete what they wrote, but not edit it.
    await mine.getByRole("button", { name: "ตัวเลือกประกาศ" }).click();
    await expect(page.getByRole("button", { name: "แก้ไขประกาศ" })).toHaveCount(0);
    await expect(page.getByRole("button", { name: "ลบประกาศ" })).toBeVisible();
  });

  test("empty states differ for staff and members", async ({ page }) => {
    let tab = await open(page, "role=owner&empty=1");
    await expect(tab.getByText("ยังไม่มีประกาศ เขียนประกาศแรกให้สมาชิกได้เลย")).toBeVisible();
    tab = await open(page, "role=member&empty=1");
    await expect(tab.getByText("ยังไม่มีประกาศจาก Club นี้")).toBeVisible();
  });
});
