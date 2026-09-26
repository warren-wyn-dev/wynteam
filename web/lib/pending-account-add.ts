/** A temporary, unactivated Supabase slot for creating/confirming another account.
 * Only metadata lives here — never access tokens or passwords. localStorage is
 * intentional: email confirmation may open in a new tab on the same device.
 */
const KEY = "wynos.pending-add-account.v1";
const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const SLOT_PATTERN = /^wynos\.account\.[a-zA-Z0-9-]{8,90}$/;

export function validAddAccountSlot(value: string | null): value is string {
  return typeof value === "string" && SLOT_PATTERN.test(value);
}

export function getPendingAddAccountSlot(): string | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return null;
    const item = JSON.parse(raw) as { slot?: unknown; startedAt?: unknown };
    const slot = typeof item.slot === "string" ? item.slot : null;
    if (!validAddAccountSlot(slot)
        || typeof item.startedAt !== "number"
        || item.startedAt > Date.now()
        || Date.now() - item.startedAt > MAX_AGE_MS) {
      window.localStorage.removeItem(KEY);
      return null;
    }
    return slot;
  } catch {
    return null;
  }
}

export function beginPendingAddAccount(slot: string): void {
  if (typeof window === "undefined" || !validAddAccountSlot(slot)) return;
  window.localStorage.setItem(KEY, JSON.stringify({ slot, startedAt: Date.now() }));
}

export function clearPendingAddAccount(slot?: string): void {
  if (typeof window === "undefined") return;
  if (!slot || getPendingAddAccountSlot() === slot) window.localStorage.removeItem(KEY);
}
