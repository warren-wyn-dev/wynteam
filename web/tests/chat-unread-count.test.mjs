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
