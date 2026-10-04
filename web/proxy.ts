import { type NextRequest, NextResponse } from "next/server";

const ROOT_DESTINATION_BY_HOST: Record<string, string> = {
  "food.wynos.online": "/food",
  "merchant.wynos.online": "/merchant",
  "maps.wynos.online": "/maps",
};

export function proxy(request: NextRequest) {
  if (request.nextUrl.pathname !== "/") return NextResponse.next();

  const host = request.headers.get("host")?.split(":")[0].toLowerCase() ?? "";
  const destination = ROOT_DESTINATION_BY_HOST[host];
  if (!destination) return NextResponse.next();

  const url = request.nextUrl.clone();
  url.pathname = destination;
  return NextResponse.rewrite(url);
}

export const config = {
  matcher: ["/"],
};
