import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const root = process.cwd();
const read = (file: string) => readFileSync(path.join(root, file), "utf8");

test("Profile actions inherit Home's shared icons and spacing without a Beta1 override", () => {
  const homeActions = read("components/home/post-actions.tsx");
  const profileCard = read("components/golden-drop-card.tsx");
  const beta1 = read("app/profile-web-beta1.css");
  const shared = read("app/threads-action-row.css");
  const profile = read("app/profile-home-feed.css");

  // Home and Profile already render the same icon set, including an animated
  // heart, rounded comment, circular repost, open-tray share and far-right save.
  expect(homeActions).toContain("<AnimatedHeart");
  expect(homeActions).toContain("<CommentIcon");
  expect(homeActions).toContain("<RepostIcon");
  expect(homeActions).toContain("<WynosShareIcon");
  expect(homeActions).toContain("<SaveIcon");
  expect(profileCard).toContain("<HomePostCard");
  expect(profileCard).toContain("viewer={viewer ?? EMPTY_VIEWER}");
  expect(profileCard).toContain("onLike={() => void like()}");
  expect(profileCard).toContain("onFollow={() => void followAuthor()}");
  expect(profileCard).toContain("onSave={() => void save()}");

  expect(shared).toContain(".wyn-post-actions.wyn-threads-actions");
  expect(shared).toContain("gap: 18px;");
  expect(shared).toContain("gap: 16px;");
  // Profile normal posts use the canonical Home CSS; no legacy Golden overrides.
  expect(profile).not.toContain(".profile-feed-list .golden-drop-card {");
  expect(profile).not.toContain(".profile-feed-list .wyn-post-actions.wyn-threads-actions {");
  expect(profile).toContain(".wyn-quote-feed-actions .wyn-post-actions.wyn-threads-actions { gap: 16px; }");
  expect(beta1).not.toMatch(/\.wyn-profile-beta1 \.profile-feed-list \.wyn-post-actions\.wyn-threads-actions\s*\{/);
  expect(beta1).not.toContain("gap: 21px !important;");
  expect(beta1).not.toContain("gap: 14px !important;");
});

test("390px and 320px Home/Profile rows have equal action geometry and a right-aligned bookmark", async ({ page }) => {
  for (const width of [390, 320]) {
    await page.setViewportSize({ width, height: 820 });
    await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });

    const result = await page.evaluate((cardWidth) => {
      const row = [
        '<div class="wyn-post-actions wyn-threads-actions">',
        '<button class="wyn-action-button" aria-label="ถูกใจ"><svg width="22" height="22"></svg><span class="wyn-action-button-count">3</span></button>',
        '<a class="wyn-action-button" aria-label="ความคิดเห็น"><svg width="24" height="24"></svg></a>',
        '<button class="wyn-action-button" aria-label="รีโพสต์"><svg width="22" height="22"></svg><span class="wyn-action-button-count">1</span></button>',
        '<button class="wyn-action-button wyn-action-share" aria-label="แชร์"><svg width="22" height="22"></svg></button>',
        '<button class="wyn-action-button wyn-action-save" aria-label="บันทึก"><svg width="22" height="22"></svg></button>',
        "</div>",
      ].join("");

      const host = document.createElement("div");
      host.style.cssText = "position:fixed;left:0;top:0;visibility:hidden;z-index:-1;";
      host.style.width = cardWidth + "px";
      host.innerHTML =
        '<div class="wyn-home-fixture"><article class="wyn-post" style="width:100%"><div class="wyn-post-body">' +
        row +
        '</div></article></div>' +
        '<div class="wyn-profile-beta1"><div class="profile-feed-list"><article class="wyn-post" style="width:100%"><div class="wyn-post-body">' +
        row +
        "</div></article></div></div>" +
        '<div class="wyn-profile-beta1"><div class="profile-feed-list"><article class="wyn-quote-feed-card"><a class="wyn-quote-feed-author-avatar"></a><div class="wyn-quote-feed-body"><div class="wyn-quote-feed-actions">' +
        row +
        '</div></div></article></div></div>';
      document.body.append(host);

      const measure = (selector: string) => {
        const actionRow = host.querySelector<HTMLElement>(selector)!;
        const buttons = [...actionRow.querySelectorAll<HTMLElement>(".wyn-action-button")];
        const firstX = buttons[0].getBoundingClientRect().left;
        const bookmark = actionRow.querySelector<HTMLElement>(".wyn-action-save")!;
        const rect = actionRow.getBoundingClientRect();
        return {
          gap: getComputedStyle(actionRow).gap,
          offsets: buttons.slice(0, 4).map((button) => button.getBoundingClientRect().left - firstX),
          iconSizes: buttons.map((button) => {
            const svg = button.querySelector("svg")!;
            const box = svg.getBoundingClientRect();
            return [box.width, box.height];
          }),
          bookmarkRightGap: rect.right - bookmark.getBoundingClientRect().right,
        };
      };
      const home = measure(".wyn-home-fixture .wyn-post-actions");
      const profile = measure(".wyn-profile-beta1 .wyn-post .wyn-post-actions");
      const quote = measure(".wyn-quote-feed-card .wyn-post-actions");
      const quoteContainer = host.querySelector<HTMLElement>(".wyn-quote-feed-card")!;
      const quoteOverflow = quoteContainer.scrollWidth - quoteContainer.clientWidth;
      host.remove();
      return { home, profile, quote, quoteOverflow };
    }, width);

    const expectedGap = width === 320 ? "16px" : "18px";
    expect(result.home.gap).toBe(expectedGap);
    expect(result.profile.gap).toBe(result.home.gap);
    expect(result.profile.iconSizes).toEqual(result.home.iconSizes);

    // Counts take up their natural width in both places, but never
    // introduce a page-specific shift between the first four icons.
    result.home.offsets.forEach((homeOffset, index) => {
      expect(Math.abs(result.profile.offsets[index] - homeOffset)).toBeLessThan(1);
    });
    expect(Math.abs(result.home.bookmarkRightGap)).toBeLessThan(1);
    expect(Math.abs(result.profile.bookmarkRightGap)).toBeLessThan(1);

    // The Quote's More control now lives in its header, so all five action
    // icons use Home's uncompressed sizing and spacing even at 320px.
    expect(result.quote.gap).toBe(expectedGap);
    expect(result.quote.iconSizes).toEqual(result.home.iconSizes);
    expect(Math.abs(result.quote.bookmarkRightGap)).toBeLessThan(1);
    expect(result.quoteOverflow).toBeLessThanOrEqual(2);
  }
});
