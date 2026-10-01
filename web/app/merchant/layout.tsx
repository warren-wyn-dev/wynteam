import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "./merchant.css";

export const metadata: Metadata = {
  title: "WYNOS Merchant",
  applicationName: "WYNOS Merchant",
  description: "จัดการออเดอร์ เมนู ยอดขาย และการจัดส่งของ WYNOS Food",
  manifest: "/merchant/manifest.webmanifest",
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
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#000000" },
  ],
};

export default function MerchantLayout({ children }: { children: ReactNode }) {
  return children;
}
