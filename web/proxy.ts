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
  if (request.nextUrl.pathname !== "/") return NextResponse.next();

  const host = request.headers.get("host")?.split(":")[0].toLowerCase() ?? "";
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
  matcher: ["/"],
};
