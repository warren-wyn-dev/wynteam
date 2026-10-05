import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "./food.css";

const FOOD_ICON = (size: number) => `/food/icon-v7?size=${size}`;

export const metadata: Metadata = {
  metadataBase: new URL("https://food.wynos.online"),
  title: "WYNOS Food | สั่งอาหารออนไลน์",
  applicationName: "WYNOS Food",
  description:
    "WYNOS Food (wynosfood) บริการสั่งอาหารออนไลน์จาก WYNOS ค้นหาร้านอาหาร เลือกเมนู และสั่งอาหารผ่าน food.wynos.online",
  keywords: [
    "WYNOS Food",
    "wynosfood",
    "wynos food",
    "สั่งอาหาร",
    "สั่งอาหารออนไลน์",
    "food delivery",
  ],
  alternates: {
    canonical: "https://food.wynos.online/",
  },
  openGraph: {
    type: "website",
    url: "https://food.wynos.online/",
    siteName: "WYNOS Food",
    title: "WYNOS Food | สั่งอาหารออนไลน์",
    description: "สั่งอาหารออนไลน์กับ WYNOS Food ที่ food.wynos.online",
    // Shared store links (/?store=<id>) preview in LINE/Messenger with the
    // Food icon; store details stay behind sign-in.
    images: [{ url: "/icons/food/icon-512.png", width: 512, height: 512, alt: "WYNOS Food" }],
  },
  twitter: {
    card: "summary",
    title: "WYNOS Food | สั่งอาหารออนไลน์",
    description: "สั่งอาหารออนไลน์กับ WYNOS Food ที่ food.wynos.online",
    images: ["/icons/food/icon-512.png"],
  },
  manifest: "/food/manifest.webmanifest?v=20261004-7",
  icons: {
    icon: [
      { url: FOOD_ICON(16), sizes: "16x16", type: "image/png" },
      { url: FOOD_ICON(32), sizes: "32x32", type: "image/png" },
      { url: FOOD_ICON(48), sizes: "48x48", type: "image/png" },
      { url: FOOD_ICON(192), sizes: "192x192", type: "image/png" },
      { url: FOOD_ICON(512), sizes: "512x512", type: "image/png" },
    ],
    shortcut: [{ url: FOOD_ICON(32), sizes: "32x32", type: "image/png" }],
    apple: [
      { url: FOOD_ICON(57), sizes: "57x57", type: "image/png" },
      { url: FOOD_ICON(72), sizes: "72x72", type: "image/png" },
      { url: FOOD_ICON(76), sizes: "76x76", type: "image/png" },
      { url: FOOD_ICON(114), sizes: "114x114", type: "image/png" },
      { url: FOOD_ICON(120), sizes: "120x120", type: "image/png" },
      { url: FOOD_ICON(152), sizes: "152x152", type: "image/png" },
      { url: FOOD_ICON(167), sizes: "167x167", type: "image/png" },
      { url: FOOD_ICON(180), sizes: "180x180", type: "image/png" },
    ],
    other: [
      { rel: "apple-touch-icon-precomposed", url: FOOD_ICON(180), sizes: "180x180", type: "image/png" },
    ],
  },
  robots: { index: true, follow: true },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "WYNOS Food",
  },
  other: {
    "msapplication-TileColor": "#e32636",
    "msapplication-TileImage": FOOD_ICON(144),
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
  interactiveWidget: "resizes-content",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#e32636" },
    { media: "(prefers-color-scheme: dark)", color: "#e32636" },
  ],
};

export default function FoodLayout({ children }: { children: ReactNode }) {
  return children;
}
