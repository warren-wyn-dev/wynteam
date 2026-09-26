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
