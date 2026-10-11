import { type NextRequest, NextResponse } from "next/server";

const ROOT_DESTINATION_BY_HOST: Record<string, string> = {
  "food.wynos.online": "/food",
  "merchant.wynos.online": "/merchant",
};

// WYNOS Maps is for signed-in WYNOS use, and the session lives on
// wynos.online, so the Maps subdomain sends visitors there. Temporary
// (307) so the subdomain can be given its own page again later.
const ROOT_REDIRECT_BY_HOST: Record<string, string> = {
  "maps.wynos.online": "https://wynos.online/maps",
};

export function proxy(request: NextRequest) {
  const host = request.headers.get("host")?.split(":")[0].toLowerCase() ?? "";

  // Food is a dedicated product origin. Keeping /food on wynos.online would
  // make the Food PWA's root scope claim the Social origin too, and shared
  // deep links could escape standalone mode. Send Social-origin Food routes
  // to the dedicated Food origin before any route rendering.
  if ((host === "wynos.online" || host === "www.wynos.online") &&
      (request.nextUrl.pathname === "/food" || request.nextUrl.pathname.startsWith("/food/"))) {
    const target = new URL("https://food.wynos.online");
    target.pathname = request.nextUrl.pathname === "/food" ? "/" : request.nextUrl.pathname;
    target.search = request.nextUrl.search;
    return NextResponse.redirect(target, 307);
  }

  // On the Food origin, the shared WYNOS auth URLs open Food's own auth pages
  // so a typed or bookmarked food.wynos.online/login never lands on Social.
  if (host === "food.wynos.online") {
    const path = request.nextUrl.pathname;
    const foodAuth = path === "/login" ? "/food/login"
      : path === "/signup" || path.startsWith("/signup/") ? "/food/signup"
      : null;
    if (foodAuth) {
      const target = request.nextUrl.clone();
      target.pathname = foodAuth;
      return NextResponse.redirect(target, 307);
    }
  }

  if (request.nextUrl.pathname !== "/") return NextResponse.next();

  const redirectTo = ROOT_REDIRECT_BY_HOST[host];
  if (redirectTo) {
    const target = new URL(redirectTo);
    target.search = request.nextUrl.search;
    return NextResponse.redirect(target, 307);
  }

  const destination = ROOT_DESTINATION_BY_HOST[host];
  if (!destination) return NextResponse.next();

  const url = request.nextUrl.clone();
  url.pathname = destination;
  return NextResponse.rewrite(url);
}

export const config = {
  matcher: ["/", "/food", "/food/:path*", "/login", "/signup", "/signup/:path*"],
};
