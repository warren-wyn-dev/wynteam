// Transport boundaries for Zoky Merchant LINE. No customer PII is sent.
// Every call to this module is made only after raw HMAC signature verification.
import { accountLinkEventInfo } from './account-link.mjs';
import { hashNonce } from './link-flow.mjs';
import { parseOrderPostback } from './order-card.mjs';
import { issueLinkToken, makeLinkPrompt } from './line-api.mjs';

const LINE_USER_ID = /^U[0-9a-f]{32}$/;
const REPLY_TOKEN = /^[A-Za-z0-9_\-]{8,255}$/;

async function replyToLine(replyToken, message, channelToken, http) {
  if (!REPLY_TOKEN.test(replyToken) || !channelToken) throw new Error('invalid_line_reply');
  const response = await http('https://api.line.me/v2/bot/message/reply', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer ' + channelToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ replyToken, messages: [message] }),
    signal: AbortSignal.timeout(7500),
  });
  if (!response.ok) throw new Error('line_reply_failed');
}
function userId(event) {
  const value = event?.source?.type === 'user' ? event.source.userId : null;
  return typeof value === 'string' && LINE_USER_ID.test(value) ? value : null;
}
function say(text) { return { type: 'text', text }; }

// repo is a privileged server-side adapter. The DB RPC must check current
// merchant membership, store identity, order state and payment state inside a
// single locked transaction (NO direct order update from this module).
export function createLineEventProcessor({ repository, channelToken, http = fetch }) {
  if (!repository || typeof repository.completeLink !== 'function' ||
      typeof repository.transitionOrder !== 'function') {
    throw new TypeError('invalid_line_repository');
  }
  return async function processVerifiedEvent(event) {
    if (!event || typeof event !== 'object') throw new TypeError('invalid_event');

    const sender = userId(event);
    if (event.type === 'message' && sender && event.message?.type === 'text' &&
      ['เชื่อมบัญชี', 'เชื่อมต่อบัญชี', 'เชื่อม LINE'].includes(String(event.message.text || '').trim())) {
      if (typeof event.replyToken !== 'string' || !REPLY_TOKEN.test(event.replyToken)) throw new Error('missing_reply');
      const token = await issueLinkToken(sender, channelToken, http);
      // The URL points at a page that requires an authenticated Merchant login.
      await replyToLine(event.replyToken, makeLinkPrompt(token), channelToken, http);
      return;
    }

    if (event.type === 'accountLink') {
      const result = accountLinkEventInfo(event);
      if (result?.result !== 'ok') return;
      const success = await repository.completeLink({
        nonceHash: await hashNonce(result.nonce),
        lineUserId: result.lineUserId,
      });
      // Account linking can be retried by LINE. The atomic DB nonce consume
      // must accept at most one webhook, and a replay is a harmless no-op.
      if (success !== true && success !== false) throw new Error('invalid_db_link_result');
      return;
    }

    if (event.type === 'postback' && sender) {
      const command = parseOrderPostback(event.postback?.data);
      if (!command) return;
      const response = await repository.transitionOrder({
        lineUserId: sender, action: command.action, orderId: command.orderId,
      });
      if (typeof event.replyToken === 'string' && REPLY_TOKEN.test(event.replyToken)) {
        const message = response?.ok === true
          ? say(command.action === 'accept' ? 'รับออเดอร์สำเร็จแล้ว' : 'ปฏิเสธออเดอร์แล้ว')
          : say('ดำเนินการไม่ได้ ออเดอร์อาจเปลี่ยนสถานะแล้วหรือคุณไม่มีสิทธิ์จัดการ');
        await replyToLine(event.replyToken, message, channelToken, http);
      }
      return;
    }
  };
}
