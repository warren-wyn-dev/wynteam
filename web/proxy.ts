import { type NextRequest, NextResponse } from "next/server";

import { FOOD_LEGACY_HOST, FOOD_PRODUCTION_HOST, FOOD_PRODUCTION_ORIGIN } from "@/lib/food-origin";

const ROOT_DESTINATION_BY_HOST: Record<string, string> = {
  [FOOD_PRODUCTION_HOST]: "/food",
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

function redirectToFood(pathname: string, search: string) {
  const target = new URL(FOOD_PRODUCTION_ORIGIN);
  target.pathname = pathname;
  target.search = search;
  return NextResponse.redirect(target, FOOD_MOVE_STATUS);
}

export function proxy(request: NextRequest) {
  const host = request.headers.get("host")?.split(":")[0].toLowerCase() ?? "";
  const { pathname, search } = request.nextUrl;

  // Every bookmark, shared link, QR poster and auth/Stripe return on the old
  // Food host keeps working: same path and query on ZOKY.
  if (host === FOOD_LEGACY_HOST) return redirectToFood(pathname, search);

  // Food is a dedicated product origin. Keeping /food on wynos.online would
  // make the Food PWA's root scope claim the Social origin too, and shared
  // deep links could escape standalone mode. Send Social-origin Food routes
  // to the dedicated Food origin before any route rendering.
  if ((host === "wynos.online" || host === "www.wynos.online") &&
      (pathname === "/food" || pathname.startsWith("/food/"))) {
    return redirectToFood(pathname === "/food" ? "/" : pathname, search);
  }

  // On the Food origin, the shared WYNOS auth URLs open Food's own auth pages
  // so a typed or bookmarked zoky.wynos.online/login never lands on Social.
  if (host === FOOD_PRODUCTION_HOST) {
    const foodAuth = pathname === "/login" ? "/food/login"
      : pathname === "/signup" || pathname.startsWith("/signup/") ? "/food/signup"
      : null;
    if (foodAuth) {
      const target = request.nextUrl.clone();
      target.pathname = foodAuth;
      return NextResponse.redirect(target, 307);
    }
  }

  if (pathname !== "/") return NextResponse.next();

  const redirectTo = ROOT_REDIRECT_BY_HOST[host];
  if (redirectTo) {
    const target = new URL(redirectTo);
    target.search = search;
    return NextResponse.redirect(target, 307);
  }

  const destination = ROOT_DESTINATION_BY_HOST[host];
  if (!destination) return NextResponse.next();

  const url = request.nextUrl.clone();
  url.pathname = destination;
  return NextResponse.rewrite(url);
}

export const config = {
  matcher: [
    "/", "/food", "/food/:path*", "/login", "/signup", "/signup/:path*",
    // Every page on the old Food host (build assets and API calls from tabs
    // that are already open stay where they are).
    { source: "/((?!_next/|api/).*)", has: [{ type: "host", value: "food.wynos.online" }] },
  ],
};
