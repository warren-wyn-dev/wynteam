import { expect, test } from "@playwright/test";

/**
 * Verification badge spacing: adjacent flex gap is 4px in all post-name
 * contexts. A second margin must not double the gap. The approved
 * profile header remains at 4px flex gap + 1px badge margin.
 *
 * Runs on iPhone WebKit, Android Chromium, and desktop Chromium.
 */
test.beforeEach(async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
});

test("Home author badge keeps exactly the 4px flex gap", async ({ page }) => {
  // Isolate a CSS fixture outside React: mutating a hydrated feed risks
  // React replacing injected nodes (notably in iPhone WebKit).
  const result = await page.evaluate(() => {
    const fixture = document.createElement("a");
    fixture.href = "#";
    fixture.className = "wyn-post-author-link";
    fixture.innerHTML =
      '<strong class="wyn-post-author-name">Wynos.online</strong>' +
      '<span class="route-verified wyn-post-verified" aria-label="ยืนยันแล้ว">✓</span>';
    document.body.appendChild(fixture);
    const name = fixture.querySelector(".wyn-post-author-name")!;
    const badge = fixture.querySelector(".route-verified")!;
    const nameBox = name.getBoundingClientRect();
    const badgeBox = badge.getBoundingClientRect();
    const result = {
      flexGap: getComputedStyle(fixture).gap,
      margin: getComputedStyle(badge).marginLeft,
      background: getComputedStyle(badge).backgroundImage,
      width: badgeBox.width,
      gap: badgeBox.left - nameBox.right,
    };
    fixture.remove();
    return result;
  });

  expect(result.flexGap).toBe("4px");
  expect(result.margin).toBe("0px");
  expect(result.width).toBe(18);
  expect(result.background).toContain("verified-badge-v2.svg");
  expect(result.gap).toBeGreaterThanOrEqual(3.5);
  expect(result.gap).toBeLessThanOrEqual(4.5);
});

for (const className of ["golden-drop-head", "detail-author-primary"]) {
  test(`${className} badge does not double the existing 4px flex gap`, async ({ page }) => {
    const result = await page.evaluate((className) => {
      const fixture = document.createElement("div");
      fixture.className = className;
      fixture.innerHTML = className === "golden-drop-head"
        ? '<a href="#"><strong><span class="qa-name">Wynos.online</span><span class="route-verified">✓</span></strong></a>'
        : '<strong><span class="qa-name">Wynos.online</span><span class="route-verified">✓</span></strong>';
      document.body.appendChild(fixture);
      const name = fixture.querySelector(".qa-name")!;
      const badge = fixture.querySelector(".route-verified")!;
      const nameBox = name.getBoundingClientRect();
      const badgeBox = badge.getBoundingClientRect();
      const strong = fixture.querySelector("strong")!;
      const result = {
        flexGap: getComputedStyle(strong).gap,
        margin: getComputedStyle(badge).marginLeft,
        gap: badgeBox.left - nameBox.right,
        width: badgeBox.width,
      };
      fixture.remove();
      return result;
    }, className);

    expect(result.flexGap).toBe("4px");
    expect(result.margin).toBe("0px");
    expect(result.width).toBe(18);
    expect(result.gap).toBeGreaterThanOrEqual(3.5);
    expect(result.gap).toBeLessThanOrEqual(4.5);
  });
}

test("profile badge keeps existing 5px combined spacing", async ({ page }) => {
  const result = await page.evaluate(() => {
    const fixture = document.createElement("div");
    fixture.className = "wyn-profile-name";
    fixture.innerHTML = '<span class="qa-profile-name">Wynos.online</span><span class="route-verified">✓</span>';
    document.body.appendChild(fixture);
    const name = fixture.querySelector(".qa-profile-name")!;
    const badge = fixture.querySelector(".route-verified")!;
    const nameBounds = name.getBoundingClientRect();
    const badgeBounds = badge.getBoundingClientRect();
    const result = {
      flexGap: getComputedStyle(fixture).gap,
      margin: getComputedStyle(badge).marginLeft,
      gap: badgeBounds.left - nameBounds.right,
      size: badgeBounds.width,
    };
    fixture.remove();
    return result;
  });
  expect(result.flexGap).toBe("4px");
  expect(result.margin).toBe("1px");
  expect(result.gap).toBeGreaterThanOrEqual(4.5);
  expect(result.gap).toBeLessThanOrEqual(5.5);
  expect(result.size).toBe(21);
});

test("Beta1 profile and post badges both show the shared white-check SVG", async ({ page }) => {
  const result = await page.evaluate(() => {
    const wrapper = document.createElement("div");
    wrapper.className = "wyn-profile-beta1";
    wrapper.innerHTML = `
      <div class="wyn-profile-name"><span>Wynos.online</span><span class="route-verified" aria-label="ยืนยันแล้ว">✓</span></div>
      <div class="profile-feed-list"><div class="golden-drop-head"><strong><span>Wynos.online</span><span class="route-verified" aria-label="ยืนยันแล้ว">✓</span></strong></div></div>
    `;
    document.body.appendChild(wrapper);
    const [profileBadge, feedBadge] = Array.from(wrapper.querySelectorAll<HTMLElement>(".route-verified"));
    const value = (badge: HTMLElement) => ({
      background: getComputedStyle(badge).backgroundImage,
      fontSize: getComputedStyle(badge).fontSize,
      color: getComputedStyle(badge).color,
      width: badge.getBoundingClientRect().width,
    });
    const output = { profile: value(profileBadge), feed: value(feedBadge) };
    wrapper.remove();
    return output;
  });
  expect(result.profile.background).toContain("verified-badge-v2.svg");
  expect(result.feed.background).toContain("verified-badge-v2.svg");
  expect(result.profile.fontSize).toBe("0px");
  expect(result.feed.fontSize).toBe("0px");
  expect(result.profile.width).toBe(22);
  expect(result.feed.width).toBe(18);
});
