import type { Metadata, Viewport } from "next";
import Image from "next/image";
import { Anuphan } from "next/font/google";
import type { ReactNode } from "react";

import "./food.css";
import "./food-app.css";

import { FOOD_PRODUCTION_ORIGIN } from "@/lib/food-origin";

// Thai loopless face for the redesigned Food app; self-hosted by next/font at build time.
const anuphan = Anuphan({
  subsets: ["thai", "latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
  variable: "--font-anuphan",
});

// ZOKY-113: ZOKY icons are new versioned files; the old /icons/food/* files
// stay in place so a rollback still finds them.
const FOOD_ICON_32 = "/icons/zoky/icon-32-v1.png";
const FOOD_ICON_192 = "/icons/zoky/icon-192-v1.png";
const FOOD_ICON_512 = "/icons/zoky/icon-512-v1.png";
const FOOD_APPLE_TOUCH_ICON = "/icons/zoky/apple-touch-icon-180-v1.png";
const FOOD_SPLASH_WORDMARK = "/icons/zoky/wordmark-white-v1.png";
// Top of the ZOKY header gradient (#F93384 → #F72C7E → #EE226E).
const FOOD_BRAND_TOP = "#f93384";

// Founder decision (2026-10-11): show a brand splash (logo only) when Food opens.
// It plays once per browser session; the boot script marks <html> before the
// splash paints so later loads in the same session skip it without a flash.
// Storage is best effort: if it is blocked the splash still shows and fades.
// While the splash shows, a temporary pink theme-color (prepended, so iOS uses
// it first) keeps the status-bar strip the same pink as the splash top; it is
// removed when the splash fades so the app keeps its normal theme color.
// The splash waits for the screen underneath to report its data is ready
// (markFoodSplashReady in lib/food-splash.ts): at least 1 s, at most ~4 s.
const FOOD_SPLASH_BOOT_SCRIPT =
  "(function(){var d=document.documentElement,seen=null;try{seen=sessionStorage.getItem('wynos-food-splash')}catch(e){}if(seen){d.setAttribute('data-fx-splash','seen');return}try{sessionStorage.setItem('wynos-food-splash','1')}catch(e){}try{var m=document.createElement('meta');m.name='theme-color';m.content='#f93384';m.setAttribute('data-fx-splash-theme','');document.head.prepend(m);var t=Date.now(),r=0;window.__fxSplashReady=function(){if(r)return;r=1;setTimeout(function(){d.setAttribute('data-fx-splash-ready','');setTimeout(function(){m.remove()},350)},Math.max(0,1000-(Date.now()-t)))};setTimeout(window.__fxSplashReady,4000)}catch(e){}})()";

// iOS shows these while the installed app launches (it ignores the manifest
// background), so there is no white flash before the splash. One image per
// iPhone/iPad screen size; see public/icons/zoky/splash/. The status-bar strip
// is flat pink and the splash is centred below it, because the standalone web
// view starts under the status bar: the in-app splash then lands on the same spot.
const FOOD_IOS_LAUNCH_SIZES: Array<[number, number, number]> = [
  [440, 956, 3], [430, 932, 3], [428, 926, 3], [420, 912, 3], [414, 896, 3], [414, 896, 2],
  [414, 736, 3], [402, 874, 3], [393, 852, 3], [390, 844, 3], [375, 812, 3], [360, 780, 3], [375, 667, 2], [320, 568, 2],
  // iPad (same sizes the root layout covers, plus iPad Air 10.9).
  [1024, 1366, 2], [834, 1194, 2], [820, 1180, 2], [810, 1080, 2], [744, 1133, 2],
];
const FOOD_IOS_LAUNCH_VERSION = 1;
const FOOD_IOS_LAUNCH_IMAGES = FOOD_IOS_LAUNCH_SIZES.map(([width, height, ratio]) => ({
  // Bump the version when the images change so iOS and caches fetch the new ones.
  url: `/icons/zoky/splash/launch-${width * ratio}x${height * ratio}.png?v=${FOOD_IOS_LAUNCH_VERSION}`,
  media: `(device-width: ${width}px) and (device-height: ${height}px) and (-webkit-device-pixel-ratio: ${ratio}) and (orientation: portrait)`,
}));

const FOOD_WEBSITE_STRUCTURED_DATA = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: "ZOKY",
  alternateName: ["Zoky", "ZOKY • สั่งอาหาร", "WYNOS Food"],
  url: `${FOOD_PRODUCTION_ORIGIN}/`,
};

export const metadata: Metadata = {
  metadataBase: new URL(FOOD_PRODUCTION_ORIGIN),
  title: "ZOKY • สั่งอาหาร",
  applicationName: "ZOKY",
  description:
    "ZOKY (เดิมชื่อ WYNOS Food) บริการสั่งอาหารออนไลน์ ค้นหาร้านอาหาร เลือกเมนู และสั่งอาหารผ่าน zoky.wynos.online",
  keywords: [
    "ZOKY",
    "zoky",
    "WYNOS Food",
    "wynos food",
    "สั่งอาหาร",
    "สั่งอาหารออนไลน์",
    "food delivery",
  ],
  alternates: {
    canonical: `${FOOD_PRODUCTION_ORIGIN}/`,
  },
  openGraph: {
    type: "website",
    url: `${FOOD_PRODUCTION_ORIGIN}/`,
    siteName: "ZOKY",
    title: "ZOKY • สั่งอาหาร",
    description: "สั่งอาหารออนไลน์กับ ZOKY ที่ zoky.wynos.online",
    // Shared store links (/?store=<id>) preview in LINE/Messenger with the
    // ZOKY icon; store details stay behind sign-in.
    images: [{ url: FOOD_ICON_512, width: 512, height: 512, alt: "ZOKY" }],
  },
  twitter: {
    card: "summary",
    title: "ZOKY • สั่งอาหาร",
    description: "สั่งอาหารออนไลน์กับ ZOKY ที่ zoky.wynos.online",
    images: [FOOD_ICON_512],
  },
  manifest: "/food/manifest.webmanifest?v=20261018-zoky1",
  icons: {
    // All Food icons are versioned static assets to avoid mobile PWA stale-cache issues.
    icon: [
      { url: FOOD_ICON_32, sizes: "32x32", type: "image/png" },
      { url: FOOD_ICON_192, sizes: "192x192", type: "image/png" },
      { url: FOOD_ICON_512, sizes: "512x512", type: "image/png" },
    ],
    shortcut: [{ url: FOOD_ICON_32, sizes: "32x32", type: "image/png" }],
    apple: [{ url: FOOD_APPLE_TOUCH_ICON, sizes: "180x180", type: "image/png" }],
    other: [
      { rel: "apple-touch-icon-precomposed", url: FOOD_APPLE_TOUCH_ICON, sizes: "180x180", type: "image/png" },
    ],
  },
  robots: { index: true, follow: true },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "ZOKY",
    startupImage: FOOD_IOS_LAUNCH_IMAGES,
  },
  other: {
    "msapplication-TileColor": FOOD_BRAND_TOP,
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
    { media: "(prefers-color-scheme: light)", color: FOOD_BRAND_TOP },
    { media: "(prefers-color-scheme: dark)", color: FOOD_BRAND_TOP },
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
          <Image className="fx-splash-wordmark" src={FOOD_SPLASH_WORDMARK} width={200} height={110} alt="" priority />
        </div>
        {children}
      </div>
    </>
  );
}
