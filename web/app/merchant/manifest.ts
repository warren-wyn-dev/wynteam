import type { MetadataRoute } from "next";

const MERCHANT_ICON_192 = "/merchant/icon-v11?size=192";
const MERCHANT_ICON_512 = "/merchant/icon-v11?size=512";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/merchant",
    name: "Wynos Merchant",
    short_name: "Wynos Merchant",
    description: "จัดการร้าน WYNOS Food",
    start_url: "/merchant",
    scope: "/merchant",
    display: "standalone",
    background_color: "#e32636",
    theme_color: "#e32636",
    lang: "th",
    orientation: "portrait",
    icons: [
      { src: MERCHANT_ICON_192, sizes: "192x192", type: "image/png", purpose: "any" },
      { src: MERCHANT_ICON_512, sizes: "512x512", type: "image/png", purpose: "any" },
      { src: MERCHANT_ICON_512, sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
