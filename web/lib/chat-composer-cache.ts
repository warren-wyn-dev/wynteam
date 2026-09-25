// Per-tab, in-memory Chat composer text only. Never persist private unsent
// messages to localStorage, IndexedDB, telemetry or browser history.
type Draft = { text: string; writtenAt: number };
const drafts = new Map<string, Draft>();
const MAX_OPEN_DRAFTS = 32;
const MAX_AGE_MS = 6 * 60 * 60 * 1000;

function key(userId: string, conversationKey: string): string {
  return JSON.stringify([userId, conversationKey]);
}

export function readChatComposerDraft(userId: string, conversationKey: string): string {
  if (!userId || !conversationKey) return "";
  const id = key(userId, conversationKey);
  const draft = drafts.get(id);
  if (!draft) return "";
  if (Date.now() - draft.writtenAt >= MAX_AGE_MS) {
    drafts.delete(id);
    return "";
  }
  return draft.text;
}

export function writeChatComposerDraft(userId: string, conversationKey: string, text: string): void {
  if (!userId || !conversationKey) return;
  const id = key(userId, conversationKey);
  drafts.delete(id);
  if (!text) return;
  drafts.set(id, { text, writtenAt: Date.now() });
  if (drafts.size > MAX_OPEN_DRAFTS) {
    const oldest = drafts.keys().next().value;
    if (oldest !== undefined) drafts.delete(oldest);
  }
}

export function clearChatComposerDraft(userId: string, conversationKey: string): void {
  if (userId && conversationKey) drafts.delete(key(userId, conversationKey));
}

export function clearAllChatComposerDrafts(): void {
  drafts.clear();
}
