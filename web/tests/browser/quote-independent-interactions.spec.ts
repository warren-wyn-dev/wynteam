import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const read = (file: string) => readFileSync(path.join(process.cwd(),file),"utf8");

test("Quote with zero reactions never inherits the original Drop's four likes", async ({ page }) => {
  await page.goto("/dev/quote-fixture", { waitUntil: "domcontentloaded" });
  const card = page.getByRole("article",{ name: "โพสต์อ้างอิง" });
  await expect(card).toBeVisible();
  await expect(card).toContainText("สวย");
  await expect(card.locator(".wyn-quote-feed-original")).toContainText("นี่คือ WYNOS");
  await expect(card.locator(".wyn-quote-feed-engagement-label")).toHaveCount(0);
  const actions = card.locator(".wyn-quote-feed-actions");
  await expect(actions.locator(".wyn-action-button-count")).toHaveCount(0);
  await expect(actions.getByRole("button",{ name: "ถูกใจ" })).toHaveAttribute("aria-pressed","false");
  await expect(actions.getByRole("button",{ name: "รีโพสต์" })).toHaveAttribute("aria-pressed","false");
  await expect(actions.getByRole("button",{ name: "บันทึก" })).toHaveAttribute("aria-pressed","false");
  await expect(actions.getByRole("link",{ name: "ความคิดเห็น" })).toHaveAttribute("href",/\/quote\/a1000000-0000-0000-0000-000000000001#comments$/);
  await expect(card.locator(".wyn-quote-feed-original")).toHaveAttribute("href",/\/drop\/d1000000-0000-0000-0000-000000000001$/);
});

test("Quote interactions have separate database IDs, RLS and no original mutations", () => {
  const migration = read("../supabase/migrations_wyn186_quote_interactions.sql");
  const actions = read("lib/quote-actions.ts");
  const card = read("components/quote-feed-card.tsx");
  const detail = read("components/quote-detail-route.tsx");
  const timeline = read("lib/profile-post-feed.ts");
  const bookmarks = read("components/bookmarks-route.tsx");

  for (const table of ["quote_likes","quote_comments","quote_reposts","quote_saves"]) {
    expect(migration).toContain("create table if not exists public."+table);
    expect(migration).toContain("alter table public."+table+" enable row level security");
    expect(actions+card).toContain(table);
  }
  expect(migration).toContain("get_quote_engagement(p_quote_ids uuid[])");
  expect(migration).toContain("join public.redrops q on q.id=ids.id and q.quote_text is not null");
  expect(card).not.toContain('toggleDropLike(');
  expect(card).not.toContain('toggleDropRedrop(');
  expect(card).not.toContain('toggleDropSave(');
  expect(card).toContain("commentHref={\`/quote/\${quoteId}#comments\`}");
  expect(card).toContain("likeCount={engagement.likeCount}");
  expect(card).toContain("redropCount={engagement.redropCount}");
  expect(detail).toContain("fetchQuoteComments(client, quoteId)");
  expect(detail).toContain("addQuoteComment(client, viewerId, quoteId, text)");
  expect(timeline).toContain("fetchQuoteRepostRows(client, [userId], limit)");
  expect(bookmarks).toContain("fetchSavedQuoteRows(client,userId,limit)");
});

test("Quote card does not overflow a 320px mobile feed", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto("/dev/quote-fixture", { waitUntil: "domcontentloaded" });
  const metrics = await page.evaluate(() => {
    const card = document.querySelector<HTMLElement>(".wyn-quote-feed-card")!;
    const row = card.querySelector<HTMLElement>(".wyn-post-actions")!;
    const cardBox = card.getBoundingClientRect();
    const rowBox = row.getBoundingClientRect();
    return {cardRight:cardBox.right,actionsRight:rowBox.right,viewport:document.documentElement.clientWidth,scroll:document.documentElement.scrollWidth};
  });
  expect(metrics.cardRight).toBeLessThanOrEqual(metrics.viewport+1);
  expect(metrics.actionsRight).toBeLessThanOrEqual(metrics.cardRight+1);
  expect(metrics.scroll).toBeLessThanOrEqual(metrics.viewport+2);
});
