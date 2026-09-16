import type { Metadata, Viewport } from "next";
import { AppNavigationRuntime } from "@/components/app-navigation-runtime";
import { QueryProvider } from "@/components/query-provider";
import { SwipeBackGesture } from "@/components/swipe-back-gesture";
import { PageTransition } from "@/components/ui/page-transition";
import "./globals.css";
import "./phase2.css";
import "./phase2-polish.css";
import "./phase3.css";
import "./parity.css";
import "./parity-auth-email.css";
import "./parity-final.css";
import "./parity-completion.css";
import "./parity-closure.css";
import "./post-detail-parity.css";
import "./parity-audit.css";
import "./profile-follow-audit.css";
import "./club-audit.css";
import "./club-detail-audit.css";
import "./profile-golden-final.css";
import "./club-detail-golden.css";
import "./golden-drop-card.css";
import "./club-post-card-web.css";
import "./founder-parity-lock.css";
import "./system-parity-lock.css";
import "./system-parity-final.css";
import "./interaction-parity-final.css";
import "./pixel-parity-final.css";
import "./pixel-parity-audit-closure.css";
import "./bottom-nav.css";
import "./home.css";
import "./design-system.css";
import "./auth-reference.css";
import "./content-reference.css";
import "./profile-reference.css";
import "./club-reference.css";
import "./chat-reference.css";
import "./threads-action-row.css";
import "./profile-home-feed.css";
import "./notifications-clean.css";
import "./skeleton.css";
// This Next.js version's `appleWebApp` metadata only emits the generic
// `mobile-web-app-capable` tag (see node_modules/next/dist/docs/01-app/
// 03-api-reference/04-functions/generate-metadata.md, "appleWebApp") and
// drops `apple-mobile-web-app-capable`, which iOS Safari actually needs to
// launch a home-screen icon in standalone mode instead of inside Safari's
// own browser chrome. Added back explicitly via `other`.
export const metadata:Metadata={title:"WYNOS",description:"WYNOS social web",appleWebApp:{capable:true,statusBarStyle:"default",title:"WYNOS"},other:{"apple-mobile-web-app-capable":"yes"}};
export const viewport:Viewport={width:"device-width",initialScale:1,viewportFit:"cover",themeColor:[{media:"(prefers-color-scheme: light)",color:"#ffffff"},{media:"(prefers-color-scheme: dark)",color:"#000000"}]};
export default function RootLayout({children}:Readonly<{children:React.ReactNode}>){return <html lang="th"><body><QueryProvider><AppNavigationRuntime /><SwipeBackGesture /><PageTransition>{children}</PageTransition></QueryProvider></body></html>}
