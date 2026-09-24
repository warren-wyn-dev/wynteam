import { readFile } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";

test.describe("Real post composer caption spacing", () => {
  test.use({ serviceWorkers: "block" });

  test("attaching an image leaves no blank caption block, and text grows naturally", async ({ page }) => {
    await page.goto("/dev/composer-fixture");
    const composer = page.getByRole("dialog", { name: "สร้างโพสต์" });
    const caption = composer.locator("textarea.beta4-compose-text");
    await expect(caption).toBeVisible();

    const before = await caption.boundingBox();
    expect(before).not.toBeNull();
    expect(before!.height).toBeLessThanOrEqual(32);

    await composer.locator('input[type="file"][multiple]').setInputFiles({
      name: "post.png",
      mimeType: "image/png",
      buffer: await readFile(path.join(process.cwd(), "public/wynos_logo_mark.png")),
    });
    const preview = composer.locator(".beta4-image-preview").first();
    await expect(preview).toBeVisible();

    const gap = await page.evaluate(() => {
      const text = document.querySelector(".beta4-compose-text")!.getBoundingClientRect();
      const photo = document.querySelector(".beta4-image-preview")!.getBoundingClientRect();
      return photo.top - text.bottom;
    });
    expect(gap).toBeGreaterThanOrEqual(0);
    expect(gap).toBeLessThanOrEqual(25);

    await caption.fill("บรรทัดที่หนึ่ง\nบรรทัดที่สอง\nบรรทัดที่สาม");
    await expect.poll(async () => (await caption.boundingBox())?.height ?? 0).toBeGreaterThan(before!.height);
    const expanded = await caption.boundingBox();
    expect(expanded!.height).toBeLessThanOrEqual(168);

    await caption.fill("");
    await expect.poll(async () => (await caption.boundingBox())?.height ?? 999).toBeLessThanOrEqual(32);
  });

  test("the actual composer—not the legacy reference mock—owns the compact text rule", async () => {
    const [component, css] = await Promise.all([
      readFile(path.join(process.cwd(), "components/beta4-composer.tsx"), "utf8"),
      readFile(path.join(process.cwd(), "components/beta4-composer-refresh.module.css"), "utf8"),
    ]);
    expect(component).toContain('className={`beta4-compose-text ${styles.composeText}`}');
    expect(component).toContain('rows={1}');
    expect(css).toContain("min-height: 28px !important;");
    expect(css).not.toContain("min-height: 86px !important;");
  });
});
