import type { MetadataRoute } from "next";

const WYNOS_ICON_192 = "/app-icon-v7?size=192";
const WYNOS_ICON_512 = "/app-icon-v7?size=512";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "WYNOS",
    short_name: "WYNOS",
    description: "WYNOS — chat, profile และ feed ในที่เดียว",
    start_url: "/",
    scope: "/",
    display: "standalone",
    background_color: "#ffffff",
    theme_color: "#ffffff",
    lang: "th",
    icons: [
      { src: WYNOS_ICON_192, sizes: "192x192", type: "image/png", purpose: "any" },
      { src: WYNOS_ICON_512, sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icons/icon-512-maskable.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
