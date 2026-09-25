import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../lib/push-notifications.ts", import.meta.url), "utf8");

function moduleWithNavigator(navigatorValue) {
  const { outputText } = ts.transpileModule(source, {
    fileName: "push-notifications.ts",
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const exports = {};
  runInNewContext(outputText, { exports, navigator: navigatorValue }, {
    filename: "push-notifications.compiled.js",
  });
  return exports;
}

test("network-detach fallback unsubscribes an active browser PushSubscription", async () => {
  let count = 0;
  const navigator = {
    serviceWorker: {
      getRegistration: async (scope) => {
        assert.equal(scope, "/");
        return { pushManager: { getSubscription: async () => ({
          unsubscribe: async () => { count++; return true; },
        }) } };
      },
    },
  };
  const result = await moduleWithNavigator(navigator).revokeLocalPushSubscription();
  assert.equal(result, true);
  assert.equal(count, 1);
});

test("no active subscription is already locally clear, without deleting the PWA worker", async () => {
  const navigator = {
    serviceWorker: {
      getRegistration: async () => ({
        pushManager: { getSubscription: async () => null },
      }),
    },
  };
  assert.equal(await moduleWithNavigator(navigator).revokeLocalPushSubscription(), true);
});

test("unsupported, missing registration or rejected unsubscribe never claim successful revocation", async () => {
  assert.equal(await moduleWithNavigator({}).revokeLocalPushSubscription(), false);
  assert.equal(await moduleWithNavigator({ serviceWorker: { getRegistration: async () => null } })
    .revokeLocalPushSubscription(), false);
  const navigator = {
    serviceWorker: {
      getRegistration: async () => ({
        pushManager: { getSubscription: async () => ({
          unsubscribe: async () => { throw new Error("offline"); },
        }) },
      }),
    },
  };
  assert.equal(await moduleWithNavigator(navigator).revokeLocalPushSubscription(), false);
});

test("logout tries local Push revoke only after failed server detach and before auth is removed", () => {
  const gate = readFileSync(new URL("../components/developer-route-gate.tsx", import.meta.url), "utf8");
  const server = gate.indexOf("const serverDetached = await unsubscribeFromPushNotifications(client);");
  const fallback = gate.indexOf("if (!serverDetached) await revokeLocalPushSubscription();",server);
  const logout = gate.indexOf("await client.auth.signOut();",fallback);
  assert.ok(server >= 0 && fallback > server && logout > fallback);
  assert.match(gate, /if \(!serverDetached\) await revokeLocalPushSubscription\(\);/);
});
