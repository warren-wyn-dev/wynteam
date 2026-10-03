import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/merchant",
    name: "Wynos Merchant",
    short_name: "Wynos Merchant",
    description: "จัดการร้าน WYNOS Food",
    start_url: "/merchant",
    scope: "/merchant",
    display: "standalone",
    background_color: "#ee1228",
    theme_color: "#ee1228",
    lang: "th",
    orientation: "portrait",
    icons: [
      { src: "/icons/merchant/v14-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/merchant/v14-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icons/merchant/v14-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
