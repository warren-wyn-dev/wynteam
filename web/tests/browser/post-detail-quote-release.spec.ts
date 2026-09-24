import { readFile } from "node:fs/promises";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("real post detail uses viewport portal, stable header and cold-load skeleton", async () => {
  const root = process.cwd();
  const [post, inset, css, portal] = await Promise.all([
    readFile(path.join(root, "components/post-detail-route.tsx"), "utf8"),
    readFile(path.join(root, "lib/use-keyboard-inset.ts"), "utf8"),
    readFile(path.join(root, "app/post-detail-keyboard-fix.css"), "utf8"),
    readFile(path.join(root, "components/ui/viewport-portal.tsx"), "utf8"),
  ]);
  expect(post).toContain('<ViewportPortal><div className="detail-composer-shell">');
  expect(post).toContain('</div></ViewportPortal>');
  expect(post).toContain('document.activeElement === composerRef.current');
  expect(post).toContain('onFocus={() => setHeaderHidden(false)}');
  expect(post).toContain('<PostDetailSkeleton />');
  expect(inset).toContain('focus.closest(".detail-composer-shell")');
  expect(inset).toContain('window.innerHeight - vv.height - vv.offsetTop');
  expect(inset).toContain('document.addEventListener("focusin", schedule)');
  expect(css).toContain('.detail-composer-shell:focus-within { padding-bottom: 9px; }');
  expect(portal).toContain('createPortal(children, host)');
  expect(portal).toContain('setHost(document.body)');
});

test("quote delete menu is compact, explains scope and has in-sheet confirmation", async ({ page }) => {
  const root = process.cwd();
  const [quote, css] = await Promise.all([
    readFile(path.join(root, "components/quote-feed-card.tsx"), "utf8"),
    readFile(path.join(root, "app/profile-home-feed.css"), "utf8"),
  ]);
  expect(quote).toContain('className="wyn-quote-feed-sheet wyn-quote-feed-menu-sheet"');
  expect(quote).toContain('setDeleteConfirm(true)');
  expect(quote).toContain('setDeleteConfirm(false)');
  expect(quote).toContain("ยืนยันการลบ");
  expect(quote).toContain("โพสต์ต้นฉบับยังอยู่");
  expect(quote).not.toContain('window.confirm("ลบโพสต์อ้างอิงนี้?")');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.setContent('<style>:root{--wyn-bg:#fff;--wyn-text:#111;--wyn-border:#dedfe3;--wyn-text-secondary:#777}</style><style>'+css+'</style><div class="wyn-quote-feed-sheet-backdrop"><section class="wyn-quote-feed-sheet wyn-quote-feed-menu-sheet" role="dialog"><div class="wyn-quote-feed-sheet-grip"></div><button class="danger">ลบอ้างอิง</button><p class="wyn-quote-feed-sheet-hint">ลบเฉพาะโพสต์อ้างอิงของคุณ ไม่กระทบโพสต์ต้นฉบับ</p><button class="wyn-quote-feed-sheet-cancel">ยกเลิก</button></section></div>');
  const sheet = await page.locator(".wyn-quote-feed-menu-sheet").boundingBox();
  expect(sheet).not.toBeNull();
  expect(sheet!.height).toBeLessThan(245);
  expect(sheet!.y + sheet!.height).toBeGreaterThanOrEqual(842);
});
