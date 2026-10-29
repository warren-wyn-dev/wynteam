// LINE API adapter, not wired to production. Never log Channel Access Tokens.
// A future event handler must call this only after verifying webhook signatures.
// The Merchant URL is a planned authenticated route; do not send links until it exists.
const LINE_USER = /^U[0-9a-f]{32}$/;

export async function issueLinkToken(lineUserId, channelAccessToken, http = fetch) {
  if (typeof lineUserId !== 'string' || !LINE_USER.test(lineUserId)) {
    throw new TypeError('invalid_line_user');
  }
  if (typeof channelAccessToken !== 'string' || !channelAccessToken.trim()) {
    throw new TypeError('channel_token_not_configured');
  }
  const response = await http(
    'https://api.line.me/v2/bot/user/' + encodeURIComponent(lineUserId) + '/linkToken',
    {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + channelAccessToken },
      signal: AbortSignal.timeout(7000),
    },
  );
  if (!response.ok) throw new Error('line_link_token_request_failed');
  let data;
  try { data = await response.json(); } catch { throw new Error('line_invalid_response'); }
  if (typeof data?.linkToken !== 'string' || !/^[A-Za-z0-9_-]{16,255}$/.test(data.linkToken)) {
    throw new Error('line_invalid_link_token');
  }
  return data.linkToken;
}

export function makeLinkPrompt(linkToken) {
  if (typeof linkToken !== 'string' || !/^[A-Za-z0-9_-]{16,255}$/.test(linkToken)) {
    throw new TypeError('invalid_link_token');
  }
  const url = new URL('https://merchant.wynos.online/merchant/line-connect');
  url.searchParams.set('linkToken', linkToken);
  return {
    type: 'template',
    altText: 'เชื่อม LINE กับร้านค้า Zoky Merchant',
    template: {
      type: 'buttons',
      text: 'เชื่อมบัญชี Zoky Merchant เพื่อรับแจ้งเตือนและจัดการออเดอร์ผ่าน LINE คุณสามารถยกเลิกการเชื่อมได้ทุกเมื่อ',
      actions: [{ type: 'uri', label: 'เชื่อมบัญชี', uri: url.toString() }],
    },
  };
}
