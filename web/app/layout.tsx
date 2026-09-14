import type { Metadata, Viewport } from "next";
import "./globals.css";
import "./design-system/tokens.css";
import "./phase2.css";
import "./phase2-polish.css";
import "./phase3.css";
import "./parity.css";
import "./parity-auth-email.css";
import "./parity-final.css";
import "./parity-completion.css";
import "./parity-closure.css";
import "./parity-audit.css";
import "./profile-follow-audit.css";
import "./club-audit.css";
import "./club-detail-audit.css";
import "./club-detail-golden.css";
import "./golden-drop-card.css";
import "./club-post-card-web.css";
import "./founder-parity-lock.css";
import "./system-parity-lock.css";
import "./system-parity-final.css";
import "./interaction-parity-final.css";
import "./pixel-parity-audit-closure.css";
// WYN-159 v2 restyle (Post Detail). Imported last so it wins the cascade
// over any remaining legacy declaration for the same selectors. Profile's
// v2 restyle lives in components/profile/profile.module.css (a CSS Module,
// scoped by build tooling rather than import order).
import "./post-detail-v2.css";

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
