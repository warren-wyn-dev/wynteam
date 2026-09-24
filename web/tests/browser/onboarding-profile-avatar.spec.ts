import { readFile } from "node:fs/promises";
import path from "node:path";
import { expect, test, type Page } from "@playwright/test";

test.describe("Onboarding avatar: photo picker and interactive zoom/crop", () => {
  test.use({ serviceWorkers: "block" }); // Safari may have an old PWA worker installed.

  async function pickPhoto(page: Page) {
    const fileChooser = page.waitForEvent("filechooser");
    await page.getByRole("button", { name: "เลือกรูปโปรไฟล์" }).click();
    const picker = await fileChooser;
    await picker.setFiles({
      name: "profile.png",
      mimeType: "image/png",
      buffer: await readFile(path.join(process.cwd(), "public/wynos_logo_mark.png")),
    });
    const crop = page.getByRole("dialog", { name: "ปรับรูปโปรไฟล์" });
    await expect(crop).toBeVisible();
    await expect(crop.getByRole("button", { name: "ใช้รูปนี้" })).toBeEnabled();
    return crop;
  }

  test("onboarding camera opens native picker, zooms, drags and previews the cropped image", async ({ page }) => {
    await page.goto("/onboarding/profile");
    const crop = await pickPhoto(page);
    const slider = crop.getByLabel("ซูมรูปโปรไฟล์");
    await expect(slider).toHaveValue("1");
    await slider.focus();
    await slider.press("End");
    await expect(slider).toHaveValue("4");

    const image = crop.locator(".wyn-photo-crop-image");
    const before = await image.evaluate((node) => (node as HTMLElement).style.left);
    const stage = crop.locator(".wyn-photo-crop-viewport");
    const box = await stage.boundingBox();
    expect(box).not.toBeNull();
    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.move(box!.x + box!.width / 2 + 45, box!.y + box!.height / 2 + 12, { steps: 5 });
    await page.mouse.up();
    await expect.poll(() => image.evaluate((node) => (node as HTMLElement).style.left)).not.toBe(before);

    await crop.getByRole("button", { name: "ใช้รูปนี้" }).click();
    await expect(crop).toHaveCount(0);
    const photo = page.locator(".wyn-onboarding-avatar-button .wyn-avatar");
    await expect.poll(() => photo.evaluate((node) => getComputedStyle(node).backgroundImage)).toContain("blob:");
    await expect(page.getByRole("button", { name: "เริ่มใช้งาน Wynos" })).toBeEnabled();
  });

  test("cancelling the photo editor does not change the avatar", async ({ page }) => {
    await page.goto("/onboarding/profile");
    const crop = await pickPhoto(page);
    await crop.getByRole("button", { name: "ยกเลิก" }).click();
    await expect(crop).toHaveCount(0);
    await expect(page.locator(".wyn-onboarding-avatar-button .wyn-avatar")).not.toHaveCSS("background-image", /blob:/);
  });

  test("a file that is not an image is rejected before opening the cropper", async ({ page }) => {
    await page.goto("/onboarding/profile");
    await page.locator('input[aria-label="อัปโหลดรูปโปรไฟล์"]').setInputFiles({
      name: "not-a-photo.pdf",
      mimeType: "application/pdf",
      buffer: Buffer.from("%PDF-1.4"),
    });
    await expect(page.getByText("กรุณาเลือกไฟล์รูปภาพ")).toBeVisible();
    await expect(page.getByRole("dialog", { name: "ปรับรูปโปรไฟล์" })).toHaveCount(0);
  });
});
