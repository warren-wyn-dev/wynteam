import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';
const code = ts.transpileModule(readFileSync(new URL('../lib/food-fulfillment-merchant.ts', import.meta.url), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
function fixture() {
  const calls = [], exports = {};
  runInNewContext(code, { exports, Uint8Array, require: () => ({ uploadFoodPrivateImage: async (...args) => { calls.push(args); return `${args[2]}/slip.jpg`; } }) });
  return { calls, api: exports };
}
test('refund completion rejects foreign, public or traversal evidence paths before calling RPC', async () => {
  const { api } = fixture(); let count = 0;
  const client = { rpc: async () => { count++; return { error: null }; } };
  for (const path of ['refunds/other/a.jpg', 'https://public.invalid/slip.jpg', 'refunds/order/../other.jpg']) {
    await assert.rejects(api.markStoreRefunded(client, 'store', 'order', path));
  }
  assert.equal(count, 0);
});
test('legacy refund uploads validate size and file content instead of trusting MIME alone', async () => {
  const { api, calls } = fixture();
  for (const file of [
    { size: 0, type: 'image/jpeg' },
    { size: 9 * 1024 * 1024, type: 'image/jpeg' },
    { size: 4, type: 'image/png', slice: () => ({ arrayBuffer: async () => new Uint8Array([60,115,118,103]).buffer }) },
  ]) await assert.rejects(api.uploadRefundSlip({}, 'store', 'order', file));
  assert.equal(calls.length, 0);
  const file = { size: 4, type: 'image/jpeg', slice: () => ({ arrayBuffer: async () => new Uint8Array([255,216,255,217]).buffer }) };
  assert.equal(await api.uploadRefundSlip({}, 'store', 'order', file), 'refunds/order/slip.jpg');
  assert.equal(calls.length, 1);
});
test('push listeners invalidate only the active account and are removed with the host', () => {
  const host = readFileSync(new URL('../components/merchant/merchant-flutter-app.tsx', import.meta.url), 'utf8');
  assert.match(host, /event\.data\.recipientId !== userId/);
  assert.match(host, /removeEventListener\("message", wake\)/);
  assert.match(host, /zoky-merchant-order-change/);
});
