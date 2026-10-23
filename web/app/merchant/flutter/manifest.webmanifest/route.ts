import merchantManifest from "../../manifest";

export function GET() {
  return Response.json({
    ...merchantManifest(),
    name: "Zoky Merchant",
    short_name: "Zoky Merchant",
    start_url: "/merchant/flutter",
    background_color: "#ffffff",
    theme_color: "#f93384",
  }, { headers: { "Content-Type": "application/manifest+json", "Cache-Control": "public, max-age=0, must-revalidate" } });
}
