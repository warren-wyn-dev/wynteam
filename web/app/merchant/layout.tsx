import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "../food/food.css";
import "./merchant.css";

const MERCHANT_ICON_180 = "/icons/merchant/v16-180.png";
const MERCHANT_ICON_192 = "/icons/merchant/v16-192.png";
const MERCHANT_ICON_512 = "/icons/merchant/v16-512.png";

export const metadata: Metadata = {
  metadataBase: new URL("https://merchant.wynos.online"),
  title: "Zoky Merchant | ระบบร้านอาหาร ZOKY",
  applicationName: "Zoky Merchant",
  description:
    "Zoky Merchant (wynosmerchant) ระบบสำหรับร้านอาหารและ Merchant ของ ZOKY จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ ZOKY",
  keywords: [
    "Zoky Merchant",
    "wynosmerchant",
    "wynos merchant",
    "ร้านอาหาร ZOKY",
    "ระบบร้านอาหาร",
    "ZOKY Merchant",
  ],
  alternates: {
    canonical: "https://merchant.wynos.online/",
  },
  openGraph: {
    type: "website",
    url: "https://merchant.wynos.online/",
    siteName: "Zoky Merchant",
    title: "Zoky Merchant | ระบบร้านอาหาร ZOKY",
    description: "ระบบสำหรับร้านอาหารและ Merchant ของ ZOKY ที่ merchant.wynos.online",
  },
  twitter: {
    card: "summary",
    title: "Zoky Merchant | ระบบร้านอาหาร ZOKY",
    description: "ระบบสำหรับร้านอาหารและ Merchant ของ ZOKY ที่ merchant.wynos.online",
  },
  manifest: "/merchant/manifest.webmanifest?v=16",
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
    title: "Zoky Merchant",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
  themeColor: "#ee1228",
  colorScheme: "light",
};

// WYN-204: Merchant is light only, whatever the phone or WYN theme says.
export default function MerchantLayout({ children }: { children: ReactNode }) {
  return <div className="wm-force-light">{children}</div>;
}
