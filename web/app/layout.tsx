import type { Metadata, Viewport } from "next";
import "./globals.css";
import "./phase2.css";
import "./phase2-polish.css";
import "./phase3.css";
import "./phase3-bridge.css";
import "./parity.css";

export const metadata: Metadata = {
  title: "WYNOS",
  description: "WYNOS social web",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#ffffff",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="th">
      <body>{children}</body>
    </html>
  );
}
