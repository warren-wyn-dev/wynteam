// The Web Beta2 development track was suspended by Founder decision
// 2026-09-29. Its three completed features were folded into Web Beta1 and
// released to all eligible users. This compatibility map must stay public;
// future features must not be added here.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = readFileSync(new URL("../lib/beta2.ts", import.meta.url), "utf8");

test("retired Beta2 features are permanently public", () => {
  const block = source.slice(source.indexOf("BETA2_RELEASED = {"), source.indexOf("} as const"));
  const entries = [...block.matchAll(/^\s+(\w+): (true|false),$/gm)].map(([, name, value]) => [name, value]);
  assert.deepEqual(entries, [
    ["chatThreads", "true"],
    ["clubChatActions", "true"],
    ["clubAnnouncements", "true"],
  ]);
});

test("retired Beta2 compatibility no longer consults the developer allowlist", () => {
  assert.doesNotMatch(source, /useIsDeveloperAccount/);
  assert.match(source, /return BETA2_RELEASED\[feature\]/);
  assert.match(source, /Do not add new features to this map/);
});
