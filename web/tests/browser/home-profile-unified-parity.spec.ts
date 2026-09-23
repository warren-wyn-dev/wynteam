import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const read = (file: string) => readFileSync(path.join(process.cwd(), file), "utf8");

test("mixed Home/Profile rows have exactly one theme-aware separator", async ({ page }) => {
  for (const colorScheme of ["light", "dark"] as const) {
    await page.emulateMedia({ colorScheme });
    await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });

    const result = await page.evaluate(() => {
      const host = document.createElement("div");
      host.style.cssText = "position:absolute;left:0;top:0;visibility:hidden;width:390px";
      const types = ["wyn-post", "wyn-post", "wyn-quote-feed-card", "wyn-post", "wyn-quote-feed-card", "wyn-quote-feed-card"];
      const articles = types.map((className) => '<article class="' + className + '"></article>').join("");
      host.innerHTML = '<div class="wyn-home-feed">' + articles + '</div>' +
        '<div class="wyn-profile-beta1"><div class="profile-feed-list">' + articles + '</div></div>' +
        '<div class="color-probe" style="border-top:1px solid var(--wyn-border)"></div>';
      document.body.appendChild(host);
      const expected = getComputedStyle(host.querySelector(".color-probe")!).borderTopColor;
      const measure = (parent: string) =>
        Array.from(host.querySelectorAll<HTMLElement>(parent + " > article")).map((el) => {
          const style = getComputedStyle(el);
          return {
            top: style.borderTopWidth,
            bottom: style.borderBottomWidth,
            color: style.borderTopColor,
          };
        });
      const output = {
        home: measure(".wyn-home-feed"),
        profile: measure(".profile-feed-list"),
        expected,
      };
      host.remove();
      return output;
    });

    // An invisible zero-width first-row border can inherit a different text
    // color in the Profile container without changing any visible divider.
    expect(result.profile.slice(1)).toEqual(result.home.slice(1));
    for (const rows of [result.home, result.profile]) {
      expect(rows[0].top).toBe("0px");
      rows.slice(1).forEach((row) => {
        expect(row.top).toBe("1px");
        expect(row.color).toBe(result.expected);
      });
      rows.forEach((row) => expect(row.bottom).toBe("0px"));
    }
  }
});

test("real Quote footer and full-width separator match normal posts on Home and Profile", async ({ page }) => {
  for (const colorScheme of ["light", "dark"] as const) {
    await page.emulateMedia({ colorScheme });
    for (const width of [320, 359, 390, 430, 681, 768]) {
      await page.setViewportSize({ width, height: 820 });
      await page.goto("/dev/quote-fixture", { waitUntil: "domcontentloaded" });
      const result = await page.evaluate(() => {
        const actualQuote = document.querySelector<HTMLElement>('[data-testid="quote-fixture"] > .wyn-quote-feed-card')!;
        const normal = document.createElement("article");
        normal.className = "wyn-post";
        normal.innerHTML = '<span class="wyn-post-avatar"></span><div class="wyn-post-body">' +
          '<div class="wyn-post-author-row">WYNOS</div><div class="wyn-post-caption-wrap">โพสต์ปกติ</div>' +
          '<div class="wyn-post-actions wyn-threads-actions"><button class="wyn-action-button">♡</button>' +
          '<button class="wyn-action-button">◯</button><button class="wyn-action-button">↻</button>' +
          '<button class="wyn-action-button">↑</button><button class="wyn-action-button wyn-action-save">♧</button></div></div>';
        const containers = ["wyn-home-feed", "profile-feed-list"].map((name) => {
          const host = document.createElement("div");
          host.className = name === "profile-feed-list" ? "wyn-profile-beta1" : "wyn-divider-test-host";
          host.style.cssText = "position:absolute;left:0;top:0;visibility:hidden;width:min(100%,680px)";
          const feed = document.createElement("div");
          feed.className = name;
          host.appendChild(feed);
          feed.append(actualQuote.cloneNode(true),normal.cloneNode(true),actualQuote.cloneNode(true),actualQuote.cloneNode(true),normal.cloneNode(true));
          document.body.append(host);
          const feedRect = feed.getBoundingClientRect();
          const posts = Array.from(feed.children) as HTMLElement[];
          const result = posts.map((post) => {
            const rect = post.getBoundingClientRect();
            const actionRect = post.querySelector<HTMLElement>(".wyn-post-actions")!.getBoundingClientRect();
            const css = getComputedStyle(post);
            return {
              left: rect.left,
              right: rect.right,
              top: rect.top,
              bottom: rect.bottom,
              borderTop: css.borderTopWidth,
              borderBottom: css.borderBottomWidth,
              borderColor: css.borderTopColor,
              paddingBottom: css.paddingBottom,
              footerGap: rect.bottom - actionRect.bottom,
            };
          });
          const expectedColor = getComputedStyle(document.documentElement).getPropertyValue("--wyn-border").trim();
          host.remove();
          return { name, feedLeft: feedRect.left, feedRight: feedRect.right, posts: result, expectedColor };
        });
        return containers;
      });
      for (const { feedLeft, feedRight, posts } of result) {
        for (const post of posts) {
          // The separator is on the NEXT full-width card, not only on its
          // inner content/actions column (which ends before the bookmark).
          expect(Math.abs(post.left - feedLeft)).toBeLessThanOrEqual(1);
          expect(Math.abs(post.right - feedRight)).toBeLessThanOrEqual(1);
          expect(post.borderBottom).toBe("0px");
          expect(post.paddingBottom).toBe("0px");
        }
        expect(posts[0].borderTop).toBe("0px");
        for (let i = 1; i < posts.length; i += 1) {
          expect(posts[i].borderTop).toBe("1px");
          expect(Math.abs(posts[i].top - posts[i - 1].bottom)).toBeLessThanOrEqual(1);
        }
        // Normal HomePostCard and QuoteFeedCard action bars now finish the
        // same distance above the next divider, without Quote's old 12px gap.
        expect(Math.abs(posts[0].footerGap - posts[1].footerGap)).toBeLessThanOrEqual(1);
        expect(Math.abs(posts[2].footerGap - posts[1].footerGap)).toBeLessThanOrEqual(1);
      }
    }
  }
});

test("normal and Quote cards share avatar/content insets at mobile and wide breakpoints", async ({ page }) => {
  for (const width of [320, 359, 360, 390, 680, 681, 768]) {
    await page.setViewportSize({ width, height: 820 });
    await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });
    const result = await page.evaluate((screenWidth) => {
      const host = document.createElement("div");
      host.style.cssText = "position:absolute;left:0;top:0;visibility:hidden";
      host.style.width = Math.min(screenWidth, 680) + "px";
      host.innerHTML =
        '<div class="wyn-profile-beta1"><div class="profile-feed-list">' +
        '<article class="wyn-post"><a class="wyn-post-avatar"></a><div class="wyn-post-body"></div></article>' +
        '<article class="wyn-quote-feed-card"><a class="wyn-quote-feed-author-avatar"></a><div class="wyn-quote-feed-body"></div></article>' +
        '</div></div>';
      document.body.appendChild(host);
      const normal = host.querySelector<HTMLElement>(".wyn-post")!;
      const quote = host.querySelector<HTMLElement>(".wyn-quote-feed-card")!;
      const normalAvatar = normal.querySelector<HTMLElement>(".wyn-post-avatar")!.getBoundingClientRect();
      const quoteAvatar = quote.querySelector<HTMLElement>(".wyn-quote-feed-author-avatar")!.getBoundingClientRect();
      const result = {
        normalInset: getComputedStyle(normal).paddingLeft,
        quoteInset: getComputedStyle(quote).paddingLeft,
        normalAvatar: normalAvatar.width,
        quoteAvatar: quoteAvatar.width,
        normalGap: getComputedStyle(normal).columnGap,
        quoteGap: getComputedStyle(quote).columnGap,
      };
      host.remove();
      return result;
    }, width);
    const expectedInset = width <= 359 ? "12px" : width >= 681 ? "20px" : "16px";
    expect(result.normalInset).toBe(expectedInset);
    expect(result.quoteInset).toBe(expectedInset);
    expect(result.normalAvatar).toBe(width <= 359 ? 34 : 40);
    expect(result.quoteAvatar).toBe(result.normalAvatar);
    expect(result.quoteGap).toBe(result.normalGap);
  }
});

test("Home and Profile tabs share active typography and indicator width", async ({ page }) => {
  for (const width of [320, 359, 360, 390]) {
    await page.setViewportSize({ width, height: 820 });
    await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });
    const result = await page.evaluate((screenWidth) => {
      const host = document.createElement("div");
      host.style.cssText = "position:absolute;left:0;top:0;visibility:hidden";
      host.style.width = screenWidth + "px";
      const homeTab = (text: string, active: boolean) =>
        '<button class="wyn-home-tab' + (active ? ' is-active' : '') +
        '"><span class="wyn-home-tab-label">' + text + '</span><span class="wyn-home-tab-indicator"></span></button>';
      const profileTab = (text: string, active: boolean) =>
        '<button class="' + (active ? 'active' : '') + '">' + text + '</button>';
      host.innerHTML = '<div class="wyn-home-tabs">' +
        homeTab("สำหรับคุณ", true) + homeTab("ติดตาม", false) + homeTab("คลับ", false) + '</div>' +
        '<div class="wyn-profile-beta1"><div class="route-tabs wyn-profile-tabs">' +
        profileTab("โพสต์", true) + profileTab("รีโพสต์", false) + profileTab("ถูกใจ", false) + '</div></div>';
      document.body.appendChild(host);
      const homeButton = host.querySelector<HTMLElement>(".wyn-home-tab.is-active")!;
      const profileButton = host.querySelector<HTMLElement>(".wyn-profile-tabs button.active")!;
      const indicator = host.querySelector<HTMLElement>(".wyn-home-tab-indicator")!;
      const result = {
        homeFont: getComputedStyle(homeButton).fontSize,
        profileFont: getComputedStyle(profileButton).fontSize,
        homeWeight: getComputedStyle(homeButton).fontWeight,
        profileWeight: getComputedStyle(profileButton).fontWeight,
        homeIndicator: indicator.getBoundingClientRect().width,
        profileIndicator: parseFloat(getComputedStyle(profileButton, "::after").width),
      };
      host.remove();
      return result;
    }, width);
    expect(result.homeFont).toBe(width <= 359 ? "14px" : "15px");
    expect(result.profileFont).toBe(result.homeFont);
    expect(result.homeWeight).toBe("700");
    expect(result.profileWeight).toBe(result.homeWeight);
    expect(Math.abs(result.profileIndicator - result.homeIndicator)).toBeLessThanOrEqual(1);
  }
});

test("caption truncation and Profile hydration use the shared source contract", () => {
  const card = read("components/home/home-post-card.tsx");
  const profile = read("components/profile-route.tsx");
  const preview = read("components/phase3-ui.tsx");
  const golden = read("components/golden-drop-card.tsx");
  const quote = read("components/quote-feed-card.tsx");
  expect(card).toContain('new Intl.Segmenter("th", { granularity: "grapheme" })');
  expect(card).toContain("chars.length > 190");
  expect(card).toContain("chars.slice(0, 190)");
  expect(profile).toContain("loadHomeViewerState(client, viewerId, combined)");
  expect(profile).toContain("viewerSnapshot={viewerSnapshot}");
  expect(preview).toContain("initialViewer={viewerSnapshot}");
  expect(golden).toContain("initialViewer ? Promise.resolve(initialViewer)");
  expect(quote).toContain("initialQuoteState ?? null");
  expect(quote).toContain("fetchQuoteEngagement(client, [quoteId])");
  expect(quote).not.toContain('className="wyn-quote-feed-more-action"');
});
