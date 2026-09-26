import { expect, test } from "@playwright/test";

const ID = "11111111-1111-4111-8111-111111111111";

// Shared profile links are "/@username". Next hands the segment over still
// URL-encoded, and the page used to 404 every one of them.
test("a shared /@username profile link is not a 404", async ({ request }) => {
  for (const path of ["/@wynos_s", "/%40wynos_s", "/@%E0%B8%A3%E0%B8%B2%E0%B8%A2%E0%B8%8A%E0%B8%B7%E0%B9%88%E0%B8%AD"]) {
    const response = await request.get(path);
    expect(response.status(), path).toBe(200);
  }
  expect((await request.get("/not-a-profile")).status()).toBe(404);
});

function meta(html: string, property: string): string | undefined {
  const tag = html.match(new RegExp(`<meta[^>]+(?:property|name)="${property}"[^>]*>`))?.[0];
  return tag?.match(/content="([^"]*)"/)?.[1];
}

for (const [path, title] of [
  [`/drop/${ID}`, "โพสต์บน WYNOS"],
  ["/@wynos_s", "@wynos_s บน WYNOS"],
  [`/club/${ID}`, "Club บน WYNOS"],
  [`/club-post/${ID}`, "โพสต์ใน Club บน WYNOS"],
  [`/quote/${ID}`, "WYNOS — โพสต์อ้างอิง"],
  ["/club-invite/ABC123", "คำเชิญเข้าร่วม Club บน WYNOS"],
  [`/pop/${ID}`, "Pop บน WYNOS"],
] as const) {
  test(`${path} has a branded link preview for LINE/Facebook/Messenger`, async ({ request }) => {
    const html = await (await request.get(path, { headers: { "user-agent": "facebookexternalhit/1.1" } })).text();
    expect(meta(html, "og:title")).toBe(title);
    expect(meta(html, "og:site_name")).toBe("WYNOS");
    expect(meta(html, "og:url")).toBe(`https://wynos.online${path}`);
    expect(meta(html, "og:image")).toBe("https://wynos.online/icons/icon-512.png");
    expect(meta(html, "twitter:card")).toBe("summary");
  });
}

test("routes without their own metadata never claim the home page URL", async ({ request }) => {
  for (const path of ["/search", "/trending"]) {
    const html = await (await request.get(path)).text();
    expect(meta(html, "og:url"), path).toBeUndefined();
    expect(html, path).not.toContain('rel="canonical" href="https://wynos.online"');
  }
});

// LINE opens links in its own browser, which is never signed in to WYNOS and
// where Google sign-in is refused. `openExternalBrowser=1` makes LINE hand
// the page to Safari/Chrome.
const LINE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari Line/14.16.0";

test("a link opened inside LINE is sent on to Safari/Chrome, once", async ({ request }) => {
  const get = (path: string) => request.get(path, { headers: { "user-agent": LINE_UA }, maxRedirects: 0 });
  for (const [path, target] of [
    ["/@warren", "/@warren?openExternalBrowser=1"],
    [`/drop/${ID}?ref=share`, `/drop/${ID}?ref=share&openExternalBrowser=1`],
    ["/", "/?openExternalBrowser=1"],
  ] as const) {
    const response = await get(path);
    expect(response.status(), path).toBe(307);
    const location = new URL(response.headers().location, "https://wynos.online");
    const expected = new URL(target, "https://wynos.online");
    expect(location.pathname, path).toBe(expected.pathname);
    expect(Object.fromEntries(location.searchParams), path).toEqual(Object.fromEntries(expected.searchParams));
  }
  // Already flagged, OAuth return, OAuth callback, API and static files are left alone.
  for (const path of ["/@warren?openExternalBrowser=1", "/welcome?code=abc", "/auth/callback?code=abc", "/api/push-config", "/sw.js", "/icons/icon-512.png"]) {
    expect((await get(path)).status(), path).not.toBe(307);
  }
});

test("other browsers and link-preview bots are never redirected", async ({ request }) => {
  for (const ua of [
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1",
    "facebookexternalhit/1.1;line-poker/1.0",
  ]) {
    expect((await request.get("/@warren", { headers: { "user-agent": ua }, maxRedirects: 0 })).status(), ua).toBe(200);
  }
});

test.describe("inside an app browser without an external-browser switch", () => {
  test.use({ userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Instagram 350.0" });
  test("the welcome screen tells the visitor to open WYNOS in their browser", async ({ page }) => {
    await page.goto("/welcome");
    await expect(page.getByTestId("in-app-browser-notice")).toContainText("เปิดในเบราว์เซอร์ของ Instagram");
  });
});

test("a normal browser sees no in-app browser notice", async ({ page }) => {
  await page.goto("/welcome");
  await expect(page.getByRole("button", { name: "เข้าสู่ระบบ", exact: true })).toBeVisible();
  await expect(page.getByTestId("in-app-browser-notice")).toHaveCount(0);
});
