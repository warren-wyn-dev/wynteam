import { issueLinkToken, makeLinkPrompt } from './line-api.mjs';
const lineId = 'U' + 'a'.repeat(32);
function check(value: boolean, name: string) { if (!value) throw new Error(name); }

Deno.test('link token request targets LINE API, uses only server token', async () => {
  let called = false;
  const issue = await issueLinkToken(lineId, 'test-server-secret', async (url, opts) => {
    called = true;
    check(url === 'https://api.line.me/v2/bot/user/' + lineId + '/linkToken', 'wrong LINE API URL');
    check(opts.headers.Authorization === 'Bearer test-server-secret', 'auth not sent privately');
    return { ok: true, json: async () => ({ linkToken: 'ValidLineLinkToken12345678' }) };
  });
  check(called && issue === 'ValidLineLinkToken12345678', 'link not issued');
});
Deno.test('invalid LINE user ID cannot request token', async () => {
  let rejected = false;
  try { await issueLinkToken('@620wwvcd', 'token', async () => { throw Error('should not call'); }); }
  catch { rejected = true; }
  check(rejected, 'invalid ID allowed');
});
Deno.test('LINE request failures do not expose secrets', async () => {
  let msg = '';
  try { await issueLinkToken(lineId, 'secret-token', async () => ({ ok: false })); }
  catch (e) { msg = String(e); }
  check(msg.includes('line_link_token_request_failed') && !msg.includes('secret-token'), 'secret leaked');
});
Deno.test('link prompt uses fixed Merchant HTTPS origin, never includes bearer secret', () => {
  const msg = makeLinkPrompt('ValidLineLinkToken12345678');
  const url = new URL(msg.template.actions[0].uri);
  check(url.origin === 'https://merchant.wynos.online', 'bad origin');
  check(url.searchParams.get('linkToken') === 'ValidLineLinkToken12345678', 'missing token');
});
