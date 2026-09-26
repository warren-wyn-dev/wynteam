import { createBrowserClient } from "@supabase/ssr";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { getActiveAccountStorageKey } from "@/lib/account-registry";
import { getPendingAddAccountSlot } from "@/lib/pending-account-add";

let client: SupabaseClient | null | undefined;
let pendingClient: SupabaseClient | null = null;
let pendingClientSlot: string | null = null;

export function hasSupabaseBrowserConfig(): boolean {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}

export function getSupabaseBrowserClient(): SupabaseClient | null {
  // Signup and email confirmation launched by Add Account must never mutate
  // the signed-in account's Supabase singleton or activate the new slot early.
  if (typeof window !== "undefined") {
    const pathname = window.location.pathname;
    const pending = getPendingAddAccountSlot();
    const signupRoute = pathname.startsWith("/signup/") || pathname === "/onboarding/profile";
    // During the Add Account Google return, only the isolated route client
    // should exchange the OAuth code; the app singleton must never consume
    // that code into A's active session before the route mounts.
    const addAccountOAuth = pathname === "/account/add"
      && new URLSearchParams(window.location.search).get("oauth") === "1";
    const callbackSlot = pathname === "/auth/callback"
      ? new URLSearchParams(window.location.search).get("slot")
      : null;
    if (pending && (signupRoute || callbackSlot === pending
      || (addAccountOAuth && new URLSearchParams(window.location.search).get("slot") === pending))) {
      const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
      const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
      if (!url || !key) return null;
      if (!pendingClient || pendingClientSlot !== pending) {
        pendingClient = createClient(url, key, {
          auth: {
            storageKey: pending,
            persistSession: true,
            autoRefreshToken: true,
            // /auth/callback exchanges its one-time code explicitly.
            detectSessionInUrl: false,
          },
        });
        pendingClientSlot = pending;
      }
      return pendingClient;
    }
  }
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

/**
 * Read/detach the PREVIOUS account during Add Account without allowing the
 * default Supabase singleton to consume B's in-flight Google OAuth callback.
 * Reuse the isolated, no-URL-detection browser client configuration.
 */
export function createAccountSwitchPriorClient(): SupabaseClient | null {
  return createPasswordRecoveryClient();
}
