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
  const [timeline, profile, preview, home, card, following] = await Promise.all([
    readFile(path.join(root, "lib/profile-post-feed.ts"), "utf8"),
    readFile(path.join(root, "components/profile-route.tsx"), "utf8"),
    readFile(path.join(root, "components/phase3-ui.tsx"), "utf8"),
    readFile(path.join(root, "components/home/home-screen.tsx"), "utf8"),
    readFile(path.join(root, "components/quote-feed-card.tsx"), "utf8"),
    readFile(path.join(root, "lib/home-feed-sources.ts"), "utf8"),
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
  expect(card).toContain("<PostActions");
  expect(card).toContain("กิจกรรมโพสต์อ้างอิง");
  expect(card).toContain("toggleQuoteLike");
  expect(card).toContain("toggleQuoteRepost");
  expect(card).toContain("toggleQuoteSave");
  expect(card).toContain("shareQuote");
  expect(card).toContain('from("drop_images")');
  expect(card).toContain("setFailedMedia");
  expect(card).toContain('.from("redrops").delete()');
  expect(card).toContain('p_target_type: "redrop"');
  // No stranger's quote/repost sneaks into Following merely because its
  // embedded original was written by someone the viewer follows.
  expect(following).toContain("redrop_id.is.null");
  expect(following).toContain("redropper_id.in.");

});

test("Quotes show the embedded original and their own independent actions", async ({ page }) => {
  const root = process.cwd();
  const css = await readFile(path.join(root, "app/profile-home-feed.css"), "utf8");
  expect(css).toContain(".wyn-quote-feed-card");
  expect(css).toContain(".wyn-quote-feed-original");
  expect(css).not.toContain("-webkit-line-clamp: 4");
  expect(css).toContain(".wyn-quote-feed-state");
  expect(css).toContain(".wyn-quote-feed-actions");
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


test("Shared Quote URLs resolve to their authored quote rather than the original post", async () => {
  const root = process.cwd();
  const [route, page, card] = await Promise.all([
    readFile(path.join(root, "components/quote-detail-route.tsx"), "utf8"),
    readFile(path.join(root, "app/quote/[id]/page.tsx"), "utf8"),
    readFile(path.join(root, "components/quote-feed-card.tsx"), "utf8"),
  ]);
  expect(page).toContain("<QuoteDetailRoute quoteId={id} />");
  expect(route).toContain('.eq("redrop_id", quoteId)');
  expect(card).toContain('/quote/${quoteId}');
  expect(card).toContain('id={quoteId ?');
  expect(card).toContain('href={`/drop/${row.id}`}');
});

test("Quote card keeps multiline text and Quote actions inside 320px", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });
  const size = await page.evaluate(() => {
    const host = document.createElement("div");
    host.className = "wyn-profile-beta1";
    host.style.width = "320px";
    host.innerHTML = `
      <div class="profile-feed-list">
        <article class="wyn-quote-feed-card">
          <a class="wyn-quote-feed-author-avatar"><span class="wyn-quote-feed-avatar fallback">W</span></a>
          <div class="wyn-quote-feed-body">
            <header class="wyn-quote-feed-head">
              <a class="wyn-quote-feed-byline"><strong>WYNOS ONLINE</strong><small> · 3 ชม.</small></a>
              <button type="button" aria-label="ตัวเลือกอ้างอิง">···</button>
            </header>
            <a class="wyn-quote-feed-original">
              <span class="wyn-quote-feed-original-text">นี่คือ WYNOS
พื้นที่ของคุณ เรื่องราวของคุณ
และผู้คนที่คุณอยากเชื่อมต่อ
นี่เป็นเพียงจุดเริ่มต้น
ยินดีต้อนรับสู่ WYNOS
#WYNOS #wynosonline</span>
            </a>
            <div class="wyn-quote-feed-engagement-label">โต้ตอบกับโพสต์ต้นฉบับ</div>
            <div class="wyn-quote-feed-actions">
              <div class="wyn-post-actions wyn-threads-actions">
                <button class="wyn-action-button">♡<span>4</span></button>
                <button class="wyn-action-button">◯</button>
                <button class="wyn-action-button">↻<span>1</span></button>
                <button class="wyn-action-button">⇧</button>
                <button class="wyn-action-button wyn-action-save">♧</button>
              </div>
            </div>
          </div>
        </article>
      </div>
    `;
    document.body.appendChild(host);
    const card = host.querySelector<HTMLElement>(".wyn-quote-feed-card")!;
    const content = host.querySelector<HTMLElement>(".wyn-quote-feed-original-text")!;
    const dimensions = {
      cardWidth: card.clientWidth,
      cardScrollWidth: card.scrollWidth,
      contentHeight: content.getBoundingClientRect().height,
      lineClamp: getComputedStyle(content).webkitLineClamp,
    };
    host.remove();
    return dimensions;
  });
  expect(size.cardScrollWidth).toBeLessThanOrEqual(size.cardWidth + 2);
  expect(size.contentHeight).toBeGreaterThan(100);
  expect(size.lineClamp).not.toBe("4");
});

test("Beta1 Quote avatar and byline use the exact same row alignment as ordinary profile posts", async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });
  const measured = await page.evaluate(() => {
    const host = document.createElement("div");
    host.className = "wyn-profile-beta1";
    host.style.width = "min(390px, 100%)";
    host.style.position = "relative";
    host.innerHTML = `
      <div class="profile-feed-list">
        <article class="wyn-post" style="padding-top:8px">
          <a class="wyn-post-avatar"><span class="route-avatar fallback" style="width:40px;height:40px">W</span></a>
          <div class="wyn-post-body">
            <header class="wyn-post-author-row">
              <a class="wyn-post-author-link"><strong class="wyn-post-author-name">WYNOS ONLINE</strong><small class="wyn-post-timestamp">· 1 ชม.</small></a>
              <button class="wyn-post-more" type="button">•••</button>
            </header>
          </div>
        </article>
        <article class="wyn-quote-feed-card">
          <a class="wyn-quote-feed-author-avatar"><span class="wyn-quote-feed-avatar fallback">W</span></a>
          <div class="wyn-quote-feed-body">
            <header class="wyn-quote-feed-head">
              <a class="wyn-quote-feed-byline"><strong>WYNOS ONLINE</strong><small>· 1 ชม.</small></a>
              <button type="button">•••</button>
            </header>
          </div>
        </article>
      </div>
    `;
    document.body.appendChild(host);
    const ordinary = host.querySelector<HTMLElement>(".wyn-post")!;
    const quote = host.querySelector<HTMLElement>(".wyn-quote-feed-card")!;
    const measure = (card: HTMLElement, avatarClass: string, nameClass: string) => {
      const outer = card.getBoundingClientRect();
      const avatar = card.querySelector<HTMLElement>(avatarClass)!.getBoundingClientRect();
      const nameEl = card.querySelector<HTMLElement>(nameClass)!;
      const name = nameEl.getBoundingClientRect();
      const menu = card.querySelector<HTMLElement>("header > button")!.getBoundingClientRect();
      return {
        avatarX: avatar.x - outer.x,
        avatarY: avatar.y - outer.y,
        avatarWidth: avatar.width,
        avatarHeight: avatar.height,
        nameX: name.x - outer.x,
        nameY: name.y - outer.y,
        fontSize: getComputedStyle(nameEl).fontSize,
        fontWeight: getComputedStyle(nameEl).fontWeight,
        menuHeight: menu.height,
      };
    };
    const ordinaryGeometry = measure(ordinary, ".wyn-post-avatar", ".wyn-post-author-name");
    const quoteGeometry = measure(quote, ".wyn-quote-feed-author-avatar", ".wyn-quote-feed-head strong");
    host.remove();
    return { ordinaryGeometry, quoteGeometry };
  });
  const { ordinaryGeometry: normal, quoteGeometry: quote } = measured;
  expect(quote.avatarWidth).toBe(normal.avatarWidth);
  expect(quote.avatarHeight).toBe(normal.avatarHeight);
  expect(Math.abs(quote.avatarX - normal.avatarX)).toBeLessThanOrEqual(1);
  expect(Math.abs(quote.avatarY - normal.avatarY)).toBeLessThanOrEqual(1);
  expect(Math.abs(quote.nameX - normal.nameX)).toBeLessThanOrEqual(1);
  expect(Math.abs(quote.nameY - normal.nameY)).toBeLessThanOrEqual(2);
  expect(quote.fontSize).toBe(normal.fontSize);
  expect(quote.fontWeight).toBe(normal.fontWeight);
  expect(quote.menuHeight).toBe(normal.menuHeight);
});
