import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "./merchant.css";

const MERCHANT_ICON_180 = "/icons/merchant/v14-180.png";
const MERCHANT_ICON_192 = "/icons/merchant/v14-192.png";
const MERCHANT_ICON_512 = "/icons/merchant/v14-512.png";

export const metadata: Metadata = {
  title: "Wynos Merchant",
  applicationName: "Wynos Merchant",
  description: "จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
  manifest: "/merchant/manifest.webmanifest?v=14",
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
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
  themeColor: "#ee1228",
};

export default function MerchantLayout({ children }: { children: ReactNode }) {
  return children;
}
