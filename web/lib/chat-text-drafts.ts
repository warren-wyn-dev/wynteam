/** Private, same-tab text drafts. Never persist image attachments or tokens. */
const PREFIX = "wynos-chat-text-draft:v1:";
const EXPIRE_MS = 24 * 60 * 60 * 1000;
const MAX_LENGTH = 10_000;

type DraftStore = Pick<Storage, "getItem" | "setItem" | "removeItem" | "length" | "key">;

function browserStore(): DraftStore | null {
  if (typeof window === "undefined") return null;
  try { return window.sessionStorage; } catch { return null; }
}

export function chatTextDraftKey(userId: string, conversationKey: string): string | null {
  if (!userId || !conversationKey) return null;
  return PREFIX + encodeURIComponent(userId) + ":" + encodeURIComponent(conversationKey);
}

export function readChatTextDraft(
  userId: string, conversationKey: string, store: DraftStore | null = browserStore(),
  now = Date.now(),
): string {
  const key = chatTextDraftKey(userId, conversationKey);
  if (!key || !store) return "";
  try {
    const raw = store.getItem(key);
    if (!raw) return "";
    const data: unknown = JSON.parse(raw);
    if (!data || typeof data !== "object") throw new Error("Invalid text draft");
    const { text, savedAt } = data as { text?: unknown; savedAt?: unknown };
    if (typeof text !== "string" || text.length > MAX_LENGTH ||
        typeof savedAt !== "number" || now < savedAt || now - savedAt > EXPIRE_MS) {
      store.removeItem(key);
      return "";
    }
    return text;
  } catch {
    try { store.removeItem(key); } catch { /* storage unavailable */ }
    return "";
  }
}

export function writeChatTextDraft(
  userId: string, conversationKey: string, text: string,
  store: DraftStore | null = browserStore(), now = Date.now(),
): boolean {
  const key = chatTextDraftKey(userId, conversationKey);
  if (!key || !store || text.length > MAX_LENGTH) return false;
  try {
    if (!text.trim()) store.removeItem(key);
    else store.setItem(key, JSON.stringify({ text, savedAt: now }));
    return true;
  } catch { return false; }
}

export function clearChatTextDraft(
  userId: string, conversationKey: string, store: DraftStore | null = browserStore(),
): void {
  const key = chatTextDraftKey(userId, conversationKey);
  if (!key || !store) return;
  try { store.removeItem(key); } catch { /* storage unavailable */ }
}

/** Remove ephemeral private text before ending a shared-device session. */
export function clearChatTextDraftsForUser(
  userId: string, store: DraftStore | null = browserStore(),
): void {
  if (!userId || !store) return;
  const prefix = PREFIX + encodeURIComponent(userId) + ":";
  try {
    const keys: string[] = [];
    for (let i = 0; i < store.length; i++) {
      const key = store.key(i);
      if (key?.startsWith(prefix)) keys.push(key);
    }
    for (const key of keys) store.removeItem(key);
  } catch { /* browser disabled session storage */ }
}
