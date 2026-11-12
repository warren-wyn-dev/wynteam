import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { createClockSkewRetryFetch, createSharedTokenRefresher } from "@/lib/supabase/clock-skew-fetch";

export const MERCHANT_AUTH_STORAGE_KEY = "wynos-merchant-auth-v1";

let merchantClient: SupabaseClient | null | undefined;

export function hasMerchantBrowserConfig() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}

export function getMerchantSupabaseBrowserClient(): SupabaseClient | null {
  if (merchantClient !== undefined) return merchantClient;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) {
    merchantClient = null;
    return merchantClient;
  }

  // The fetch is built before the client, so the refresher binds it lazily.
  let created: SupabaseClient | null = null;
  const refresh = createSharedTokenRefresher(async () => {
    const { data, error } = await created!.auth.refreshSession();
    return error ? null : data.session?.access_token ?? null;
  });
  merchantClient = createClient(url, key, {
    auth: {
      storageKey: MERCHANT_AUTH_STORAGE_KEY,
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      flowType: "pkce",
    },
    global: { fetch: createClockSkewRetryFetch(undefined, refresh) },
  });
  created = merchantClient;
  return merchantClient;
}
