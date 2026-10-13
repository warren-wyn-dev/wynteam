type IntentStorage = Pick<Storage, "getItem" | "setItem" | "removeItem">;
const memory = new Map<string, { fingerprint: string; key: string; usesV3: boolean }>();

export function checkoutIntentUsesV3(userId: string, storage: IntentStorage | null) {
  const slot = `wynos.food.checkout-intent:${userId}`;
  try { return (JSON.parse(storage?.getItem(slot) ?? "null") ?? memory.get(slot))?.usesV3 === true; }
  catch { return memory.get(slot)?.usesV3 === true; }
}

/** Persist only a UUID and request fingerprint, never address/contact/cart data. */
export async function checkoutIntentKey(
  userId: string,
  payload: unknown,
  storage: IntentStorage | null,
): Promise<string> {
  const encoded = new TextEncoder().encode(JSON.stringify(payload));
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  const fingerprint = Array.from(new Uint8Array(digest), (n) => n.toString(16).padStart(2, "0")).join("");
  const slot = `wynos.food.checkout-intent:${userId}`;
  try {
    const prior = JSON.parse(storage?.getItem(slot) ?? "null") ?? memory.get(slot);
    // An unresolved attempt keeps its key even if refresh changes the quote
    // or the user edits the cart. The backend resolves/conflicts that intent
    // before another order may be created; a network error is not a new sale.
    if (typeof prior?.key === "string"
      && /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(prior.key)) return prior.key;
  } catch { /* Invalid or unavailable storage: new key for this attempt. */ }
  const prior = memory.get(slot);
  if (prior) return prior.key;
  const key = crypto.randomUUID();
  const usesV3 = Boolean(payload && typeof payload === "object" && "pricingRuleVersion" in payload
    && payload.pricingRuleVersion === "food_checkout_v3");
  memory.set(slot, { fingerprint, key, usesV3 });
  try { storage?.setItem(slot, JSON.stringify({ fingerprint, key, usesV3 })); } catch { /* private mode */ }
  return key;
}

export function clearCheckoutIntent(userId: string, storage: IntentStorage | null) {
  memory.delete(`wynos.food.checkout-intent:${userId}`);
  try { storage?.removeItem(`wynos.food.checkout-intent:${userId}`); } catch { /* private mode */ }
}
