import type { Session, SupabaseClient } from "@supabase/supabase-js";
import { PERSIST_QUERY_CACHE_KEY } from "@/lib/query-persist-key";

export const MAX_SAVED_ACCOUNTS = 9;

const REGISTRY_KEY = "wynos.saved-accounts.v1";
const ACTIVE_STORAGE_KEY = "wynos.active-account-storage.v1";
const SLOT_PREFIX = "wynos.account.";

export type SavedAccount = {
  userId: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
  email: string | null;
  storageKey: string | null;
  lastUsedAt: number;
};

function available(): boolean {
  return typeof window !== "undefined" && typeof window.localStorage !== "undefined";
}

function readRegistry(): SavedAccount[] {
  if (!available()) return [];
  try {
    const raw = window.localStorage.getItem(REGISTRY_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as SavedAccount[];
    return Array.isArray(parsed) ? parsed.filter((item) => Boolean(item?.userId)) : [];
  } catch {
    return [];
  }
}

function writeRegistry(accounts: SavedAccount[]): void {
  if (!available()) return;
  window.localStorage.setItem(REGISTRY_KEY, JSON.stringify(accounts.slice(0, MAX_SAVED_ACCOUNTS)));
}

export function getActiveAccountStorageKey(): string | null {
  if (!available()) return null;
  return window.localStorage.getItem(ACTIVE_STORAGE_KEY);
}

export function createAccountStorageKey(): string {
  const suffix = typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  return `${SLOT_PREFIX}${suffix}`;
}

export function listSavedAccounts(): SavedAccount[] {
  return readRegistry().sort((a, b) => b.lastUsedAt - a.lastUsedAt);
}

export async function registerSessionAccount(
  client: SupabaseClient,
  session: Session,
  storageKey: string | null = getActiveAccountStorageKey(),
): Promise<boolean> {
  if (!available()) return false;
  const accounts = readRegistry();
  const existing = accounts.find((item) => item.userId === session.user.id);
  if (!existing && accounts.length >= MAX_SAVED_ACCOUNTS) return false;

  const profileResult = await client
    .from("profiles")
    .select("username,display_name,avatar_url")
    .eq("id", session.user.id)
    .maybeSingle();
  const profile = profileResult.error ? null : profileResult.data;
  const next: SavedAccount = {
    userId: session.user.id,
    username: String(profile?.username ?? session.user.user_metadata?.username ?? session.user.email?.split("@")[0] ?? "WYNOS"),
    displayName: profile?.display_name == null ? (session.user.user_metadata?.full_name ?? null) : String(profile.display_name),
    avatarUrl: profile?.avatar_url == null ? (session.user.user_metadata?.avatar_url ?? null) : String(profile.avatar_url),
    email: session.user.email ?? null,
    storageKey,
    lastUsedAt: Date.now(),
  };
  writeRegistry([next, ...accounts.filter((item) => item.userId !== next.userId)]);
  return true;
}

export async function registerCurrentAccount(client: SupabaseClient): Promise<boolean> {
  const result = await client.auth.getSession();
  if (!result.data.session) return false;
  return registerSessionAccount(client, result.data.session);
}

export function activateSavedAccount(userId: string): boolean {
  if (!available()) return false;
  const accounts = readRegistry();
  const target = accounts.find((item) => item.userId === userId);
  if (!target) return false;
  // Do not carry account A\u0027s persisted Feed/Profile/Chat cache into account B.\n  window.localStorage.removeItem(PERSIST_QUERY_CACHE_KEY);\n  writeRegistry([{ ...target, lastUsedAt: Date.now() }, ...accounts.filter((item) => item.userId !== userId)]);
  if (target.storageKey) window.localStorage.setItem(ACTIVE_STORAGE_KEY, target.storageKey);
  else window.localStorage.removeItem(ACTIVE_STORAGE_KEY);
  return true;
}

export function removeSavedAccount(userId: string): void {
  if (!available()) return;
  const accounts = readRegistry();
  const target = accounts.find((item) => item.userId === userId);
  if (!target) return;
  writeRegistry(accounts.filter((item) => item.userId !== userId));
  if (target.storageKey) {
    window.localStorage.removeItem(target.storageKey);
    window.localStorage.removeItem(`${target.storageKey}-code-verifier`);
    if (window.localStorage.getItem(ACTIVE_STORAGE_KEY) === target.storageKey) {
      window.localStorage.removeItem(ACTIVE_STORAGE_KEY);
    }
  }
}

export function markAccountStorageActive(storageKey: string): void {
  if (!available()) return;
  if (getActiveAccountStorageKey() !== storageKey) {
    window.localStorage.removeItem(PERSIST_QUERY_CACHE_KEY);
  }
  window.localStorage.setItem(ACTIVE_STORAGE_KEY, storageKey);
}
