import type { Metadata, Viewport } from "next";

import { MerchantFlutterApp } from "@/components/merchant/merchant-flutter-app";

export const viewport: Viewport = { themeColor: "#f93384" };

export const metadata: Metadata = {
  title: "Zoky Merchant | จัดการร้านของคุณ",
  manifest: "/merchant/flutter/manifest.webmanifest",
  applicationName: "Zoky Merchant",
  // Founder 2026-11-01: the Zoky Merchant logo is the home-screen icon (v16).
  appleWebApp: { capable: true, statusBarStyle: "default", title: "Zoky Merchant" },
  robots: { index: false, follow: false },
};

export default function MerchantFlutterPage() {
  return <MerchantFlutterApp />;
}
