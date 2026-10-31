// Pure LINE account-linking protocol helpers. No production side effects.
// The caller MUST authenticate the current Zoky Merchant user, verify the
// current store membership, and atomically persist/consume this nonce server-side.

export function newLinkNonce() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

export function isLinkNonce(nonce) {
  return typeof nonce === 'string' && /^[0-9a-f]{64}$/.test(nonce);
}

export function buildAccountLinkRedirect(linkToken, nonce) {
  // LINE issues an opaque, single-use token. Never allow an external redirect.
  if (typeof linkToken !== 'string' || !/^[A-Za-z0-9_-]{16,255}$/.test(linkToken)) {
    throw new TypeError('invalid_link_token');
  }
  if (!isLinkNonce(nonce)) throw new TypeError('invalid_nonce');
  const url = new URL('https://access.line.me/dialog/bot/accountLink');
  url.searchParams.set('linkToken', linkToken);
  url.searchParams.set('nonce', nonce);
  return url.toString();
}

export function accountLinkEventInfo(event) {
  if (!event || typeof event !== 'object' || event.type !== 'accountLink') return null;
  if (event.link?.result === 'failed') return { result: 'failed' };
  if (event.link?.result !== 'ok') throw new TypeError('invalid_link_result');

  const lineUserId = event.source?.type === 'user' ? event.source.userId : null;
  // LINE user ID is not the public @... Bot basic ID.
  if (typeof lineUserId !== 'string' || !/^U[0-9a-f]{32}$/.test(lineUserId)) {
    throw new TypeError('invalid_line_user');
  }
  if (!isLinkNonce(event.link?.nonce)) throw new TypeError('invalid_nonce');
  return { result: 'ok', lineUserId, nonce: event.link.nonce };
}
