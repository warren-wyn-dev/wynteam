/** Session-only, user- and conversation-scoped unsent text. Never stores messages
 * or FCM tokens, and does not survive a confirmed sign-out. */
export const CHAT_DRAFT_PREFIX = "wynos.chat-draft.v1:";
const MAX_DRAFT_CHARS = 10000;

function storage(): Storage | null {
  if (typeof window === "undefined") return null;
  try { return window.sessionStorage; } catch { return null; }
}

export function chatDraftKey(userId: string, conversationId: string, recipientId = ""): string {
  if (!userId || !conversationId) throw new Error("Chat draft requires an account and conversation");
  const room = conversationId === "new" ? `new:${recipientId}` : conversationId;
  return `${CHAT_DRAFT_PREFIX}${encodeURIComponent(userId)}:${encodeURIComponent(room)}`;
}

export function readChatDraft(key: string): string {
  if (!key.startsWith(CHAT_DRAFT_PREFIX)) return "";
  try { return (storage()?.getItem(key) ?? "").slice(0, MAX_DRAFT_CHARS); } catch { return ""; }
}

export function writeChatDraft(key: string, text: string): void {
  if (!key.startsWith(CHAT_DRAFT_PREFIX)) return;
  try {
    const store = storage();
    if (!store) return;
    if (text.trim()) store.setItem(key, text.slice(0, MAX_DRAFT_CHARS));
    else store.removeItem(key);
  } catch { /* Storage may be blocked; text stays in React state. */ }
}

export function clearChatDraft(key: string): void {
  if (!key.startsWith(CHAT_DRAFT_PREFIX)) return;
  try { storage()?.removeItem(key); } catch { /* safe to ignore */ }
}

/** Wipe all unsent device text on logout or an unexpected identity change. */
export function clearSessionChatDrafts(): void {
  try {
    const store = storage();
    if (!store) return;
    for (let index = store.length - 1; index >= 0; index -= 1) {
      const key = store.key(index);
      if (key?.startsWith(CHAT_DRAFT_PREFIX)) store.removeItem(key);
    }
  } catch { /* Never block sign-out because browser storage is unavailable. */ }
}

/** Purge only this removed account's unsent text. */
export function clearChatDraftsForUser(userId: string): void {
  if (!userId) return;
  try {
    const store = storage();
    if (!store) return;
    const prefix = CHAT_DRAFT_PREFIX + encodeURIComponent(userId) + ":";
    for (let index = store.length - 1; index >= 0; index -= 1) {
      const key = store.key(index);
      if (key?.startsWith(prefix)) store.removeItem(key);
    }
  } catch { /* Never block removing a saved account. */ }
}
