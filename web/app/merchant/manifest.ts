import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/merchant",
    name: "Zoky Merchant",
    short_name: "Zoky Merchant",
    description: "จัดการร้าน ZOKY",
    start_url: "/merchant",
    scope: "/merchant",
    display: "standalone",
    background_color: "#ee1228",
    theme_color: "#ee1228",
    lang: "th",
    orientation: "portrait",
    icons: [
      { src: "/icons/merchant/v16-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/merchant/v16-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icons/merchant/v16-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
