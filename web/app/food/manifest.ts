import type { MetadataRoute } from "next";

const FOOD_ICON_192 = "/food/icon-v7?size=192";
const FOOD_ICON_512 = "/food/icon-v7?size=512";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/food",
    name: "WYNOS Food",
    short_name: "WYNOS Food",
    description: "WYNOS Food Developer Preview",
    start_url: "/food",
    scope: "/food",
    display: "standalone",
    background_color: "#e32636",
    theme_color: "#e32636",
    lang: "th",
    orientation: "portrait",
    icons: [
      { src: FOOD_ICON_192, sizes: "192x192", type: "image/png", purpose: "any" },
      { src: FOOD_ICON_512, sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icons/food/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
