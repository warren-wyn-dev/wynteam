import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = readFileSync(new URL("../app/api/push-config/route.ts", import.meta.url), "utf8");

test("Push config prefers Vercel env and falls back to the public Supabase bridge", () => {
  assert.match(source, /NEXT_PUBLIC_FIREBASE_API_KEY/);
  assert.match(source, /NEXT_PUBLIC_SUPABASE_URL \|\| process\.env\.SUPABASE_URL/);
  assert.match(source, /functions\/v1\/web-push-config-bridge/);
  assert.match(source, /validBridgeConfig/);
  assert.match(source, /configured: false/);
  assert.doesNotMatch(source, /SUPABASE_SERVICE_ROLE_KEY/);
  assert.doesNotMatch(source, /service_role/);
});
