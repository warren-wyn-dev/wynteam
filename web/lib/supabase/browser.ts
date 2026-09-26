import { createBrowserClient } from "@supabase/ssr";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { getActiveAccountStorageKey } from "@/lib/account-registry";
import { getAddAccountIntentSlot, getPendingAddAccountSlot } from "@/lib/pending-account-add";

let client: SupabaseClient | null | undefined;
let pendingClient: SupabaseClient | null = null;
let pendingClientSlot: string | null = null;

export function hasSupabaseBrowserConfig(): boolean {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}

/**
 * Add Account maintains its own Supabase session while A remains active.
 * Explicitly selecting this client on signup screens avoids a soft-navigation
 * race: window.location.pathname can still reflect the preceding page while
 * React mounts the next route.
 */
export function getPendingAddAccountClient(expectedSlot?: string | null): SupabaseClient | null {
  const pending = getPendingAddAccountSlot();
  if (!pending || (expectedSlot && pending !== expectedSlot)) return null;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return null;
  if (!pendingClient || pendingClientSlot !== pending) {
    pendingClient = createClient(url, key, {
      auth: {
        storageKey: pending,
        persistSession: true,
        autoRefreshToken: true,
        // /auth/callback explicitly exchanges the PKCE code once.
        detectSessionInUrl: false,
      },
    });
    pendingClientSlot = pending;
  }
  return pendingClient;
}

export function getSignupAuthClient(): SupabaseClient | null {
  const ownPendingSlot = getAddAccountIntentSlot();
  if (ownPendingSlot) {
    // If this tab's provisional slot expired or another tab started its own
    // registration, NEVER read that second tab's session or write into A.
    return getPendingAddAccountClient(ownPendingSlot);
  }
  // A completely separate normal signup tab must ignore another tab's
  // pending Add Account slot even though localStorage is origin-wide.
  return getSupabaseBrowserClient();
}

export function getSupabaseBrowserClient(): SupabaseClient | null {
  // The root app mounts persistent listeners before the page is hydrated.
  // During these two isolated OAuth redirects, they must not consume B's
  // one-time PKCE code in the *active* account A's browser singleton.
  if (typeof window !== "undefined") {
    const pathname = window.location.pathname;
    const params = new URLSearchParams(window.location.search);
    const pending = getPendingAddAccountSlot();
    const pendingRedirect = (pathname === "/account/add" && params.get("oauth") === "1"
        || pathname === "/auth/callback") && params.get("slot") === pending;
    if (pending && pendingRedirect) return getPendingAddAccountClient(pending);
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
