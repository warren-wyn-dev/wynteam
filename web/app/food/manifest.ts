import type { MetadataRoute } from "next";

const FOOD_ICON_192 = "/icons/food/icon-192-v9.png";
const FOOD_ICON_512 = "/icons/food/icon-512-v9.png";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/",
    name: "WYNOS Food",
    short_name: "WYNOS Food",
    description: "WYNOS Food Public Beta",
    start_url: "/",
    scope: "/",
    display: "standalone",
    background_color: "#e32636",
    theme_color: "#e32636",
    lang: "th",
    orientation: "portrait",
    icons: [
      { src: FOOD_ICON_192, sizes: "192x192", type: "image/png", purpose: "any" },
      { src: FOOD_ICON_512, sizes: "512x512", type: "image/png", purpose: "any" },
      { src: FOOD_ICON_512, sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
