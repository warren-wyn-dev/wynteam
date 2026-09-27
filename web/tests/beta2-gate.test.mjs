// Web Beta2: every Beta2 feature starts developer-only; releasing one is a
// deliberate, Founder-approved change to BETA2_RELEASED.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = readFileSync(new URL("../lib/beta2.ts", import.meta.url), "utf8");

test("Beta2 features are developer-only until the Founder releases them", () => {
  const block = source.slice(source.indexOf("BETA2_RELEASED = {"), source.indexOf("} as const"));
  const entries = [...block.matchAll(/^\s+(\w+): (true|false),$/gm)].map(([, name, value]) => [name, value]);
  assert.ok(entries.length > 0, "BETA2_RELEASED lists the Beta2 features");
  // A feature flipped to true must be recorded as released by the Founder.
  const approvals = readFileSync(new URL("../../.wyn/company/APPROVALS.md", import.meta.url), "utf8");
  for (const [name, value] of entries) {
    if (value === "true") assert.match(approvals, new RegExp(`Beta2 release: ${name}\\b`), `${name} release needs a "Beta2 release: ${name}" approval entry`);
  }
});

test("the gate fails closed through the developer RPC", () => {
  assert.match(source, /BETA2_RELEASED\[feature\] \|\| isDeveloper/);
  assert.match(source, /useIsDeveloperAccount\(client, userId\)/);
});
