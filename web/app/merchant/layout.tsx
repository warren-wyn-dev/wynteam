import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "../food/food.css";
import "./merchant.css";

const MERCHANT_ICON_180 = "/icons/merchant/v15-180.png";
const MERCHANT_ICON_192 = "/icons/merchant/v15-192.png";
const MERCHANT_ICON_512 = "/icons/merchant/v15-512.png";

export const metadata: Metadata = {
  metadataBase: new URL("https://merchant.wynos.online"),
  title: "WYNOS Merchant | ระบบร้านอาหาร WYNOS",
  applicationName: "WYNOS Merchant",
  description:
    "WYNOS Merchant (wynosmerchant) ระบบสำหรับร้านอาหารและ Merchant ของ WYNOS จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
  keywords: [
    "WYNOS Merchant",
    "wynosmerchant",
    "wynos merchant",
    "ร้านอาหาร WYNOS",
    "ระบบร้านอาหาร",
    "WYNOS Food Merchant",
  ],
  alternates: {
    canonical: "https://merchant.wynos.online/",
  },
  openGraph: {
    type: "website",
    url: "https://merchant.wynos.online/",
    siteName: "WYNOS Merchant",
    title: "WYNOS Merchant | ระบบร้านอาหาร WYNOS",
    description: "ระบบสำหรับร้านอาหารและ Merchant ของ WYNOS ที่ merchant.wynos.online",
  },
  twitter: {
    card: "summary",
    title: "WYNOS Merchant | ระบบร้านอาหาร WYNOS",
    description: "ระบบสำหรับร้านอาหารและ Merchant ของ WYNOS ที่ merchant.wynos.online",
  },
  manifest: "/merchant/manifest.webmanifest?v=15",
  icons: {
    icon: [
      { url: MERCHANT_ICON_192, sizes: "192x192", type: "image/png" },
      { url: MERCHANT_ICON_512, sizes: "512x512", type: "image/png" },
    ],
    shortcut: [
      { url: MERCHANT_ICON_192, sizes: "192x192", type: "image/png" },
    ],
    apple: [
      { url: MERCHANT_ICON_180, sizes: "180x180", type: "image/png" },
    ],
    other: [
      {
        rel: "apple-touch-icon-precomposed",
        url: MERCHANT_ICON_180,
        sizes: "180x180",
        type: "image/png",
      },
    ],
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Wynos Merchant",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#ee1228",
  colorScheme: "light",
};

// WYN-204: Merchant is light only, whatever the phone or WYN theme says.
export default function MerchantLayout({ children }: { children: ReactNode }) {
  return <div className="wm-force-light">{children}</div>;
}
