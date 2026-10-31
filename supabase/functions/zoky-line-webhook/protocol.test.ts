import {
  accountLinkEventInfo, buildAccountLinkRedirect, isLinkNonce, newLinkNonce,
} from './account-link.mjs';
import { makeOrderFlexCard, parseOrderPostback } from './order-card.mjs';

function check(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}
const id = '123e4567-e89b-42d3-a456-426614174000';
const lineUserId = 'U' + 'a'.repeat(32);
Deno.test('nonce is random, 256 bits, and constrained to accepted format', () => {
  const a = newLinkNonce(), b = newLinkNonce();
  check(isLinkNonce(a) && isLinkNonce(b) && a !== b, 'nonce not secure');
});
Deno.test('LINE redirect cannot be open-redirected', () => {
  const link = buildAccountLinkRedirect('validTokenFromLine12345', newLinkNonce());
  check(new URL(link).origin === 'https://access.line.me', 'redirect origin');
  let rejected = false;
  try { buildAccountLinkRedirect('https://evil.example/path', newLinkNonce()); } catch { rejected = true; }
  check(rejected, 'external url allowed');
});
Deno.test('accountLink event validates source and nonce', () => {
  const nonce = newLinkNonce();
  const info = accountLinkEventInfo({ type: 'accountLink', source: { type: 'user', userId: lineUserId }, link: { result: 'ok', nonce } });
  check(info?.result === 'ok' && info.nonce === nonce, 'invalid event parsing');
});
Deno.test('failure event does not require source userId', () => {
  check(accountLinkEventInfo({ type: 'accountLink', link: { result: 'failed' } })?.result === 'failed', 'failure rejected');
});
Deno.test('forged event with malformed user ID is rejected', () => {
  let rejected = false;
  try { accountLinkEventInfo({ type: 'accountLink', source: { type: 'user', userId: '@620wwvcd' }, link: { result: 'ok', nonce: newLinkNonce() } }); } catch { rejected = true; }
  check(rejected, 'bot ID accepted as user ID');
});
Deno.test('order Flex card includes only order/store/total, and action buttons', () => {
  const flex = makeOrderFlexCard({ orderId: id, orderNumber: 'ZK1024', storeName: 'ร้านทดสอบ', totalBaht: 200 });
  check(flex.contents.footer.contents.length === 2, 'missing actions');
  check(!JSON.stringify(flex).includes('shipping_address'), 'private data present');
  check(parseOrderPostback(flex.contents.footer.contents[0].action.data)?.action === 'accept', 'postback fails');
  check(parseOrderPostback(flex.contents.footer.contents[1].action.data)?.action === 'reject', 'postback fails');
});
Deno.test('invalid or ambiguous postbacks rejected', () => {
  check(parseOrderPostback('v=1&a=accept&oid=' + id + '&a=reject') === null, 'duplicate key accepted');
  check(parseOrderPostback('v=1&a=cancel&oid=' + id) === null, 'unknown action');
  check(parseOrderPostback('v=1&a=accept&oid=not-a-uuid') === null, 'invalid id');
});
