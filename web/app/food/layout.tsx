import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "./food.css";

export const metadata: Metadata = {
  title: "WYNOS Food · Developer Preview",
  applicationName: "WYNOS Food",
  description: "WYNOS Food closed developer preview",
  manifest: "/food/manifest.webmanifest",
  robots: { index: false, follow: false },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "WYNOS Food",
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

export default function FoodLayout({ children }: { children: ReactNode }) {
  return children;
}
