import { type NextRequest, NextResponse } from "next/server";

import { FOOD_LEGACY_HOST, FOOD_PRODUCTION_HOST, FOOD_PRODUCTION_ORIGIN } from "@/lib/food-origin";

const ROOT_DESTINATION_BY_HOST: Record<string, string> = {
  [FOOD_PRODUCTION_HOST]: "/food",
  [FOOD_LEGACY_HOST]: "/food",
  "merchant.wynos.online": "/merchant",
};

// WYNOS Maps is for signed-in WYNOS use, and the session lives on
// wynos.online, so the Maps subdomain sends visitors there. Temporary
// (307) so the subdomain can be given its own page again later.
const ROOT_REDIRECT_BY_HOST: Record<string, string> = {
  "maps.wynos.online": "https://wynos.online/maps",
};

// ZOKY-114: WYNOS Food moved to ZOKY (zoky.wynos.online). Temporary (307)
// until the cutover is verified; then the Founder decides on 308 (ZOKY-100 Q2).
const FOOD_MOVE_STATUS = 307;
const FOOD_LEGACY_SW_CLEANUP_PATH = "/food/legacy-sw-cleanup.js";

// ZOKY-114 two-phase cutover (CTO M1, Founder decision 2026-10-18). Server-only
// flag, read per request: proxy runs in the Node.js runtime (Next.js 16) and
// non-NEXT_PUBLIC_ variables are not inlined at build time. On Vercel a changed
// value only applies to a new deployment, so turning it on or off = redeploy.
// Phase 1 (unset/anything else): food.wynos.online keeps serving Food as before.
// Phase 2 ("1" or "true"): food.wynos.online moves to ZOKY + cleanup worker.
function legacyFoodRedirectEnabled() {
  const value = process.env.ZOKY_LEGACY_FOOD_REDIRECT;
  return value === "1" || value === "true";
}

function redirectToFood(pathname: string, search: string) {
  const target = new URL(FOOD_PRODUCTION_ORIGIN);
  target.pathname = pathname;
  target.search = search;
  return NextResponse.redirect(target, FOOD_MOVE_STATUS);
}

export function proxy(request: NextRequest) {
  const host = request.headers.get("host")?.split(":")[0].toLowerCase() ?? "";
  const { pathname, search } = request.nextUrl;

  if (host === FOOD_LEGACY_HOST && legacyFoodRedirectEnabled()) {
    // ZOKY-136: browsers reject a redirected service-worker update, so the old
    // worker (and its push subscription) would live on. Serve a cleanup worker
    // that unsubscribes push and unregisters itself instead.
    if (pathname === "/sw.js") {
      const cleanup = request.nextUrl.clone();
      cleanup.pathname = FOOD_LEGACY_SW_CLEANUP_PATH;
      cleanup.search = "";
      return NextResponse.rewrite(cleanup);
    }
    // Every bookmark, shared link, QR poster and auth/Stripe return on the old
    // Food host keeps working: same path and query on ZOKY.
    return redirectToFood(pathname, search);
  }

  // Food is a dedicated product origin. Keeping /food on wynos.online would
  // make the Food PWA's root scope claim the Social origin too, and shared
  // deep links could escape standalone mode. Send Social-origin Food routes
  // to the dedicated Food origin before any route rendering.
  if ((host === "wynos.online" || host === "www.wynos.online") &&
      (pathname === "/food" || pathname.startsWith("/food/"))) {
    return redirectToFood(pathname === "/food" ? "/" : pathname, search);
  }

  // On the Food origin, the shared WYNOS auth URLs open Food's own auth pages
  // so a typed or bookmarked zoky.wynos.online/login never lands on Social
  // (food.wynos.online too while it still serves Food in phase 1).
  if (host === FOOD_PRODUCTION_HOST || host === FOOD_LEGACY_HOST) {
    const foodAuth = pathname === "/login" ? "/food/login"
      : pathname === "/signup" || pathname.startsWith("/signup/") ? "/food/signup"
      : null;
    if (foodAuth) {
      const target = request.nextUrl.clone();
      target.pathname = foodAuth;
      return NextResponse.redirect(target, 307);
    }
  }

  // Existing login returns and installed Merchant apps still enter /merchant.
  // Keep a deliberate legacy escape hatch and the payment callback handler.
  if (host === "merchant.wynos.online" && pathname === "/merchant"
      && process.env.ZOKY_MERCHANT_FLUTTER_ENABLED === "1"
      && request.nextUrl.searchParams.get("legacy") !== "1"
      && !["return", "refresh"].includes(request.nextUrl.searchParams.get("payments") ?? "")) {
    const target = request.nextUrl.clone();
    target.pathname = "/merchant/flutter";
    return NextResponse.redirect(target, 307);
  }

  if (pathname !== "/") return NextResponse.next();

  const redirectTo = ROOT_REDIRECT_BY_HOST[host];
  if (redirectTo) {
    const target = new URL(redirectTo);
    target.search = search;
    return NextResponse.redirect(target, 307);
  }

  // This only switches the Merchant origin. Auth and legacy /merchant/*
  // remain in the existing Next.js app, and Food/Social are unaffected.
  // Existing Stripe Connect return/refresh handling belongs to MerchantPaymentSetup.
  const stripeCallback = ["return", "refresh"].includes(request.nextUrl.searchParams.get("payments") ?? "");
  const destination = host === "merchant.wynos.online" && !stripeCallback && process.env.ZOKY_MERCHANT_FLUTTER_ENABLED === "1"
    ? "/merchant/flutter"
    : ROOT_DESTINATION_BY_HOST[host];
  if (!destination) return NextResponse.next();

  const url = request.nextUrl.clone();
  url.pathname = destination;
  return NextResponse.rewrite(url);
}

export const config = {
  matcher: [
    "/", "/merchant", "/food", "/food/:path*", "/login", "/signup", "/signup/:path*",
    // Every page on the old Food host for the phase 2 redirect (build assets
    // and API calls from tabs that are already open stay where they are).
    // The matcher is fixed at build time; in phase 1 these return next().
    { source: "/((?!_next/|api/).*)", has: [{ type: "host", value: "food.wynos.online" }] },
  ],
};
