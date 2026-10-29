import assert from 'node:assert/strict';
import { test } from 'node:test';
import { handleLineWebhook, verifyLineSignature } from '../../supabase/functions/zoky-line-webhook/handler.mjs';

const secret = 'node-local-test-only';
const bytes = (body) => new TextEncoder().encode(body);
async function signedHeader(body) {
  const key = await crypto.subtle.importKey('raw', bytes(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const signature = new Uint8Array(await crypto.subtle.sign('HMAC', key, bytes(body)));
  return Buffer.from(signature).toString('base64');
}
async function request(body, includeSignature = true) {
  const headers = includeSignature ? { 'x-line-signature': await signedHeader(body) } : {};
  return new Request('https://example.test/webhook', { method: 'POST', headers, body });
}

test('signed LINE verification request with events: [] succeeds', async () => {
  const response = await handleLineWebhook(await request('{"events":[]}'), secret);
  assert.equal(response.status, 200);
});
test('missing signature fails', async () => {
  assert.equal((await handleLineWebhook(await request('{"events":[]}', false), secret)).status, 401);
});
test('tampering is detected even when JSON meaning is unchanged', async () => {
  const original = '{"events":[]}';
  const sig = await signedHeader(original);
  assert.equal(await verifyLineSignature(bytes(original + ' '), sig, secret), false);
});
test('malformed signature is rejected', async () => {
  assert.equal(await verifyLineSignature(bytes('{"events":[]}'), 'abc', secret), false);
});
test('valid signed business events fail closed without changing any orders', async () => {
  assert.equal((await handleLineWebhook(await request('{"events":[{"type":"postback"}]}'), secret)).status, 503);
});
test('missing secret fails closed', async () => {
  assert.equal((await handleLineWebhook(await request('{"events":[]}'), '')).status, 503);
});
test('malformed JSON is rejected after signature check', async () => {
  assert.equal((await handleLineWebhook(await request('{"events":['), secret)).status, 400);
});
test('non-POST request is rejected', async () => {
  assert.equal((await handleLineWebhook(new Request('https://example.test/webhook'), secret)).status, 405);
});
test('oversized signed payload rejected', async () => {
  const body = '{"events":[],"extra":"' + 'x'.repeat(262144) + '"}';
  assert.equal((await handleLineWebhook(await request(body), secret)).status, 413);
});
