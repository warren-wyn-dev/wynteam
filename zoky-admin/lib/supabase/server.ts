import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

/**
 * Server-side Supabase client (Server Components/Route Handlers/Server
 * Actions) -- reads the session from cookies, still scoped to the
 * signed-in user's own RLS policies (anon key + user JWT, not the
 * service-role key). This is the client every role check in this app
 * must go through -- see the Design spec's "role check ต้องเกิดที่
 * layout level (server-side)" requirement, .wyn/docs/design/
 * wyn-049-admin-foundation.md.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            for (const { name, value, options } of cookiesToSet) {
              cookieStore.set(name, value, options);
            }
          } catch {
            // Called from a Server Component that can't set cookies
            // directly (e.g. a page render, not a Server Action/Route
            // Handler) -- middleware.ts refreshes the session on every
            // request instead, so this is safe to ignore. Mirrors the
            // official @supabase/ssr Next.js App Router pattern.
          }
        },
      },
    },
  );
}
