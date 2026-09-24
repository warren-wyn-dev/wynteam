import { readFile } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";

// The real compose modal requires a signed-in account. Guard the precise
// mobile layout behavior here without creating posts or touching user data.
test("image composer keeps the empty caption to one line and expands with typing", async ({ page }) => {
  const root = process.cwd();
  const [component, css] = await Promise.all([
    readFile(path.join(root, "components/beta4-composer.tsx"), "utf8"),
    readFile(path.join(root, "components/beta4-composer-refresh.module.css"), "utf8"),
  ]);
  expect(component).toContain('const hasAttachedMedia = mode === "image" && (files.length > 0 || Boolean(existingImageUrl))');
  expect(component).toContain("useLayoutEffect(() => {");
  expect(component).toContain('textarea.style.height = "0px"');
  expect(component).toContain("textarea.scrollHeight");
  expect(component).toContain("[caption, hasAttachedMedia, mode]");
  expect(component).toContain("hasAttachedMedia ? styles.attachedCaption");
  expect(component).toContain("rows={1}");
  expect(css).toMatch(/\.attachedCaption\s*\{[^}]*min-height:\s*32px\s*!important/);
  expect(css).toMatch(/\.composeText\s*\{[^}]*overflow-y:\s*hidden\s*!important/);

  // Browser geometry smoke: the one-line attached-media rule does not reserve
  // 86px above a photo and a longer caption can grow without overlap.
  await page.goto("/welcome");
  const result = await page.evaluate(() => {
    const textarea = document.createElement("textarea");
    textarea.rows = 1;
    Object.assign(textarea.style, {
      width: "300px", boxSizing: "border-box", minHeight: "32px",
      padding: "0", margin: "0", lineHeight: "22.4px",
      fontSize: "16px", resize: "none", overflowY: "hidden",
    });
    document.body.appendChild(textarea);
    const resize = () => {
      textarea.style.height = "0px";
      textarea.style.height = `${Math.max(32, textarea.scrollHeight)}px`;
      return textarea.getBoundingClientRect().height;
    };
    const empty = resize();
    textarea.value = "บรรทัดแรก\nบรรทัดสอง\nบรรทัดสาม\nบรรทัดสี่";
    const multiline = resize();
    textarea.remove();
    return { empty, multiline };
  });
  expect(result.empty).toBeLessThanOrEqual(34);
  expect(result.multiline).toBeGreaterThan(result.empty + 30);
});
