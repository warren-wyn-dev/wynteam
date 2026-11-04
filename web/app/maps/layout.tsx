import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";

import "../food/food.css";
import "./maps.css";
import "./maps-v2.css";
import "./maps-v3.css";
import "./maps-v4.css";
import "./maps-v5.css";
import "./maps-v6.css";

export const metadata: Metadata = {
  title: "Wyn Maps",
  applicationName: "Wyn Maps",
  description: "ค้นหา สำรวจ และเลือกตำแหน่งบน Wyn Maps",
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
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#000000" },
  ],
};

export default function MapsLayout({ children }: { children: ReactNode }) {
  return children;
}
