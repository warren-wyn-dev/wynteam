// ZOKY-114: which origin Food auth and post-login navigation use per host.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const out = ts.transpileModule(readFileSync(new URL("../lib/food-origin.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(out, { module: mod, exports: mod.exports, Set, URL });
const { FOOD_PRODUCTION_ORIGIN, foodAuthOriginFor, foodHomeUrlFor, isFoodAppHost } = mod.exports;

test("ZOKY is the canonical Food origin; food.wynos.online is still a Food host during the move", () => {
  assert.equal(FOOD_PRODUCTION_ORIGIN, "https://zoky.wynos.online");
  assert.equal(isFoodAppHost("zoky.wynos.online"), true);
  assert.equal(isFoodAppHost("ZOKY.WYNOS.ONLINE"), true);
  assert.equal(isFoodAppHost("food.wynos.online"), true);
  for (const host of ["wynos.online", "www.wynos.online", "merchant.wynos.online", "zoky.online", "evil-zoky.wynos.online.example", "localhost"]) {
    assert.equal(isFoodAppHost(host), false, host);
  }
});

test("Food auth stays on the Food origin it started on and moves Social-origin Food to ZOKY", () => {
  assert.equal(foodAuthOriginFor("zoky.wynos.online", "https://zoky.wynos.online"), "https://zoky.wynos.online");
  assert.equal(foodAuthOriginFor("food.wynos.online", "https://food.wynos.online"), "https://food.wynos.online");
  assert.equal(foodAuthOriginFor("wynos.online", "https://wynos.online"), "https://zoky.wynos.online");
  assert.equal(foodAuthOriginFor("www.wynos.online", "https://www.wynos.online"), "https://zoky.wynos.online");
  // Local and preview builds keep their own origin.
  assert.equal(foodAuthOriginFor("localhost", "http://localhost:3000"), "http://localhost:3000");
  assert.equal(foodAuthOriginFor("wynos-web-git-x.vercel.app", "https://wynos-web-git-x.vercel.app"), "https://wynos-web-git-x.vercel.app");
});

test("after sign-in Food opens at the root of a Food origin, else /food on this origin", () => {
  assert.equal(foodHomeUrlFor("zoky.wynos.online", "https://zoky.wynos.online"), "https://zoky.wynos.online/");
  assert.equal(foodHomeUrlFor("food.wynos.online", "https://food.wynos.online"), "https://food.wynos.online/");
  assert.equal(foodHomeUrlFor("wynos.online", "https://wynos.online"), "https://zoky.wynos.online/");
  assert.equal(foodHomeUrlFor("localhost", "http://localhost:3000"), "http://localhost:3000/food");
});
