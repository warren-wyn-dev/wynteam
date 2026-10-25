import { createBrowserClient } from "@supabase/ssr";

/**
 * Browser-side Supabase client -- uses the public anon/publishable key
 * only (safe to embed, protected by RLS, same as the Flutter app's own
 * SUPABASE_PUBLISHABLE_KEY convention, see app/lib/core/env.dart). No
 * service-role client exists anywhere in this app yet -- WYN-049's
 * scope (auth + layout only) needs none, since `profiles`' own SELECT
 * policy already lets any authenticated user read their own
 * platform_role (see supabase/schema.sql). A server-only service-role
 * client is deliberately deferred to whichever later task (WYN-051+)
 * first needs to bypass RLS for cross-user data, per this task's
 * Product spec Risks section on handling that key carefully.
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  );
}
