import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const read = (name: string) => readFileSync(path.join(process.cwd(), name), "utf8");

test("Profile uses the actual HomePostCard renderer for every normal, liked and reposted Drop", () => {
  const preview = read("components/phase3-ui.tsx");
  const profile = read("components/profile-route.tsx");
  const golden = read("components/golden-drop-card.tsx");
  const homeCard = read("components/home/home-post-card.tsx");
  const beta1 = read("app/profile-web-beta1.css");

  expect(profile).toContain("<DropPreviewCard row={row} homeParity");
  expect(preview).toContain("<GoldenDropCard row={row} homeParity={homeParity}");
  expect(golden).toContain("<HomePostCard");
  expect(golden).toContain("row={{ ...row, like_count: likeCount, redrop_count: redropCount }}");
  for (const element of ["<PostAuthorRow", "<PostMediaCarousel", "<PostActions", "wyn-post-caption-wrap", "wyn-post-avatar"]) {
    expect(homeCard).toContain(element);
  }
  expect(beta1).not.toContain("grid-template-columns: 44px minmax(0, 1fr) !important");
  expect(beta1).not.toContain("font-size: 15.5px !important");
});

test("Home and Profile align header, caption, hashtags, inset media and actions at all mobile sizes", async ({ page }) => {
  for (const width of [390, 320, 768]) {
    await page.setViewportSize({ width, height: 820 });
    await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });
    const layout = await page.evaluate((screenWidth) => {
      const card = [
        '<article class="wyn-post" style="padding-top:8px">',
        '<a class="wyn-post-avatar"><span class="route-avatar fallback">W</span></a>',
        '<div class="wyn-post-body">',
        '<header class="wyn-post-author-row">',
        '<a class="wyn-post-author-link"><strong class="wyn-post-author-name">ZEN</strong><small class="wyn-post-timestamp">· 25 ส.ค.</small></a>',
        '<button class="wyn-post-more">···</button>',
        '</header>',
        '<div class="wyn-post-caption-wrap">',
        '<p class="wyn-post-caption">ชาเขียว 🧋</p>',
        '<p class="wyn-post-caption wyn-post-caption-tags">#ชาเขียว #WYNOS</p>',
        '</div>',
        '<div class="wyn-post-media" style="margin-top:8px">',
        '<div class="wyn-post-media-track is-single">',
        '<img class="wyn-post-media-item" alt="" width="400" height="400" style="width:100%;height:auto" />',
        '</div></div>',
        '<div class="wyn-post-actions wyn-threads-actions">',
        '<button class="wyn-action-button"><svg width="22" height="22"></svg><span class="wyn-action-button-count">3</span></button>',
        '<button class="wyn-action-button"><svg width="24" height="24"></svg></button>',
        '<button class="wyn-action-button"><svg width="22" height="22"></svg></button>',
        '<button class="wyn-action-button wyn-action-share"><svg width="22" height="22"></svg></button>',
        '<button class="wyn-action-button wyn-action-save"><svg width="22" height="22"></svg></button>',
        '</div></div></article>',
      ].join("");
      const host = document.createElement("div");
      host.style.cssText = "position:fixed;left:0;top:0;visibility:hidden;z-index:-1;";
      host.style.width = Math.min(screenWidth, 600) + "px";
      host.innerHTML = '<div class="wyn-home-fixture">' + card + '</div>'
        + '<div class="wyn-profile-beta1"><div class="profile-feed-list">' + card + '</div></div>';
      document.body.append(host);
      const measure = (prefix: string) => {
        const outer = host.querySelector<HTMLElement>(prefix + " .wyn-post")!;
        const rect = outer.getBoundingClientRect();
        const byline = host.querySelector<HTMLElement>(prefix + " .wyn-post-author-name")!;
        const caption = host.querySelector<HTMLElement>(prefix + " .wyn-post-caption")!;
        const image = host.querySelector<HTMLElement>(prefix + " .wyn-post-media-item")!;
        const actions = host.querySelector<HTMLElement>(prefix + " .wyn-post-actions")!;
        const position = (selector: string) => {
          const element = host.querySelector<HTMLElement>(prefix + " " + selector)!;
          const box = element.getBoundingClientRect();
          return [Math.round((box.x - rect.x) * 100) / 100, Math.round((box.y - rect.y) * 100) / 100,
            Math.round(box.width * 100) / 100, Math.round(box.height * 100) / 100];
        };
        return {
          avatar: position(".wyn-post-avatar"),
          name: position(".wyn-post-author-name"),
          caption: position(".wyn-post-caption"),
          tags: position(".wyn-post-caption-tags"),
          image: position(".wyn-post-media-item"),
          actions: position(".wyn-post-actions"),
          bookmark: position(".wyn-action-save"),
          font: getComputedStyle(caption).fontSize,
          nameFont: getComputedStyle(byline).fontSize,
          imageRadius: getComputedStyle(image).borderRadius,
          actionGap: getComputedStyle(actions).gap,
          overflow: outer.scrollWidth - outer.clientWidth,
        };
      };
      const home = measure(".wyn-home-fixture");
      const profile = measure(".wyn-profile-beta1");
      host.remove();
      return { home, profile };
    }, width);

    expect(layout.profile).toEqual(layout.home);
    expect(layout.home.avatar[2]).toBe(width <= 359 ? 34 : 40);
    expect(layout.home.caption[0]).toBe(width <= 359 ? 54 : width >= 681 ? 70 : 66);
    expect(layout.home.image[0]).toBe(layout.home.caption[0]);
    expect(layout.home.actions[0]).toBe(layout.home.caption[0]);
    expect(layout.home.image[1]).toBeGreaterThan(layout.home.tags[1]);
    expect(layout.home.font).toBe("16px");
    expect(layout.home.nameFont).toBe("15px");
    expect(layout.home.imageRadius).toBe("14px");
    expect(layout.home.actionGap).toBe(width <= 359 ? "16px" : "18px");
    expect(layout.home.overflow).toBeLessThanOrEqual(2);
  }
});
