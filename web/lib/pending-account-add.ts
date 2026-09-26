/** Temporary metadata for a second account. Never persist passwords here.
 * The localStorage slot lets an email callback opened in a new tab recover the
 * PKCE verifier, while sessionStorage binds an active signup to its own tab.
 * A concurrent signup in another tab must never inherit this account.
 */
const KEY = "wynos.pending-add-account.v1";
const INTENT_KEY = "wynos.add-account-intent.v1";
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

export function getAddAccountIntentSlot(): string | null {
  if (typeof window === "undefined") return null;
  try {
    const slot = window.sessionStorage.getItem(INTENT_KEY);
    return validAddAccountSlot(slot) ? slot : null;
  } catch {
    return null;
  }
}

/** Distinguish normal signup from an unfinished/expired Add Account attempt. */
export function hasAddAccountIntent(): boolean {
  return getAddAccountIntentSlot() !== null;
}

/** Return the provisional slot only to the tab that started this signup. */
export function getPendingAddAccountSlotForTab(): string | null {
  const intent = getAddAccountIntentSlot();
  return intent && getPendingAddAccountSlot() === intent ? intent : null;
}

export function beginPendingAddAccount(slot: string): boolean {
  if (typeof window === "undefined" || !validAddAccountSlot(slot)) return false;
  // Both stores are mandatory. If Safari blocks either store, fail closed:
  // routing onward without tab intent could reuse the signed-in account A.
  try {
    window.sessionStorage.setItem(INTENT_KEY, slot);
    window.localStorage.setItem(KEY, JSON.stringify({ slot, startedAt: Date.now() }));
    return true;
  } catch {
    try { window.sessionStorage.removeItem(INTENT_KEY); } catch { /* Blocked. */ }
    return false;
  }
}

/** After a verified email callback opens in a different tab, associate that
 * tab with the exact same provisional identity before resuming signup. */
export function claimPendingAddAccountSlot(slot: string): boolean {
  if (typeof window === "undefined" || !validAddAccountSlot(slot)
      || getPendingAddAccountSlot() !== slot) return false;
  try {
    window.sessionStorage.setItem(INTENT_KEY, slot);
    return true;
  } catch {
    return false;
  }
}

export function clearPendingAddAccount(slot?: string): void {
  if (typeof window === "undefined") return;
  const own = getAddAccountIntentSlot();
  // Never clear a different tab's newer provisional account.
  if (slot && own && slot !== own) return;
  const target = slot ?? own;
  if (target && getPendingAddAccountSlot() === target) {
    window.localStorage.removeItem(KEY);
  }
  try { window.sessionStorage.removeItem(INTENT_KEY); } catch { /* Optional storage. */ }
}
