import { expect, test } from "@playwright/test";

// WEB-B1-QA-01: no third-party page may frame a WYNOS session.
for (const path of ["/", "/welcome", "/notifications"]) {
  test(`${path} is served with anti-framing and nosniff headers`, async ({ request }) => {
    const response = await request.get(path, { maxRedirects: 0 });
    const headers = response.headers();
    expect(headers["x-frame-options"]).toBe("DENY");
    expect(headers["content-security-policy"]).toContain("frame-ancestors 'none'");
    expect(headers["x-content-type-options"]).toBe("nosniff");
    expect(headers["referrer-policy"]).toBe("strict-origin-when-cross-origin");
  });
}

test("a cross-origin page cannot embed WYNOS in an iframe", async ({ page, baseURL }) => {
  await page.setContent(`<iframe id="victim" src="${baseURL}/welcome" width="390" height="600"></iframe>`);
  await page.waitForTimeout(1500);
  const frame = page.frames().find((f) => f.url().includes("/welcome"));
  const rendered = frame ? await frame.locator("body *").count().catch(() => 0) : 0;
  expect(rendered).toBe(0);
});
