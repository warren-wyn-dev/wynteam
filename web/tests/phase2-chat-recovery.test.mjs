import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

function loadModule(path, extras = {}) {
  const source = readFileSync(new URL(path, import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    fileName: path, compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const exports = {};
  runInNewContext(outputText, { exports, ...extras }, { filename: path });
  return exports;
}

test("composer text survives route unmount, but stays isolated by user and thread", () => {
  const c = loadModule("../lib/chat-composer-cache.ts");
  c.writeChatComposerDraft("A", "thread1", "Private to A");
  c.writeChatComposerDraft("A", "thread2", "Second thread");
  assert.equal(c.readChatComposerDraft("A", "thread1"), "Private to A");
  assert.equal(c.readChatComposerDraft("A", "thread2"), "Second thread");
  assert.equal(c.readChatComposerDraft("B", "thread1"), "");
  c.clearChatComposerDraft("A", "thread1");
  assert.equal(c.readChatComposerDraft("A", "thread1"), "");
  c.clearAllChatComposerDrafts();
  assert.equal(c.readChatComposerDraft("A", "thread2"), "");
});

test("stale composer text expires, and successful send clears it", () => {
  let timestamp = 100_000;
  const c = loadModule("../lib/chat-composer-cache.ts", { Date: { now: () => timestamp } });
  c.writeChatComposerDraft("A", "thread", "unsent");
  assert.equal(c.readChatComposerDraft("A", "thread"), "unsent");
  timestamp += 6 * 60 * 60 * 1000;
  assert.equal(c.readChatComposerDraft("A", "thread"), "");
  c.writeChatComposerDraft("A", "thread", "new text");
  c.writeChatComposerDraft("A", "thread", "");
  assert.equal(c.readChatComposerDraft("A", "thread"), "");
});

test("returning online coalesces visibility/focus events and detaches listeners", () => {
  const win = new Map(), doc = new Map();
  let timestamp = 5_000, fired = 0;
  const eventSource = (listeners) => ({
    addEventListener: (name, callback) => listeners.set(name, callback),
    removeEventListener: (name, callback) => {
      if (listeners.get(name) === callback) listeners.delete(name);
    },
  });
  const document = { visibilityState: "visible", ...eventSource(doc) };
  const navigator = { onLine: true };
  const window = eventSource(win);
  const m = loadModule("../lib/chat-resume.ts", { document, navigator, window, Date: { now: () => timestamp } });
  const detach = m.attachChatResume(() => { fired++; });
  win.get("focus")();
  doc.get("visibilitychange")();
  assert.equal(fired, 1);
  timestamp += 3_100;
  document.visibilityState = "hidden";
  win.get("focus")();
  assert.equal(fired, 1);
  document.visibilityState = "visible";
  navigator.onLine = false;
  win.get("online")();
  assert.equal(fired, 1);
  navigator.onLine = true;
  win.get("online")();
  assert.equal(fired, 2);
  detach();
  assert.equal(win.size, 0);
  assert.equal(doc.size, 0);
});

test("Chat routes wire backfill, per-account cache clearance and no duplicate send on read-receipt error", () => {
  const thread = readFileSync(new URL("../components/chat-routes.tsx", import.meta.url), "utf8");
  const inbox = readFileSync(new URL("../components/chat-inbox-parity.tsx", import.meta.url), "utf8");
  const gate = readFileSync(new URL("../components/developer-route-gate.tsx", import.meta.url), "utf8");
  assert.match(thread, /attachChatResume\(\(\) => \{ void refresh\(\); \}\)/);
  assert.match(inbox, /attachChatResume\(\(\) => \{ void refetch\(\); \}\)/);
  assert.match(thread, /clearChatComposerDraft\(userId, composerKey\)/);
  assert.match(thread, /void markConversationRead\(client, realConversationId\)\.catch/);
  assert.match(gate, /clearAllChatComposerDrafts\(\)/);
});
