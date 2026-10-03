import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "./merchant.css";

const MERCHANT_ICON_192 = "/icons/merchant/merchant-app-v2-192.png";
const MERCHANT_ICON_512 = "/icons/merchant/merchant-app-v2-512.png";

export const metadata: Metadata = {
  title: "WYNOS Merchant",
  applicationName: "WYNOS Merchant",
  description: "จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
  manifest: "/merchant/manifest.webmanifest?v=20261003-2",
  icons: {
    icon: [
      { url: MERCHANT_ICON_192, sizes: "192x192", type: "image/png" },
      { url: MERCHANT_ICON_512, sizes: "512x512", type: "image/png" },
    ],
    apple: [{ url: MERCHANT_ICON_192, sizes: "192x192", type: "image/png" }],
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
