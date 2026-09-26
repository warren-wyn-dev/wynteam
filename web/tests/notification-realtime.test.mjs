import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../lib/notification-count.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  fileName: "notification-count.ts",
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;

function fixture() {
  let activeSlot = "wynos.account.test-a";
  let online = true;
  let countResult = 3;
  let nextFetch = null;
  let snapshot = () => 0;
  const queries = [];
  const channels = [];
  const activities = [];
  const timers = new Map();
  const intervals = new Map();
  const broadcasts = [];
  const cleanups = [];
  let nextTimer = 1;

  function target() {
    const listeners = new Map();
    return {
      addEventListener: (name, fn) => {
        const fns = listeners.get(name) ?? [];
        fns.push(fn); listeners.set(name, fns);
      },
      removeEventListener: (name, fn) => {
        listeners.set(name, (listeners.get(name) ?? []).filter((x) => x !== fn));
      },
      emit: (name, data) => (listeners.get(name) ?? []).forEach((fn) => fn(data)),
    };
  }
  const win = target();
  win.setTimeout = (fn) => { const id = nextTimer++; timers.set(id, fn); return id; };
  win.clearTimeout = (id) => timers.delete(id);
  win.setInterval = (fn) => { const id = nextTimer++; intervals.set(id, fn); return id; };
  win.clearInterval = (id) => intervals.delete(id);
  const document = target();
  document.visibilityState = "visible";
  const navigator = { get onLine() { return online; } };

  class FakeBroadcast {
    constructor(name) { this.name = name; broadcasts.push(this); }
    postMessage(data) { this.sent = data; }
    close() { this.closed = true; }
    deliver(data) { this.onmessage?.({ data }); }
  }
  const exports = {};
  const client = {
    from: (table) => {
      assert.equal(table, "notifications");
      const chain = {
        select: (column, options) => {
          assert.equal(column, "id");
          assert.equal(options.head, true);
          return chain;
        },
        eq: (key, value) => { queries.push([key, value]); return chain; },
        neq: (key, value) => {
          queries.push([key, value]);
          if (nextFetch) {
            const promise = nextFetch;
            nextFetch = null;
            return promise;
          }
          return Promise.resolve({ error: null, count: countResult });
        },
      };
      return chain;
    },
    channel: (name) => {
      const callbacks = {};
      const channel = {
        name, callbacks,
        on: (_, spec, callback) => { callbacks[spec.event] = { spec, callback }; return channel; },
        subscribe: (callback) => { channel.onStatus = callback; return channel; },
      };
      channels.push(channel);
      return channel;
    },
    removeChannel: async (channel) => { channel.removed = true; },
  };
  runInNewContext(compiled, {
    exports,
    require: (name) => {
      if (name === "react") return {
        useCallback: (callback) => callback,
        useEffect: (callback) => { cleanups.push(callback()); },
        useSyncExternalStore: (_, getSnapshot) => {
          snapshot = getSnapshot;
          return getSnapshot();
        },
      };
      if (name === "@/lib/account-registry") return {
        getActiveAccountStorageKey: () => activeSlot,
      };
      if (name === "@/lib/notification-events") return {
        emitNotificationChanges: (uid) => activities.push(uid),
      };
      throw new Error("Unexpected import: " + name);
    },
    window: win,
    document,
    navigator,
    BroadcastChannel: FakeBroadcast,
    Date,
  }, { filename: "notification-count.compiled.js" });

  const timersStep = () => {
    const task = timers.entries().next().value;
    if (task) { timers.delete(task[0]); task[1](); }
  };
  return {
    client,
    exports,
    queries,
    channels,
    activities,
    broadcasts,
    timers,
    intervals,
    document,
    win,
    hook: (uid = "account-a") => exports.useUnreadNotificationCount(client, uid, true),
    get count() { return snapshot(); },
    get unreadQueries() { return queries.filter(([key]) => key === "recipient_id").length; },
    setResult: (n) => { countResult = n; },
    deferFetch: () => {
      let resolve;
      const promise = new Promise((r) => { resolve = r; });
      nextFetch = promise;
      return resolve;
    },
    changeSlot: (slot) => { activeSlot = slot; },
    setOnline: (value) => { online = value; },
    pulse: (event = "INSERT", data = { id: "new-1", recipient_id: "account-a", type: "like_drop", is_read: false }) => {
      channels[0].callbacks[event].callback({ new: data });
    },
    push: (detail) => win.emit("wynos:notification-push", { detail }),
    time: timersStep,
    cleanup: () => cleanups.forEach((fn) => fn?.()),
  };
}

const flush = async () => { for (let i = 0; i < 15; i += 1) await Promise.resolve(); };

test("unread SQL excludes DM transport rows and duplicate badges share one Realtime channel", async () => {
  const f = fixture();
  f.hook();
  f.hook();
  await flush();
  assert.equal(f.channels.length, 1);
  assert.equal(f.unreadQueries, 1);
  assert.ok(f.queries.some(([key, value]) => key === "type" && value === "new_message"));
  assert.equal(f.count, 3);
  assert.equal(f.channels[0].callbacks.INSERT.spec.filter, "recipient_id=eq.account-a");
  f.cleanup();
});

test("a new Realtime INSERT updates the badge immediately and wakes the list once", async () => {
  const f = fixture();
  f.hook(); await flush();
  f.pulse();
  assert.equal(f.count, 4);
  assert.deepEqual(f.activities, ["account-a"]);
  f.pulse(); // Same row can also be delivered by FCM.
  assert.equal(f.count, 4);
  f.pulse("INSERT", { id: "message-1", recipient_id: "account-a", type: "new_message" });
  f.pulse("INSERT", { id: "wrong-user", recipient_id: "account-b", type: "like_drop" });
  assert.equal(f.count, 4);
  f.cleanup();
});

test("a stale SQL response must never erase a newer Realtime badge", async () => {
  const f = fixture();
  const resolve = f.deferFetch();
  f.hook();
  f.pulse();
  resolve({ error: null, count: 0 });
  await flush();
  f.time();
  await flush();
  assert.equal(f.count, 3, "after reconciling, only the new server count is authoritative");
  assert.equal(f.unreadQueries, 2);
  f.cleanup();
});

test("Push hints are scoped to the authenticated recipient and recover without a Realtime publication", async () => {
  const f = fixture();
  f.hook(); await flush();
  f.push({ recipientId: "account-b", notificationId: "not-for-a", type: "like_drop" });
  assert.equal(f.activities.length, 0);
  f.push({ notificationId: "new-from-old-edge", type: "follow" });
  assert.equal(f.count, 4, "legacy Push without recipient_id still reconciles only A via RLS");
  f.time(); await flush();
  assert.ok(f.unreadQueries >= 2);
  f.cleanup();
});

test("mark-read holds the optimistic zero until the bounded server update settles", async () => {
  const f = fixture();
  f.hook(); await flush();
  f.exports.markNotificationsRead("account-a");
  assert.equal(f.count, 0);
  const before = f.unreadQueries;
  f.push({ notificationId: "arrived-during-read", type: "comment_drop" });
  assert.equal(f.count, 1);
  f.time(); await flush();
  assert.equal(f.unreadQueries, before, "do not fetch stale unread state during the mutation");
  f.setResult(1);
  f.exports.settleNotificationsRead(f.client, "account-a");
  f.time(); await flush();
  assert.equal(f.count, 1);
  assert.equal(f.unreadQueries, before + 1);
  f.cleanup();
});

test("another browser tab's invalidation carries no content and never wakes another account", async () => {
  const f = fixture();
  f.hook(); await flush();
  f.broadcasts[0].deliver({ userId: "account-b", kind: "new", notificationId: "other" });
  assert.deepEqual(f.activities, []);
  f.broadcasts[0].deliver({ userId: "account-a", kind: "sync" });
  assert.deepEqual(f.activities, ["account-a"]);
  assert.equal(f.count, 3);
  f.cleanup();
});

test("the former account cannot process delayed Push after an account switch", async () => {
  const f = fixture();
  f.hook(); await flush();
  f.changeSlot("wynos.account.test-b");
  f.push({ notificationId: "a-late-push", type: "follow" });
  f.pulse();
  assert.deepEqual(f.activities, []);
  assert.equal(f.count, 3);
  f.cleanup();
});

test("notification page shows cache instantly, reconciles missed events and guards snapshot mark-read", () => {
  const route = readFileSync(new URL("../components/notifications-route.tsx", import.meta.url), "utf8");
  const data = readFileSync(new URL("../lib/phase3-data.ts", import.meta.url), "utf8");
  const fg = readFileSync(new URL("../lib/push-notifications.ts", import.meta.url), "utf8");
  const worker = readFileSync(new URL("../public/sw.js", import.meta.url), "utf8");
  assert.match(route, /useState\(!cached\)/);
  assert.match(route, /subscribeNotificationChanges\(userId, refresh\)/);
  assert.match(route, /markAllNotificationsRead\(client, userId, next\[0\]\.created_at\)/);
  assert.match(route, /settleNotificationsRead\(client, userId\)/);
  assert.match(data, /request\.lte\("created_at", newestVisibleCreatedAt\)/);
  assert.match(fg, /window\.dispatchEvent\(new CustomEvent\("wynos:notification-push"/);
  assert.match(worker, /kind: "wynos:notification-push"/);
});
