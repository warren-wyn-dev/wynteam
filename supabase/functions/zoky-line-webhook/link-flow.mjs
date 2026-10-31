// Staging-only orchestration for LINE Account Linking.
// NEVER call from a client: auth identity and DB mutations must be server-side.
import { newLinkNonce, buildAccountLinkRedirect, accountLinkEventInfo } from './account-link.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TTL_MS = 10 * 60 * 1000; // LINE's link token validity window.

export async function hashNonce(nonce) {
  if (typeof nonce !== 'string' || !/^[0-9a-f]{64}$/.test(nonce)) throw new TypeError('invalid_nonce');
  const input = new TextEncoder().encode(nonce);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', input));
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Called only after obtaining the signed-in Merchant user ID from a verified
 * Supabase session. The repository MUST recheck membership in the database,
 * and enforce uniqueness and expiry at storage level.
 */
export async function startMerchantLineLink({ userId, storeId, linkToken, repository, now = Date.now() }) {
  if (typeof userId !== 'string' || !UUID.test(userId) || typeof storeId !== 'string' || !UUID.test(storeId)) {
    throw new TypeError('invalid_identity');
  }
  if (!Number.isFinite(now) || now < 0) throw new TypeError('invalid_time');
  if (!repository || typeof repository.requireActiveMember !== 'function' ||
      typeof repository.savePendingLink !== 'function') throw new TypeError('invalid_repository');
  await repository.requireActiveMember({ userId, storeId });
  const nonce = newLinkNonce();
  // Validate the token and destination before saving a pending link.
  const redirectUrl = buildAccountLinkRedirect(linkToken, nonce);
  const nonceHash = await hashNonce(nonce);
  await repository.savePendingLink({
    nonceHash,
    userId,
    storeId,
    expiresAt: new Date(now + TTL_MS).toISOString(),
  });
  return { redirectUrl, expiresAt: new Date(now + TTL_MS).toISOString() };
}

/**
 * Only call on an event that passed LINE raw-body signature verification.
 * consumeAndAttach MUST be a single DB transaction that locks the pending
 * nonce, checks it is unused/unexpired, rechecks the current store membership,
 * and upserts one active LINE user connection atomically. It must not trust
 * client-supplied store/user claims or process a replay twice.
 */
export async function finishMerchantLineLink({ verifiedEvent, repository }) {
  if (!repository || typeof repository.consumeAndAttach !== 'function') throw new TypeError('invalid_repository');
  const link = accountLinkEventInfo(verifiedEvent);
  if (!link) return { result: 'ignored' };
  if (link.result === 'failed') return { result: 'failed' };
  const nonceHash = await hashNonce(link.nonce);
  const ok = await repository.consumeAndAttach({ nonceHash, lineUserId: link.lineUserId });
  return { result: ok === true ? 'linked' : 'rejected' };
}
