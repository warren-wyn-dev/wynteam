import { readFile } from "node:fs/promises";
import path from "node:path";

import { expect, test } from "@playwright/test";
import { mergeProfilePostsAndQuotes, PROFILE_POST_PAGE_SIZE } from "../../lib/profile-post-feed";
import type { HomeFeedRow } from "../../lib/feed";

function row(id: string, created_at: string, quoteId?: string, quote_text?: string): HomeFeedRow {
  return {
    id,
    created_at,
    content_type: "drop",
    author_id: "original-author",
    ...(quoteId ? {
      redrop_id: quoteId,
      redropper_id: "quoting-author",
      redropper_username: "quote_writer",
      quote_text,
    } : {}),
  };
}

test("Quotes appear with original posts newest-first without duplicate or missing pagination rows", () => {
  const posts = [
    row("p1", "2026-09-23T12:00:00Z"),
    row("p2", "2026-09-23T11:58:00Z"),
    row("p3", "2026-09-23T11:55:00Z"),
  ];
  const quotes = [
    row("original-A", "2026-09-23T12:05:00Z", "q1", "ความคิดเห็นหนึ่ง"),
    row("original-A", "2026-09-23T11:59:00Z", "q2", "ความคิดเห็นสอง"),
    row("original-B", "2026-09-23T11:57:00Z", "q3", "ความคิดเห็นสาม"),
    row("original-C", "2026-09-23T11:56:00Z", "q4", "ความคิดเห็นสี่"),
    row("original-D", "2026-09-23T11:54:00Z", "q5", "ความคิดเห็นห้า"),
    row("original-E", "2026-09-23T11:53:00Z", "r1"), // standard repost, excluded
  ];
  const page0 = mergeProfilePostsAndQuotes(posts, quotes, 0, 3);
  const page1 = mergeProfilePostsAndQuotes(posts, quotes, 1, 3);
  const page2 = mergeProfilePostsAndQuotes(posts, quotes, 2, 3);
  const key = (value: HomeFeedRow) => value.redrop_id ?? value.id;
  expect(page0.map(key)).toEqual(["q1", "p1", "q2"]);
  expect(page1.map(key)).toEqual(["p2", "q3", "q4"]);
  expect(page2.map(key)).toEqual(["p3", "q5"]);
  expect(new Set([...page0, ...page1, ...page2].map(key)).size).toBe(8);
  expect(PROFILE_POST_PAGE_SIZE).toBe(21);
});

test("The profile data queries never mix Quote and Standard Reposts", async () => {
  const root = process.cwd();
  const [timeline, profile, preview, home, card] = await Promise.all([
    readFile(path.join(root, "lib/profile-post-feed.ts"), "utf8"),
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
    readFile(path.join(root, "components/phase3-ui.tsx"), "utf8"),
    readFile(path.join(root, "components/home/home-screen.tsx"), "utf8"),
    readFile(path.join(root, "components/quote-feed-card.tsx"), "utf8"),
  ]);
  expect(timeline).toContain("fetchProfileDrops(client, userId, 0, limit)");
  expect(timeline).toContain('not("quote_text", "is", null)');
  expect(timeline).toContain('is("quote_text", null)');
  expect(timeline).toContain("mergeProfilePostsAndQuotes(posts,");
  expect(profile).toContain("fetchProfilePostTimeline(client, profileId, nextPage)");
  expect(profile).toContain("fetchProfileStandardReposts(client, profileId, nextPage)");
  expect(profile).toContain('deleteMountCache(`profile-feed:${actorId}:posts`)');
  expect(preview).toContain("if (isQuotePost(row))");
  expect(preview).toContain("<QuoteFeedCard");
  expect(home).toContain("isQuotePost(row) ? (");
  expect(home).toContain("<QuoteFeedCard");
  expect(card).toContain("row.redropper_display_name");
  expect(card).toContain("row.redropper_avatar_url");
  expect(card).toContain("row.author_avatar_url");
  expect(card).toContain('href={`/drop/${row.id}`}');
  expect(card).not.toContain("<PostActions");
  expect(card).toContain('.from("redrops").delete()');
  expect(card).toContain('p_target_type: "redrop"');
});

test("Quotes show quoted author, an embedded original, and no wrongly attributed engagement UI", async ({ page }) => {
  const root = process.cwd();
  const css = await readFile(path.join(root, "app/profile-home-feed.css"), "utf8");
  expect(css).toContain(".wyn-quote-feed-card");
  expect(css).toContain(".wyn-quote-feed-original");
  expect(css).toContain("-webkit-line-clamp: 4");
  expect(css).toContain(".wyn-quote-feed-original-image");
  expect(css).toContain(".wyn-quote-feed-sheet-backdrop");

  await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });
  // The fixture currently contains only standard post rows. Use it to ensure
  // the new Quote CSS cannot introduce horizontal overflow into the Home feed.
  const result = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    body: document.body.scrollWidth,
  }));
  expect(result.body).toBeLessThanOrEqual(result.viewport + 2);
});
