import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "./merchant.css";

const MERCHANT_ICON = (size: number) => `/merchant/icon-v8?size=${size}`;

export const metadata: Metadata = {
  title: "Wynos Merchant",
  applicationName: "Wynos Merchant",
  description: "จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
  manifest: "/merchant/manifest.webmanifest?v=20261004-8",
  icons: {
    icon: [
      { url: MERCHANT_ICON(16), sizes: "16x16", type: "image/png" },
      { url: MERCHANT_ICON(32), sizes: "32x32", type: "image/png" },
      { url: MERCHANT_ICON(48), sizes: "48x48", type: "image/png" },
      { url: MERCHANT_ICON(192), sizes: "192x192", type: "image/png" },
      { url: MERCHANT_ICON(512), sizes: "512x512", type: "image/png" },
    ],
    shortcut: [{ url: MERCHANT_ICON(32), sizes: "32x32", type: "image/png" }],
    apple: [
      { url: MERCHANT_ICON(57), sizes: "57x57", type: "image/png" },
      { url: MERCHANT_ICON(72), sizes: "72x72", type: "image/png" },
      { url: MERCHANT_ICON(76), sizes: "76x76", type: "image/png" },
      { url: MERCHANT_ICON(114), sizes: "114x114", type: "image/png" },
      { url: MERCHANT_ICON(120), sizes: "120x120", type: "image/png" },
      { url: MERCHANT_ICON(152), sizes: "152x152", type: "image/png" },
      { url: MERCHANT_ICON(167), sizes: "167x167", type: "image/png" },
      { url: MERCHANT_ICON(180), sizes: "180x180", type: "image/png" },
    ],
    other: [
      { rel: "apple-touch-icon-precomposed", url: MERCHANT_ICON(180), sizes: "180x180", type: "image/png" },
    ],
  },
  openGraph: {
    title: "Wynos Merchant",
    description: "จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
    images: [{ url: MERCHANT_ICON(512), width: 512, height: 512, alt: "Wynos Merchant" }],
    type: "website",
  },
  twitter: {
    card: "summary",
    title: "Wynos Merchant",
    description: "จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
    images: [MERCHANT_ICON(512)],
  },
  robots: { index: false, follow: false },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Wynos Merchant",
  },
  other: {
    "msapplication-TileColor": "#e32636",
    "msapplication-TileImage": MERCHANT_ICON(144),
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
