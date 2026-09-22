import { expect, test } from "@playwright/test";

/**
 * Verified badge spacing: the flex Home row already supplies a 4px gap,
 * while inline post names need an explicit 2px margin. The profile header
 * keeps its approved 4px flex gap + 1px badge margin.
 *
 * Runs on iPhone WebKit, Android Chromium and desktop Chromium.
 */
test.beforeEach(async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "domcontentloaded" });
});

test("Home author badge keeps exactly the 4px flex gap", async ({ page }) => {
  const author = page.locator(".wyn-post-author-link").first();
  await expect(author).toBeVisible();
  await author.evaluate((link) => {
    const name = link.querySelector(".wyn-post-author-name");
    if (!name) throw new Error("Home author name was not rendered");
    link.querySelector(".route-verified")?.remove();
    const badge = document.createElement("span");
    badge.className = "route-verified wyn-post-verified";
    badge.textContent = "✓";
    name.insertAdjacentElement("afterend", badge);
  });

  const name = author.locator(".wyn-post-author-name");
  const badge = author.locator(".route-verified");
  await expect(author).toHaveCSS("gap", "4px");
  await expect(badge).toHaveCSS("margin-left", "0px");
  await expect(badge).toHaveCSS("width", "18px");
  await expect(badge).toHaveCSS("background-image", /verified-badge-v2\.svg/);
  const [nameBox, badgeBox] = await Promise.all([name.boundingBox(), badge.boundingBox()]);
  expect(nameBox).not.toBeNull();
  expect(badgeBox).not.toBeNull();
  const actualGap = badgeBox!.x - (nameBox!.x + nameBox!.width);
  expect(actualGap).toBeGreaterThanOrEqual(3.5);
  expect(actualGap).toBeLessThanOrEqual(4.5);
});

test("inline post/detail badges use 2px rather than the old 4px gap", async ({ page }) => {
  const inlineGap = await page.evaluate(() => {
    const fixture = document.createElement("div");
    fixture.className = "golden-drop-head";
    fixture.innerHTML = '<a href="#"><strong><span class="qa-name">Wynos.online</span><span class="route-verified">✓</span></strong></a>';
    document.body.appendChild(fixture);
    const name = fixture.querySelector(".qa-name")!;
    const badge = fixture.querySelector(".route-verified")!;
    const bounds = name.getBoundingClientRect();
    const badgeBounds = badge.getBoundingClientRect();
    const result = {
      margin: getComputedStyle(badge).marginLeft,
      gap: badgeBounds.left - bounds.right,
    };
    fixture.remove();
    return result;
  });
  expect(inlineGap.margin).toBe("2px");
  expect(inlineGap.gap).toBeGreaterThanOrEqual(1.5);
  expect(inlineGap.gap).toBeLessThanOrEqual(2.5);
});

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
