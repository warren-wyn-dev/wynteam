import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

function load(path) {
  const source = readFileSync(new URL(path, import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const exports = {};
  runInNewContext(outputText, { exports, Date, JSON, encodeURIComponent, Promise });
  return exports;
}

function store() {
  const values = new Map();
  return {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: (key) => values.delete(key),
    get length() { return values.size; },
    key: (i) => [...values.keys()][i] ?? null,
  };
}
const drafts = load("../lib/chat-text-drafts.ts");
const resume = load("../lib/chat-resume.ts");

test("text survives reload but is isolated by user and conversation", () => {
  const s = store(), t = 1_000_000;
  assert.equal(drafts.writeChatTextDraft("alice", "room1", "Hello", s, t), true);
  assert.equal(drafts.readChatTextDraft("alice", "room1", s, t + 1000), "Hello");
  assert.equal(drafts.readChatTextDraft("alice", "room2", s, t + 1000), "");
  assert.equal(drafts.readChatTextDraft("bob", "room1", s, t + 1000), "");
  drafts.writeChatTextDraft("bob", "room1", "Private B", s, t);
  drafts.clearChatTextDraftsForUser("alice", s);
  assert.equal(drafts.readChatTextDraft("alice", "room1", s, t + 1000), "");
  assert.equal(drafts.readChatTextDraft("bob", "room1", s, t + 1000), "Private B");
});

test("expired, corrupt, blank, and excessively long drafts do not persist", () => {
  const s = store(), t = 123_000_000;
  drafts.writeChatTextDraft("alice", "room1", "Keep", s, t);
  assert.equal(drafts.readChatTextDraft("alice", "room1", s, t + 86_400_001), "");
  s.setItem(drafts.chatTextDraftKey("alice", "room1"), "not-json");
  assert.equal(drafts.readChatTextDraft("alice", "room1", s, t), "");
  assert.equal(drafts.writeChatTextDraft("alice", "room1", "x".repeat(10_001), s, t), false);
  assert.equal(drafts.writeChatTextDraft("alice", "room1", "   ", s, t), true);
  assert.equal(s.length, 0);
});

function events() {
  const slots = new Map();
  return {
    addEventListener(name, fn) { slots.set(name, fn); },
    removeEventListener(name, fn) { if (slots.get(name) === fn) slots.delete(name); },
    emit(name) { slots.get(name)?.(); },
    get listenerCount() { return slots.size; },
  };
}
test("offline/hidden tabs defer refresh; reconnect/focus coalesce; cleanup detaches listeners", async () => {
  const win = Object.assign(events(), { navigator: { onLine: false } });
  const doc = Object.assign(events(), { visibilityState: "visible" });
  let calls = 0;
  const remove = resume.attachChatResume(() => { calls++; }, { window: win, document: doc });
  win.emit("online");
  await Promise.resolve(); await Promise.resolve();
  assert.equal(calls, 0);
  win.navigator.onLine = true;
  doc.visibilityState = "hidden";
  doc.emit("visibilitychange");
  await Promise.resolve(); await Promise.resolve();
  assert.equal(calls, 0);
  doc.visibilityState = "visible";
  win.emit("online");
  doc.emit("visibilitychange");
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(calls, 1);
  remove();
  assert.equal(win.listenerCount + doc.listenerCount, 0);
  doc.emit("visibilitychange");
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(calls, 1);
});

test("successful send clears saved text, failure path restores visible composer text", () => {
  const source = readFileSync(new URL("../components/chat-routes.tsx", import.meta.url), "utf8");
  const success = source.indexOf("clearChatTextDraft(userId, textDraftScope)");
  const failure = source.indexOf("setDraft(text); setFile(attachedFile);", success);
  assert.ok(success > source.indexOf("await sendMessage(") && failure > success);
});
