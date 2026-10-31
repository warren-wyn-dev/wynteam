import { handleLineWebhook, verifyLineSignature } from './handler.mjs';

const secret = 'local-test-only';
const bytes = (s: string) => new TextEncoder().encode(s);
async function signature(body: string) {
  const key = await crypto.subtle.importKey(
    'raw', bytes(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const digest = new Uint8Array(await crypto.subtle.sign('HMAC', key, bytes(body)));
  return btoa(String.fromCharCode(...digest));
}
async function req(body: string, signed = true) {
  return new Request('https://example.test/functions/v1/zoky-line-webhook', {
    method: 'POST',
    headers: signed ? { 'x-line-signature': await signature(body) } : {},
    body,
  });
}
Deno.test('accepts LINE signed empty verify events only', async () => {
  const response = await handleLineWebhook(await req('{"destination":"U123","events":[]}'), secret);
  if (response.status !== 200) throw Error('invalid verification response');
});
Deno.test('rejects absent or tampered signature', async () => {
  const body = '{"events":[]}';
  if ((await handleLineWebhook(await req(body, false), secret)).status !== 401) throw Error('missing signature accepted');
  const signed = await signature(body);
  if (await verifyLineSignature(bytes(body + ' '), signed, secret)) throw Error('tampered body accepted');
});
Deno.test('does not acknowledge signed business events before implementation', async () => {
  const response = await handleLineWebhook(await req('{"events":[{"type":"postback"}]}'), secret);
  if (response.status !== 503) throw Error('business event falsely acknowledged');
});
Deno.test('requires configured secret', async () => {
  const response = await handleLineWebhook(await req('{"events":[]}'), '');
  if (response.status !== 503) throw Error('missing secret accepted');
});
