import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

const PUBLIC_PATHS = ["/login"];

/**
 * Refreshes the Supabase session cookie on every request (the official
 * @supabase/ssr pattern for Next.js middleware) and redirects
 * unauthenticated requests to /login before they ever reach a Server
 * Component -- the Design spec's "ไม่ sign-in เลย (guest) พยายามเข้า URL
 * ของหน้า Admin ตรงๆ → ถูก redirect ไปหน้า sign-in เสมอ" acceptance
 * criterion. Does NOT check platform_role here (that needs a
 * `profiles` query, which belongs in the admin layout per the Design
 * spec's "role check ต้องเกิดที่ layout level" -- middleware only
 * proves "is there a session at all", not "does this session have
 * permission").
 */
export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          for (const { name, value } of cookiesToSet) {
            request.cookies.set(name, value);
          }
          supabaseResponse = NextResponse.next({ request });
          for (const { name, value, options } of cookiesToSet) {
            supabaseResponse.cookies.set(name, value, options);
          }
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isPublicPath = PUBLIC_PATHS.includes(request.nextUrl.pathname);

  if (!user && !isPublicPath) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.search = "";
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}
