// Safe, fail-closed preview: authenticates LINE's raw webhook body.
// Do not acknowledge real events until durable event processing is implemented.
const MAX_BODY_BYTES = 262144;

function reply(code, status) {
  return new Response(JSON.stringify({ status: code }), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });
}

export async function verifyLineSignature(rawBytes, signature, secret) {
  if (!secret || !signature || !/^[A-Za-z0-9+/]{43}=$/.test(signature)) return false;
  let supplied;
  try {
    supplied = Uint8Array.from(atob(signature), (character) => character.charCodeAt(0));
  } catch {
    return false;
  }
  if (supplied.byteLength !== 32) return false;
  const secretKey = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'],
  );
  // Verify exactly the received bytes, before JSON parsing/normalizing them.
  return crypto.subtle.verify('HMAC', secretKey, supplied, rawBytes);
}

export async function handleLineWebhook(request, secret) {
  if (request.method !== 'POST') return reply('method_not_allowed', 405);
  if (!secret) return reply('not_configured', 503);
  const signature = request.headers.get('x-line-signature');
  if (!signature) return reply('unauthorized', 401);
  const declaredLength = Number(request.headers.get('content-length'));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    return reply('payload_too_large', 413);
  }
  let rawBytes;
  try {
    rawBytes = new Uint8Array(await request.arrayBuffer());
  } catch {
    return reply('invalid_body', 400);
  }
  if (rawBytes.byteLength > MAX_BODY_BYTES) return reply('payload_too_large', 413);
  if (!(await verifyLineSignature(rawBytes, signature, secret))) {
    return reply('unauthorized', 401);
  }
  let payload;
  try {
    payload = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(rawBytes));
  } catch {
    return reply('invalid_json', 400);
  }
  if (!payload || typeof payload !== 'object' || Array.isArray(payload) ||
      !Array.isArray(payload.events)) {
    return reply('invalid_payload', 400);
  }
  // LINE Developers' Verify action sends events: []. No order mutation.
  if (payload.events.length === 0) return reply('verified', 200);

  // This scaffold MUST NOT process or acknowledge real LINE events yet.
  // A future implementation must verify tenant ownership, atomically
  // persist event IDs, and dispatch only to an authorized order transition.
  return reply('event_processing_not_enabled', 503);
}
