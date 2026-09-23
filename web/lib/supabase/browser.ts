import { createBrowserClient } from "@supabase/ssr";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { getActiveAccountStorageKey } from "@/lib/account-registry";

let client: SupabaseClient | null | undefined;

export function hasSupabaseBrowserConfig(): boolean {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}

export function getSupabaseBrowserClient(): SupabaseClient | null {
  if (client !== undefined) return client;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !publishableKey) {
    client = null;
    return client;
  }

  const accountStorageKey = getActiveAccountStorageKey();
  client = accountStorageKey
    ? createClient(url, publishableKey, {
        auth: {
          storageKey: accountStorageKey,
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: true,
        },
      })
    : createBrowserClient(url, publishableKey);
  return client;
}

/**
 * A separate recovery client prevents an existing signed-in account (or the
 * SDK's implicit URL detection) from being mistaken for proof of recovery.
 * It shares the normal PKCE/cookie storage, but only an explicit successful
 * exchange of the one-time link unlocks the new-password form.
 */
export function createPasswordRecoveryClient(): SupabaseClient | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return null;
  const accountStorageKey = getActiveAccountStorageKey();
  return accountStorageKey
    ? createClient(url, key, {
        auth: {
          storageKey: accountStorageKey,
          persistSession: true,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      })
    : createBrowserClient(url, key, {
        isSingleton: false,
        auth: { detectSessionInUrl: false, autoRefreshToken: false },
      });
}
