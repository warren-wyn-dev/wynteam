import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { test } from "node:test";
import ts from "typescript";

function harness(blocked = false) {
  const source = readFileSync(new URL("../lib/chat-draft-storage.ts", import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    fileName: "chat-draft-storage.ts",
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const rows = new Map();
  const sessionStorage = {
    get length() { return rows.size; },
    key: (index) => [...rows.keys()][index] ?? null,
    getItem: (key) => rows.get(key) ?? null,
    setItem: (key, value) => rows.set(key, String(value)),
    removeItem: (key) => rows.delete(key),
  };
  const window = blocked ? Object.defineProperty({}, "sessionStorage", {
    get() { throw new Error("Storage blocked"); },
  }) : { sessionStorage };
  const exports = {};
  runInNewContext(outputText, { exports, window }, { filename: "chat-draft-storage.js" });
  return { api: exports, rows, sessionStorage };
}

test("unsent text survives local remount without mixing users or conversations", () => {
  const { api } = harness();
  const a = api.chatDraftKey("account-A", "room-1");
  const b = api.chatDraftKey("account-B", "room-1");
  const c = api.chatDraftKey("account-A", "room-2");
  api.writeChatDraft(a, "message for A");
  api.writeChatDraft(b, "message for B");
  api.writeChatDraft(c, "another room");
  assert.equal(api.readChatDraft(a), "message for A");
  assert.equal(api.readChatDraft(b), "message for B");
  assert.equal(api.readChatDraft(c), "another room");
  assert.notEqual(api.chatDraftKey("A", "new", "recipient-1"), api.chatDraftKey("A", "new", "recipient-2"));
});

test("confirmed send removes only the sent draft", () => {
  const { api } = harness();
  const a = api.chatDraftKey("A", "room");
  const b = api.chatDraftKey("B", "room");
  api.writeChatDraft(a, "sent");
  api.writeChatDraft(b, "keep");
  api.clearChatDraft(a);
  assert.equal(api.readChatDraft(a), "");
  assert.equal(api.readChatDraft(b), "keep");
  api.writeChatDraft(b, "  ");
  assert.equal(api.readChatDraft(b), "");
});

test("sign-out wipes every chat draft without touching unrelated session data", () => {
  const { api, sessionStorage } = harness();
  api.writeChatDraft(api.chatDraftKey("A", "room"), "secret-A");
  api.writeChatDraft(api.chatDraftKey("B", "room"), "secret-B");
  sessionStorage.setItem("oauth-verifier", "keep");
  api.clearSessionChatDrafts();
  assert.equal(sessionStorage.length, 1);
  assert.equal(sessionStorage.getItem("oauth-verifier"), "keep");
});

test("storage permission failures never block composing, navigation or sign-out", () => {
  const { api } = harness(true);
  const key = api.chatDraftKey("A", "room");
  assert.doesNotThrow(() => api.writeChatDraft(key, "unsent text"));
  assert.equal(api.readChatDraft(key), "");
  assert.doesNotThrow(() => api.clearSessionChatDrafts());
});


test("read-receipt failure cannot trigger a false successful-send failure", () => {
  const thread = readFileSync(new URL("../components/chat-routes.tsx", import.meta.url), "utf8");
  assert.match(thread, /void markConversationRead\(client, realConversationId\)\.catch\(/);
  assert.match(thread, /await markConversationRead\(client, conversationId\)\.catch\(/);
});


test("removing a saved account purges only its chat drafts", () => {
  const { api } = harness();
  const a = api.chatDraftKey("A", "room"), b = api.chatDraftKey("B", "room");
  api.writeChatDraft(a, "A private"); api.writeChatDraft(b, "B private");
  api.clearChatDraftsForUser("B");
  assert.equal(api.readChatDraft(a), "A private");
  assert.equal(api.readChatDraft(b), "");
});
