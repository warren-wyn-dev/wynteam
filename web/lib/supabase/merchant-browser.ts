import { createClient, type SupabaseClient } from "@supabase/supabase-js";

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

  merchantClient = createClient(url, key, {
    auth: {
      storageKey: MERCHANT_AUTH_STORAGE_KEY,
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });
  return merchantClient;
}
