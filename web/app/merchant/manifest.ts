import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/merchant",
    name: "WYNOS Merchant",
    short_name: "Merchant",
    description: "จัดการร้าน WYNOS Food",
    start_url: "/merchant",
    scope: "/merchant",
    display: "standalone",
    background_color: "#ffffff",
    theme_color: "#e32636",
    lang: "th",
    orientation: "portrait",
    icons: [
      { src: "/icons/merchant/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/merchant/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any maskable" },
    ],
  };
}
