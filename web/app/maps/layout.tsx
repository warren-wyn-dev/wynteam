import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "../food/food.css";
import "./maps.css";
import "./maps-v2.css";

export const metadata: Metadata = {
  title: "WYNOS Maps",
  applicationName: "WYNOS Maps",
  description: "ค้นหา สำรวจ และเลือกตำแหน่งบน WYNOS Maps",
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
  interactiveWidget: "resizes-content",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#0a9f52" },
    { media: "(prefers-color-scheme: dark)", color: "#0a9f52" },
  ],
};

export default function MapsLayout({ children }: { children: ReactNode }) {
  return children;
}
