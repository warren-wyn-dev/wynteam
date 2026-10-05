import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const proxy = readFileSync(new URL("../proxy.ts", import.meta.url), "utf8");

test("maps.wynos.online root redirects to signed-in WYNOS Maps on wynos.online", () => {
  assert.match(proxy, /"maps\.wynos\.online": "https:\/\/wynos\.online\/maps"/);
  assert.match(proxy, /NextResponse\.redirect\(target, 307\)/);
  assert.doesNotMatch(proxy, /"maps\.wynos\.online": "\/maps"/);
});

test("food and merchant subdomains keep their root rewrites", () => {
  assert.match(proxy, /"food\.wynos\.online": "\/food"/);
  assert.match(proxy, /"merchant\.wynos\.online": "\/merchant"/);
});
