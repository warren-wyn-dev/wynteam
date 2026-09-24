import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

const read = (relative: string) => readFileSync(path.join(process.cwd(), relative), "utf8");

test("Search is an actual search control, not a Safari credential form", () => {
  const source = read("components/search-route.tsx");
  expect(source).toContain('<div className="search-route-form" role="search">');
  expect(source).toContain('type="search" name="search_query"');
  expect(source).toContain('autoComplete="off"');
  expect(source).toContain('autoCorrect="off"');
  expect(source).toContain('enterKeyHint="search"');
  expect(source).toContain('if (event.key === "Enter") { event.preventDefault(); submitNow(); }');
  expect(source).not.toContain('<form className="search-route-form"');
});

test("Following and Followers list badges stay adjacent and centered without row dividers", async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });
  for (const width of [320, 390, 432]) {
    await page.setViewportSize({ width, height: 830 });
    const result = await page.evaluate((width) => {
      const fixture = document.createElement("div");
      fixture.style.cssText = "width:" + width + "px;position:fixed;top:0;left:0;visibility:hidden";
      fixture.innerHTML = '<div class="follow-list-route">' +
        ["followers", "following"].map((kind) =>
          '<div class="follow-list-row" data-kind="' + kind + '">' +
          '<a class="follow-list-person"><span class="route-avatar" style="display:block;width:44px;height:44px;flex:none"></span>' +
          '<span class="follow-list-person-copy"><strong class="follow-list-person-name">' +
          '<span class="follow-list-display-name">WYNOS Official with a particularly long visible display name</span>' +
          '<b class="route-verified">✓</b></strong><small>@wynos_s</small></span></a>' +
          '<button class="follow-pill requested">ติดตามแล้ว</button></div>',
        ).join("") + "</div>";
      document.body.appendChild(fixture);
      const measurements = [...fixture.querySelectorAll<HTMLElement>(".follow-list-row")].map((row) => {
        const name = row.querySelector<HTMLElement>(".follow-list-display-name")!.getBoundingClientRect();
        const badge = row.querySelector<HTMLElement>(".route-verified")!.getBoundingClientRect();
        const strong = row.querySelector<HTMLElement>(".follow-list-person-name")!;
        return {
          border: getComputedStyle(row).borderBottomWidth,
          layout: getComputedStyle(strong).display,
          gap: badge.left - name.right,
          verticalOffset: Math.abs((badge.top + badge.bottom - name.top - name.bottom) / 2),
          badgeSize: [badge.width, badge.height],
          overflow: fixture.scrollWidth - fixture.clientWidth,
        };
      });
      fixture.remove();
      return measurements;
    }, width);
    expect(result).toHaveLength(2);
    for (const row of result) {
      expect(row.border).toBe("0px");
      expect(["flex", "inline-flex"]).toContain(row.layout);
      expect(row.gap).toBeGreaterThanOrEqual(3.5);
      expect(row.gap).toBeLessThanOrEqual(4.5);
      expect(row.verticalOffset).toBeLessThanOrEqual(1);
      expect(row.badgeSize).toEqual([14, 14]);
      expect(row.overflow).toBeLessThanOrEqual(1);
    }
  }
});

test("Follow mutation reconciles authoritative state and invalidates cached profile counts", () => {
  const actions = read("lib/home-actions.ts");
  const query = read("components/query-provider.tsx");
  const profile = read("components/profile-route.tsx");
  const cache = read("lib/follow-state.ts");
  expect(actions).toContain('const actuallyFollowing = Boolean(existing.data);');
  expect(actions).toContain('ignoreDuplicates: true');
  expect(cache).toContain('deleteMountCacheByPrefix("search-users:"');
  expect(cache).toContain('deleteMountCacheByPrefix("follow-list:"');
  expect(query).toContain('client.invalidateQueries({ queryKey: ["profile-summary"] })');
  expect(profile).toContain('refetchOnMount: "always"');
  expect(profile).toContain('await refetch(); // server-count reconciliation');
});
