import type { MetadataRoute } from "next";

const FOOD_ICON_192 = "/icons/zoky/icon-192-v1.png";
const FOOD_ICON_512 = "/icons/zoky/icon-512-v1.png";
const FOOD_ICON_MASKABLE_512 = "/icons/zoky/icon-512-maskable-v1.png";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/",
    name: "ZOKY",
    short_name: "ZOKY",
    description: "ZOKY สั่งอาหาร (Public Beta)",
    start_url: "/",
    scope: "/",
    display: "standalone",
    background_color: "#f93384",
    theme_color: "#f93384",
    lang: "th",
    orientation: "portrait",
    icons: [
      { src: FOOD_ICON_192, sizes: "192x192", type: "image/png", purpose: "any" },
      { src: FOOD_ICON_512, sizes: "512x512", type: "image/png", purpose: "any" },
      { src: FOOD_ICON_MASKABLE_512, sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
