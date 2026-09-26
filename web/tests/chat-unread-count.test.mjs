import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");

test("Chat tab badge uses the shared auth.uid()-scoped RPC and never crosses accounts", () => {
  const lib = read("../lib/chat-unread-count.ts");
  const host = read("../components/app-bottom-nav-runtime.tsx");
  const nav = read("../components/bottom-navigation.tsx");
  // Same server definition as the Flutter app (respects chat lockdown).
  assert.match(lib, /client\.rpc\("count_unread_conversations"\)/);
  // A response that lands after an account switch is discarded.
  assert.match(lib, /getActiveAccountStorageKey\(\) !== accountKey\) return;/);
  // Only DM-related Push hints for this account trigger a refresh.
  assert.match(lib, /detail\.recipientId !== userId\) return;/);
  assert.match(lib, /detail\.type === "new_message"/);
  // Re-read when the route changes so a conversation just read clears.
  assert.match(host, /useUnreadChatCount\(userId \? getSupabaseBrowserClient\(\) : null, userId, pathname\)/);
  assert.match(nav, /chatUnreadCount > 9 \? "9\+" : chatUnreadCount/);
});

test("an older count response that resolves last never overwrites the newest one", async () => {
  const ts = (await import("typescript")).default;
  const { runInNewContext } = await import("node:vm");
  const source = read("../lib/chat-unread-count.ts");
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const mod = { exports: {} };
  const fakeReact = { useEffect: () => undefined, useSyncExternalStore: (_s, get) => get() };
  runInNewContext(compiled, {
    module: mod,
    exports: mod.exports,
    require: (name) => name === "react" ? fakeReact : { getActiveAccountStorageKey: () => "slot-a" },
  });
  const { refreshUnreadChatCount, useUnreadChatCount } = mod.exports;

  const pending = [];
  const client = { rpc: () => new Promise((resolve) => pending.push(resolve)) };
  const older = refreshUnreadChatCount(client, "u1"); // read before mark-read: 1
  const newer = refreshUnreadChatCount(client, "u1"); // read after mark-read: 0
  pending[1]({ data: 0, error: null });
  await newer;
  pending[0]({ data: 1, error: null });
  await older;
  assert.equal(useUnreadChatCount(client, "u1", "/chat"), 0);
});
