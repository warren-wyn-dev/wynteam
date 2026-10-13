import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import ts from "typescript";

const exports = {};
vm.runInNewContext(ts.transpileModule(readFileSync(new URL("../lib/food-merchant.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText, { exports, require: () => ({}) });

test("rejection requires a bounded reason before any write", async () => {
  let calls = 0;
  for (const reason of ["  ", "x".repeat(1001)]) {
    await assert.rejects(exports.rejectFoodOrder({ rpc: async () => { calls++; } }, "order", reason));
  }
  assert.equal(calls, 0);
});

test("rejection uses strict server RPC and trims reason", async () => {
  const calls = [];
  await exports.rejectFoodOrder({ rpc: async (name, args) => { calls.push({ name, args }); return { error: null }; } }, "order", "  เมนูหมด  ");
  assert.equal(calls[0].name, "food_reject_order");
  assert.equal(calls[0].args.p_reason, "เมนูหมด");
  assert.equal(calls.length, 1);
});

test("old database fallback preserves reason only on known missing RPC", async () => {
  const calls = [];
  await exports.rejectFoodOrder({ rpc: async (name, args) => {
    calls.push({ name, args });
    return { error: name === "food_reject_order" ? { code: "PGRST202", message: "missing" } : null };
  } }, "order", "เมนูหมด");
  assert.equal(calls.length, 2);
  assert.equal(calls[1].name, "food_transition_order");
  assert.equal(calls[1].args.p_note, "เมนูหมด");
});

test("unknown response or authorization failure never retries another write", async () => {
  for (const error of [{ code: "42501", message: "denied" }, { message: "network failed" }]) {
    let calls = 0;
    await assert.rejects(exports.rejectFoodOrder({ rpc: async () => { calls++; return { error }; } }, "order", "เมนูหมด"));
    assert.equal(calls, 1);
  }
});
