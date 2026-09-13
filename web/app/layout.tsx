import type { Metadata, Viewport } from "next";
import "./globals.css";
import "./phase2.css";
import "./phase2-polish.css";
import "./phase3.css";
import "./phase3-bridge.css";
import "./parity.css";
import "./parity-auth-email.css";
import "./parity-final.css";
import "./parity-fixes.css";
import "./parity-completion.css";
import "./parity-closure.css";
import "./post-detail-parity.css";
import "./parity-audit.css";
import "./profile-follow-audit.css";
import "./club-audit.css";
import "./club-detail-audit.css";
import "./home-golden-final.css";
import "./profile-golden-final.css";
import "./club-detail-golden.css";
import "./golden-drop-card.css";
import "./club-post-card-web.css";

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
