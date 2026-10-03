import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "./merchant.css";

const MERCHANT_ICON_192 = "/merchant/icon-v6?size=192";
const MERCHANT_ICON_512 = "/merchant/icon-v6?size=512";
const MERCHANT_APPLE_TOUCH_ICON = "/merchant/icon-v6?size=180";

export const metadata: Metadata = {
  title: "WYNOS Merchant",
  applicationName: "WYNOS Merchant",
  description: "จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
  manifest: "/merchant/manifest.webmanifest?v=20261004-6",
  icons: {
    icon: [
      { url: MERCHANT_ICON_192, sizes: "192x192", type: "image/png" },
      { url: MERCHANT_ICON_512, sizes: "512x512", type: "image/png" },
    ],
    apple: [
      { url: MERCHANT_APPLE_TOUCH_ICON, sizes: "180x180", type: "image/png" },
    ],
    other: [
      { rel: "apple-touch-icon-precomposed", url: MERCHANT_APPLE_TOUCH_ICON, sizes: "180x180", type: "image/png" },
    ],
  },
  openGraph: {
    title: "WYNOS Merchant",
    description: "จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
    images: [{ url: MERCHANT_ICON_512, width: 512, height: 512, alt: "WYNOS Merchant" }],
    type: "website",
  },
  twitter: {
    card: "summary",
    title: "WYNOS Merchant",
    description: "จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
    images: [MERCHANT_ICON_512],
  },
  robots: { index: false, follow: false },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "WYNOS Merchant",
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

export default function MerchantLayout({ children }: { children: ReactNode }) {
  return children;
}
