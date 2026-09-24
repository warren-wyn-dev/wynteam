import { readFile } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";

const PALETTE_PATH = path.join(process.cwd(), "app/comment-neutral.css");

test("quote and regular post inputs use neutral grey and black, never beige", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "light" });
  const css = await readFile(PALETTE_PATH, "utf8");
  await page.setContent(
    '<style>:root{--paper:#fff;--surface:#f1efe9;--wyn-bg:#fff;--wyn-surface:#f1efe9;--ink:#12120f}' +
    '.detail-comment-form input,.flutter-detail-composer-field input{background:var(--surface)}' +
    '.detail-comment-form button,.flutter-detail-composer-field button{background:var(--ink)}' +
    '.detail-comment-form,.detail-composer-shell{background:var(--paper)}' +
    '</style><style>' + css + '</style>' +
    '<section class="wyn-quote-comments"><form class="detail-comment-form">' +
    '<input id="quote-input" placeholder="แสดงความคิดเห็นต่อโพสต์อ้างอิง…" />' +
    '<button id="quote-send" type="submit" disabled aria-label="ส่งความคิดเห็น">➤</button>' +
    '</form></section>' +
    '<div class="detail-composer-shell"><form class="detail-comment-form flutter-detail-composer">' +
    '<div class="flutter-detail-composer-field"><input id="post-input" placeholder="แสดงความคิดเห็น..."/>' +
    '<button id="post-send" type="submit" disabled aria-label="ส่งความคิดเห็น">➤</button>' +
    '</div></form></div>'
  );
  for (const target of ["quote", "post"]) {
    const input = page.locator(`#${target}-input`);
    const send = page.locator(`#${target}-send`);
    const result = await input.evaluate((node) => {
      const style = getComputedStyle(node);
      return {
        bg: style.backgroundColor,
        text: style.color,
        border: style.borderTopColor,
        fontSize: style.fontSize,
        placeholder: getComputedStyle(node, "::placeholder").color,
      };
    });
    expect(result.bg).toBe("rgb(242, 243, 245)");
    expect(result.text).toBe("rgb(17, 17, 17)");
    expect(result.border).toBe("rgb(229, 231, 235)");
    expect(result.fontSize).toBe("16px");
    expect(result.placeholder).toBe("rgb(142, 142, 147)");
    expect(await send.evaluate((node) => getComputedStyle(node).backgroundColor)).toBe("rgb(17, 17, 17)");
    expect(await send.evaluate((node) => getComputedStyle(node).color)).toBe("rgb(191, 194, 200)");
    await send.evaluate((node: HTMLButtonElement) => { node.disabled = false; });
    expect(await send.evaluate((node) => getComputedStyle(node).color)).toBe("rgb(255, 255, 255)");
  }
});

test("dark scheme keeps a cool neutral input and high-contrast send control", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "dark" });
  const css = await readFile(PALETTE_PATH, "utf8");
  await page.setContent('<style>' + css + '</style><section class="wyn-quote-comments"><form class="detail-comment-form"><input id="comment" placeholder="แสดงความคิดเห็น..." /><button type="submit">➤</button></form></section>');
  expect(await page.locator("#comment").evaluate((node) => getComputedStyle(node).backgroundColor)).toBe("rgb(31, 32, 35)");
  expect(await page.locator("#comment").evaluate((node) => getComputedStyle(node).color)).toBe("rgb(247, 247, 248)");
  expect(await page.locator('button[type="submit"]').evaluate((node) => getComputedStyle(node).backgroundColor)).toBe("rgb(247, 247, 248)");
});

test("color-only change preserves comment form markup, submission and layout", async () => {
  const root = process.cwd();
  const [quote, post, layout, css] = await Promise.all([
    readFile(path.join(root, "components/quote-detail-route.tsx"), "utf8"),
    readFile(path.join(root, "components/post-detail-route.tsx"), "utf8"),
    readFile(path.join(root, "app/layout.tsx"), "utf8"),
    readFile(PALETTE_PATH, "utf8"),
  ]);
  expect(quote).toContain('onSubmit={(event) => { event.preventDefault(); void send(); }}');
  expect(quote).toContain('className="detail-comment-form"');
  expect(post).toContain('className="detail-comment-form flutter-detail-composer"');
  expect(layout).toContain('import "./comment-neutral.css";');
  expect(css).not.toContain("position: fixed");
  expect(css).not.toContain("bottom:");
  expect(css).not.toContain("transform:");
});
