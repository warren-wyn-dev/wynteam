import type { Metadata, Viewport } from "next";
import Image from "next/image";
import { Anuphan } from "next/font/google";
import type { ReactNode } from "react";

import "./food.css";
import "./food-app.css";

// Thai loopless face for the redesigned Food app; self-hosted by next/font at build time.
const anuphan = Anuphan({
  subsets: ["thai", "latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
  variable: "--font-anuphan",
});

const FOOD_ICON_32 = "/icons/food/icon-32-v12.png";
const FOOD_ICON_192 = "/icons/food/icon-192-v12.png";
const FOOD_ICON_512 = "/icons/food/icon-512-v12.png";

// Founder decision (2026-10-11): show a brand splash (logo only) when Food opens.
// It plays once per browser session; the boot script marks <html> before the
// splash paints so later loads in the same session skip it without a flash.
// While the splash shows, a temporary pink theme-color (prepended, so iOS uses
// it first) keeps the status-bar strip the same pink as the splash top; it is
// removed when the splash fades so the app keeps its normal theme color.
// The splash waits for the screen underneath to report its data is ready
// (markFoodSplashReady in lib/food-splash.ts): at least 1 s, at most ~4 s.
const FOOD_SPLASH_BOOT_SCRIPT =
  "try{var d=document.documentElement;if(sessionStorage.getItem('wynos-food-splash')){d.setAttribute('data-fx-splash','seen')}else{sessionStorage.setItem('wynos-food-splash','1');var m=document.createElement('meta');m.name='theme-color';m.content='#ff7aa6';m.setAttribute('data-fx-splash-theme','');document.head.prepend(m);var t=Date.now(),r=0;window.__fxSplashReady=function(){if(r)return;r=1;setTimeout(function(){d.setAttribute('data-fx-splash-ready','');setTimeout(function(){m.remove()},350)},Math.max(0,1000-(Date.now()-t)))};setTimeout(window.__fxSplashReady,4000)}}catch(e){}";

// iOS shows these while the installed app launches (it ignores the manifest
// background), so there is no white flash before the splash. One image per
// iPhone screen size; see public/icons/food/splash/.
const FOOD_IOS_LAUNCH_SIZES: Array<[number, number, number]> = [
  [440, 956, 3], [430, 932, 3], [428, 926, 3], [420, 912, 3], [414, 896, 3], [414, 896, 2],
  [414, 736, 3], [402, 874, 3], [393, 852, 3], [390, 844, 3], [375, 812, 3], [360, 780, 3], [375, 667, 2], [320, 568, 2],
];
const FOOD_IOS_LAUNCH_IMAGES = FOOD_IOS_LAUNCH_SIZES.map(([width, height, ratio]) => ({
  url: `/icons/food/splash/launch-${width * ratio}x${height * ratio}.png`,
  media: `(device-width: ${width}px) and (device-height: ${height}px) and (-webkit-device-pixel-ratio: ${ratio}) and (orientation: portrait)`,
}));

const FOOD_WEBSITE_STRUCTURED_DATA = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: "WYNOS Food",
  alternateName: ["Wynos Food", "WYNOS Food • สั่งอาหาร"],
  url: "https://food.wynos.online/",
};

export const metadata: Metadata = {
  metadataBase: new URL("https://food.wynos.online"),
  title: "WYNOS Food • สั่งอาหาร",
  applicationName: "WYNOS Food",
  description:
    "WYNOS Food (wynosfood) บริการสั่งอาหารออนไลน์จาก WYNOS ค้นหาร้านอาหาร เลือกเมนู และสั่งอาหารผ่าน food.wynos.online",
  keywords: [
    "WYNOS Food",
    "wynosfood",
    "wynos food",
    "สั่งอาหาร",
    "สั่งอาหารออนไลน์",
    "food delivery",
  ],
  alternates: {
    canonical: "https://food.wynos.online/",
  },
  openGraph: {
    type: "website",
    url: "https://food.wynos.online/",
    siteName: "WYNOS Food",
    title: "WYNOS Food • สั่งอาหาร",
    description: "สั่งอาหารออนไลน์กับ WYNOS Food ที่ food.wynos.online",
    // Shared store links (/?store=<id>) preview in LINE/Messenger with the
    // Food icon; store details stay behind sign-in.
    images: [{ url: FOOD_ICON_512, width: 512, height: 512, alt: "WYNOS Food" }],
  },
  twitter: {
    card: "summary",
    title: "WYNOS Food • สั่งอาหาร",
    description: "สั่งอาหารออนไลน์กับ WYNOS Food ที่ food.wynos.online",
    images: [FOOD_ICON_512],
  },
  manifest: "/food/manifest.webmanifest?v=20261009-13",
  icons: {
    // All Food icons are versioned static assets to avoid mobile PWA stale-cache issues.
    icon: [
      { url: FOOD_ICON_32, sizes: "32x32", type: "image/png" },
      { url: FOOD_ICON_192, sizes: "192x192", type: "image/png" },
      { url: FOOD_ICON_512, sizes: "512x512", type: "image/png" },
    ],
    shortcut: [{ url: FOOD_ICON_32, sizes: "32x32", type: "image/png" }],
    apple: [{ url: FOOD_ICON_192, sizes: "192x192", type: "image/png" }],
    other: [
      { rel: "apple-touch-icon-precomposed", url: FOOD_ICON_192, sizes: "192x192", type: "image/png" },
    ],
  },
  robots: { index: true, follow: true },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "WYNOS Food",
    startupImage: FOOD_IOS_LAUNCH_IMAGES,
  },
  other: {
    "msapplication-TileColor": "#e32636",
    "msapplication-TileImage": FOOD_ICON_192,
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
    { media: "(prefers-color-scheme: light)", color: "#e32636" },
    { media: "(prefers-color-scheme: dark)", color: "#e32636" },
  ],
};

export default function FoodLayout({ children }: { children: ReactNode }) {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(FOOD_WEBSITE_STRUCTURED_DATA).replace(/</g, "\\u003c"),
        }}
      />
      <script dangerouslySetInnerHTML={{ __html: FOOD_SPLASH_BOOT_SCRIPT }} />
      <div className={`${anuphan.variable} fx-font`}>
        <div className="fx-splash" aria-hidden="true">
          <Image className="fx-splash-logo" src={FOOD_ICON_512} width={96} height={96} alt="" priority />
          <span className="fx-splash-name">WYNOS <b>Food</b></span>
        </div>
        {children}
      </div>
    </>
  );
}
