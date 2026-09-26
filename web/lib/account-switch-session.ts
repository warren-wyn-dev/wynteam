import { createBrowserClient } from "@supabase/ssr";
import { createClient } from "@supabase/supabase-js";

import type { SavedAccount } from "@/lib/account-registry";

export type AccountSessionCheck =
  | { ok: true }
  | { ok: false; reason: "missing" | "mismatch" | "expired" | "network" | "unavailable" };

/**
 * Check a saved account before changing the active browser storage slot.
 * The temporary client never starts background token refresh or consumes an
 * OAuth callback. getUser() checks the actual Auth server; a registry entry
 * alone is not proof that its refresh token is usable or belongs to this user.
 */
export async function checkSavedAccountSession(account: SavedAccount): Promise<AccountSessionCheck> {
  if (typeof window === "undefined") return { ok: false, reason: "unavailable" };
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return { ok: false, reason: "unavailable" };

  // Custom account slots live in localStorage; the original default account
  // instead uses the existing @supabase/ssr cookie store.
  if (account.storageKey) {
    try {
      const raw = window.localStorage.getItem(account.storageKey);
      if (!raw) return { ok: false, reason: "missing" };
      const session = JSON.parse(raw) as {
        access_token?: unknown;
        refresh_token?: unknown;
        user?: { id?: unknown };
      };
      if (typeof session.access_token !== "string" || typeof session.refresh_token !== "string") {
        return { ok: false, reason: "missing" };
      }
      if (session.user?.id && session.user.id !== account.userId) {
        return { ok: false, reason: "mismatch" };
      }
    } catch {
      return { ok: false, reason: "missing" };
    }
  }

  if (typeof navigator !== "undefined" && navigator.onLine === false) {
    return { ok: false, reason: "network" };
  }

  try {
    const client = account.storageKey
      ? createClient(url, key, {
          auth: {
            storageKey: account.storageKey,
            persistSession: true,
            autoRefreshToken: false,
            detectSessionInUrl: false,
          },
        })
      : createBrowserClient(url, key, {
          isSingleton: false,
          auth: { autoRefreshToken: false, detectSessionInUrl: false },
        });
    const { data, error } = await client.auth.getUser();
    if (error) {
      const code = error.code ?? "";
      const invalidToken = [
        "session_not_found",
        "refresh_token_already_used",
        "refresh_token_not_found",
        "invalid_refresh_token",
        "invalid_token",
        "bad_jwt",
        "user_not_found",
      ].includes(code);
      return { ok: false, reason: invalidToken ? "expired" : "network" };
    }
    if (!data.user) return { ok: false, reason: "missing" };
    if (data.user.id !== account.userId) return { ok: false, reason: "mismatch" };
    return { ok: true };
  } catch {
    return { ok: false, reason: "network" };
  }
}
