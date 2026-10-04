import { headers } from "next/headers";

export const dynamic = "force-dynamic";

const URL_BY_HOST: Record<string, string> = {
  "wynos.online": "https://wynos.online/",
  "www.wynos.online": "https://wynos.online/",
  "food.wynos.online": "https://food.wynos.online/",
  "merchant.wynos.online": "https://merchant.wynos.online/",
  "maps.wynos.online": "https://maps.wynos.online/",
};

export async function GET() {
  const headerList = await headers();
  const host = headerList.get("host")?.split(":")[0].toLowerCase() ?? "wynos.online";
  const url = URL_BY_HOST[host] ?? "https://wynos.online/";
  const lastmod = new Date().toISOString();

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${url}</loc>
    <lastmod>${lastmod}</lastmod>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>`;

  return new Response(xml, {
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
      "Cache-Control": "public, s-maxage=3600, stale-while-revalidate=86400",
    },
  });
}
