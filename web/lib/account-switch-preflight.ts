import type { SavedAccount } from "@/lib/account-registry";
import {
  checkSavedAccountSession,
  type AccountSessionCheck,
} from "@/lib/account-switch-session";

// Short-lived, in-memory ONLY. Every successful warm-up calls Supabase Auth's
// real getUser() first; the saved registry or an unverified local JWT alone
// can never mark a different account ready.
export const SWITCH_PREFLIGHT_TTL_MS = 12_000;

type Verified = { fingerprint: string; verifiedAt: number };
const verified = new Map<string, Verified>();
const inFlight = new Map<string, Promise<AccountSessionCheck>>();

function identity(account: SavedAccount): string {
  return `${account.userId}:${account.storageKey ?? "default-cookie"}`;
}

/**
 * A version marker, NOT an auth credential. Hashing the stored session /
 * browser cookie means a refresh, logout, or sign-in from another tab
 * invalidates any earlier getUser() result without duplicating tokens.
 * No fingerprint -> fall back to a fresh server check at selection time.
 */
function authFingerprint(account: SavedAccount): string | null {
  if (typeof window === "undefined") return null;
  try {
    let raw: string | null;
    if (account.storageKey) {
      raw = window.localStorage.getItem(account.storageKey);
      if (!raw) return null;
      const session = JSON.parse(raw) as { user?: { id?: string } };
      if (session.user?.id !== account.userId) return null;
    } else {
      raw = typeof document === "undefined" ? null : document.cookie;
      if (!raw) return null;
    }

    let hash = 2166136261;
    for (let i = 0; i < raw.length; i += 1) {
      hash = Math.imul(hash ^ raw.charCodeAt(i), 16777619);
    }
    return `${raw.length}:${hash >>> 0}`;
  } catch {
    return null;
  }
}

function stillVerified(account: SavedAccount): boolean {
  if (typeof navigator !== "undefined" && navigator.onLine === false) return false;
  const entry = verified.get(identity(account));
  const fingerprint = authFingerprint(account);
  if (!entry || !fingerprint ||
      entry.fingerprint !== fingerprint ||
      Date.now() - entry.verifiedAt > SWITCH_PREFLIGHT_TTL_MS) {
    verified.delete(identity(account));
    return false;
  }
  return true;
}

/**
 * Start the read-only Auth verification before the user taps an account.
 * Duplicate taps and an idle warm-up share the same in-flight request.
 * A token/cookie change DURING verification is never cached.
 */
export function prewarmSavedAccountSession(account: SavedAccount): Promise<AccountSessionCheck> {
  if (stillVerified(account)) return Promise.resolve({ ok: true });
  const key = identity(account);
  const pending = inFlight.get(key);
  if (pending) return pending;

  const before = authFingerprint(account);
  if (!before) return Promise.resolve({ ok: false, reason: "unavailable" });

  const request = checkSavedAccountSession(account)
    .then((result) => {
      if (result.ok && before === authFingerprint(account) &&
          (typeof navigator === "undefined" || navigator.onLine !== false)) {
        verified.set(key, { fingerprint: before, verifiedAt: Date.now() });
      } else {
        verified.delete(key);
      }
      return result;
    })
    .catch((): AccountSessionCheck => {
      verified.delete(key);
      return { ok: false, reason: "network" };
    })
    .finally(() => {
      if (inFlight.get(key) === request) inFlight.delete(key);
    });
  inFlight.set(key, request);
  return request;
}

/**
 * A recent server-verified, unchanged session is ready on tap. Otherwise
 * perform the original remote check: never activate an unverified slot.
 */
export async function getPreparedSavedAccountSession(account: SavedAccount): Promise<AccountSessionCheck> {
  if (stillVerified(account)) return { ok: true };
  if (!authFingerprint(account)) return checkSavedAccountSession(account);
  const result = await prewarmSavedAccountSession(account);
  if (!result.ok) return result;
  return stillVerified(account) ? result : checkSavedAccountSession(account);
}
