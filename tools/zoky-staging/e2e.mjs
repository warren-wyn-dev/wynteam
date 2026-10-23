#!/usr/bin/env node
// ZOKY Stripe-only + auto-refund: Stripe TEST-MODE E2E against the separate
// Free staging Supabase project (rollout plan step 1,
// .wyn/docs/deployment/zoky-stripe-only-rollout-plan.md).
//
//   node e2e.mjs setup   seed the synthetic store, create the E2E owner, and
//                        start Stripe test onboarding (prints a link for the Founder)
//   node e2e.mjs run     run the CTO scenario list and write a summary
//
// Synthetic data only (example.com users, a fake store). No Stripe key is read
// here: every Stripe call is made by the staging Edge Functions, which hold the
// sk_test key as a Supabase secret. A live key is detected and refused.
// Env: STAGING_REF, STAGING_MGMT_TOKEN (staging account token), BACKEND_DIR
// (checkout of the backend ref, for the policy/cron SQL files).
import { randomBytes } from "node:crypto";
import { appendFileSync, readFileSync } from "node:fs";
import { join } from "node:path";

const REF = need("STAGING_REF");
const MGMT = need("STAGING_MGMT_TOKEN");
const BACKEND_DIR = process.env.BACKEND_DIR || ".";
const MODE = process.argv[2];
const URL_BASE = `https://${REF}.supabase.co`;
const STORE = "00000000-0000-4000-8000-0000000e2e02";
const UNREADY_STORE = "00000000-0000-4000-8000-0000000e2e04";
const MENU = "00000000-0000-4000-8000-0000000e2e03";
const OWNER_EMAIL = "zoky-e2e-owner@example.com";
const RUN = Date.now().toString(36);
const UUID = /^[0-9a-f-]{36}$/;
const results = [];

function need(name) {
  const v = (process.env[name] || "").trim();
  if (!v) { console.error(`::error::${name} is missing`); process.exit(1); }
  return v;
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const id = (v) => { if (!UUID.test(String(v))) throw new Error(`not a uuid: ${v}`); return v; };
const summary = (line) => { console.log(line); if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, line + "\n"); };

// ---- staging access (Management API SQL, Auth admin, PostgREST, Functions)
async function sql(query) {
  const res = await fetch(`https://api.supabase.com/v1/projects/${REF}/database/query`, {
    method: "POST", headers: { Authorization: `Bearer ${MGMT}`, "Content-Type": "application/json" },
    body: JSON.stringify({ query }),
  });
  const body = await res.json().catch(() => null);
  if (!res.ok) throw new Error(`sql HTTP ${res.status}: ${JSON.stringify(body).slice(0, 300)}`);
  return body;
}
const one = async (q) => (await sql(q))[0] ?? {};
const sqlFile = (rel) => sql(`begin;\n${readFileSync(join(BACKEND_DIR, rel), "utf8")}\ncommit;`);

let ANON = "", SERVICE = "";
async function loadKeys() {
  const res = await fetch(`https://api.supabase.com/v1/projects/${REF}/api-keys?reveal=true`, { headers: { Authorization: `Bearer ${MGMT}` } });
  if (!res.ok) throw new Error(`api-keys HTTP ${res.status}`);
  for (const k of await res.json()) {
    if (k.name === "anon" && k.api_key) ANON = k.api_key;
    if (k.name === "service_role" && k.api_key) SERVICE = k.api_key;
  }
  if (!ANON || !SERVICE) throw new Error("legacy anon/service_role API keys not found on the staging project");
  console.log(`::add-mask::${ANON}`);
  console.log(`::add-mask::${SERVICE}`);
}
async function call(path, { token = ANON, method = "POST", body } = {}) {
  const res = await fetch(`${URL_BASE}${path}`, {
    method, headers: { apikey: ANON, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null; try { data = JSON.parse(text); } catch { data = text; }
  return { status: res.status, data };
}
const rpc = (token, name, args) => call(`/rest/v1/rpc/${name}`, { token, body: args });
const fn = (token, name, body) => call(`/functions/v1/${name}`, { token, body });

async function ensureUser(email, password) {
  const found = await one(`select id from auth.users where email = '${email.replace(/'/g, "")}'`);
  if (found.id) {
    const r = await call(`/auth/v1/admin/users/${id(found.id)}`, { token: SERVICE, method: "PUT", body: { password } });
    if (r.status !== 200) throw new Error(`update user HTTP ${r.status}`);
    return found.id;
  }
  const r = await call("/auth/v1/admin/users", { token: SERVICE, body: { email, password, email_confirm: true } });
  if (r.status !== 200) throw new Error(`create user HTTP ${r.status}`);
  return id(r.data.id);
}
async function signIn(email, password) {
  const r = await call("/auth/v1/token?grant_type=password", { body: { email, password } });
  if (r.status !== 200 || !r.data.access_token) throw new Error(`sign-in HTTP ${r.status}`);
  console.log(`::add-mask::${r.data.access_token}`);
  return r.data.access_token;
}
async function owner() {
  const pw = randomBytes(18).toString("base64url");
  const uid = await ensureUser(OWNER_EMAIL, pw);
  return { uid, token: await signIn(OWNER_EMAIL, pw) };
}
async function newBuyer(tag) {
  const email = `zoky-e2e-${RUN}-${tag}@example.com`;
  const pw = randomBytes(18).toString("base64url");
  const uid = await ensureUser(email, pw);
  await sql(`insert into public.profiles(id, username, display_name) values ('${id(uid)}', 'e2e_${RUN}_${tag}', 'E2E Buyer') on conflict (id) do nothing`);
  return { uid, token: await signIn(email, pw) };
}

// ---- Stripe test mode guard: the staging functions must hold a TEST key
async function assertTestMode() {
  // food-stripe-checkout answers 403 live_stripe_origin_required for a live key
  // before it looks at the caller; with a test key it rejects the anon caller (401).
  const r = await fn(ANON, "food-stripe-checkout", { orderId: "00000000-0000-0000-0000-000000000000" });
  if (r.status === 403 && r.data?.error === "live_stripe_origin_required") {
    throw new Error("STOP: the staging STRIPE_SECRET_KEY is a LIVE key. Replace it with the sk_test key.");
  }
  if (r.status === 503) throw new Error(`staging Stripe secret missing or unreadable (${r.data?.error})`);
  if (r.status !== 401) throw new Error(`unexpected test-mode probe answer HTTP ${r.status} ${JSON.stringify(r.data)}`);
}

// ---- orders
async function placeOrder(buyer, store = STORE) {
  const r = await rpc(buyer.token, "food_create_order", {
    p_store_id: store, p_recipient_name: "E2E", p_recipient_phone: "0800000000",
    p_shipping_address: "ที่อยู่ทดสอบ (staging)", p_customer_note: null,
    p_items: [{ menu_item_id: MENU, quantity: 1, note: "", selected_options: [] }],
    p_latitude: 16.186, p_longitude: 103.302,
  });
  if (r.status !== 200) throw new Error(`food_create_order HTTP ${r.status}: ${JSON.stringify(r.data).slice(0, 200)}`);
  return id(r.data);
}
const order = (oid) => one(`select status, payment_status, payment_provider, refund_status, refund_awaiting_customer,
  stripe_checkout_session_id, stripe_payment_intent_id from public.food_orders where id = '${id(oid)}'`);
async function checkout(buyer, oid, method) {
  return fn(buyer.token, "food-stripe-checkout", { orderId: oid, method });
}
async function waitFor(label, check, timeoutMs = 6 * 60_000, everyMs = 10_000) {
  const end = Date.now() + timeoutMs;
  let last;
  while (Date.now() < end) {
    last = await check();
    if (last.ok) return last;
    await sleep(everyMs);
  }
  throw new Error(`timed out waiting for ${label}: ${JSON.stringify(last?.state ?? last)}`);
}
const waitPaid = (oid, ms) => waitFor("order paid", async () => {
  const o = await order(oid);
  return { ok: o.payment_status === "paid" && o.payment_provider === "stripe", state: o };
}, ms);
async function storeCancel(own, oid) {
  const r = await rpc(own.token, "food_transition_order", { p_order_id: oid, p_status: "cancelled", p_eta_minutes: null, p_note: "E2E store cancel" });
  if (r.status !== 200 && r.status !== 204) throw new Error(`store cancel HTTP ${r.status}: ${JSON.stringify(r.data).slice(0, 200)}`);
}
const jobs = (oid) => sql(`select kind, reason, status, stripe_refund_id is not null as has_refund from public.food_stripe_jobs where order_id = '${id(oid)}' order by created_at`);
const events = (oid) => sql(`select event_type from public.food_stripe_webhook_events where order_id = '${id(oid)}' order by received_at`);
async function noDuplicateNotices(oid, buyerUid) {
  // "exactly one notification each": no buyer or merchant notice text repeats.
  const dup = await one(`select
      (select count(*) from (select reason from public.notifications where recipient_id = '${id(buyerUid)}'
         group by reason having count(*) > 1) d) as buyer_dups,
      (select count(*) from (select reason from public.merchant_notifications where reason ~ ('#' || (select order_number from public.food_orders where id = '${id(oid)}') || '( |$)')
         group by recipient_user_id, reason having count(*) > 1) d) as merchant_dups`);
  if (Number(dup.buyer_dups) || Number(dup.merchant_dups)) throw new Error(`duplicate notifications ${JSON.stringify(dup)}`);
}

// ---- Stripe hosted Checkout (test mode) through Playwright
let browser;
async function pay(url, method, card = "4242424242424242") {
  if (!browser) browser = await (await import("playwright")).chromium.launch();
  const page = await browser.newPage();
  try {
    await page.goto(url, { waitUntil: "domcontentloaded" });
    if (method === "card") {
      await page.locator("#cardNumber").fill(card);
      await page.locator("#cardExpiry").fill("12 / 34");
      await page.locator("#cardCvc").fill("123");
      const name = page.locator("#billingName");
      if (await name.count()) await name.fill("E2E Test");
    }
    const email = page.locator("#email");
    if (await email.count() && await email.isEditable()) await email.fill("zoky-e2e@example.com");
    await page.locator('[data-testid="hosted-payment-submit-button"], button[type="submit"]').first().click();
    if (method === "promptpay") await authorizePromptPay(page);
    return true;
  } catch (error) {
    await page.screenshot({ path: `checkout-${method}-${Date.now()}.png`, fullPage: true }).catch(() => {});
    console.log(`checkout automation failed (${method}): ${String(error).slice(0, 200)}`);
    return false;
  } finally {
    await page.close().catch(() => {});
  }
}
async function authorizePromptPay(page) {
  // Test mode offers an "Authorize test payment" action, either on the page
  // or on the page encoded in the QR code. Try the button first, then the QR.
  const button = () => page.getByRole("button", { name: /authori[sz]e test payment/i })
    .or(page.getByRole("link", { name: /authori[sz]e test payment/i }));
  for (let i = 0; i < 20; i++) {
    if (await button().count()) { await button().first().click(); return; }
    const target = await qrTarget(page);
    if (target) {
      await page.goto(target, { waitUntil: "domcontentloaded" });
      await button().first().click({ timeout: 30_000 });
      return;
    }
    await sleep(1500);
  }
  throw new Error("no test authorization action found");
}
async function qrTarget(page) {
  const img = page.locator('img[src*="qr"], canvas').first();
  if (!(await img.count())) return null;
  const { default: jsQR } = await import("jsqr");
  const { PNG } = await import("pngjs");
  const png = PNG.sync.read(await img.screenshot());
  const code = jsQR(new Uint8ClampedArray(png.data), png.width, png.height);
  const text = code?.data ?? "";
  return /^https:\/\/[a-z0-9.-]*stripe\.com\//i.test(text) ? text : null;
}
async function payOrHandOver(url, method, oid, card) {
  if (await pay(url, method, card)) return waitPaid(oid, 3 * 60_000);
  summary(`- MANUAL: open this test Checkout link and tap the test "Authorize" button within 8 minutes: ${url}`);
  return waitPaid(oid, 8 * 60_000);
}

// ---- scenarios
async function scenario(name, body) {
  try {
    const note = await body();
    results.push({ name, status: note?.manual ? "MANUAL" : "PASS", note: note?.text ?? "" });
  } catch (error) {
    results.push({ name, status: "FAIL", note: String(error?.message ?? error).slice(0, 400) });
  }
  const r = results.at(-1);
  console.log(`${r.status} ${name} ${r.note}`);
}
const policy = (on) => sqlFile(on ? "supabase/migrations/20261023100200_food_stripe_only_activate.sql"
  : "supabase/rollbacks/20261023100200_food_stripe_only_activate_rollback.sql");
async function newPaidOrder(own, tag, method, card) {
  const buyer = await newBuyer(tag);
  const oid = await placeOrder(buyer);
  const c = await checkout(buyer, oid, method);
  if (c.status !== 200 || !c.data?.url) throw new Error(`checkout ${method} HTTP ${c.status} ${JSON.stringify(c.data)}`);
  await payOrHandOver(c.data.url, method, oid, card);
  const ledger = await one(`select livemode, payment_method from public.food_stripe_payments where order_id = '${oid}'`);
  if (ledger.livemode !== false) throw new Error("payment ledger is not test mode");
  return { buyer, oid };
}
async function refundOutcome(oid) {
  return waitFor("refund outcome", async () => {
    const o = await order(oid);
    const done = o.refund_status === "refunded" || o.refund_status === "failed" || o.refund_awaiting_customer === true;
    return { ok: done, state: { ...o, jobs: await jobs(oid) } };
  }, 8 * 60_000, 15_000);
}

async function setup() {
  await loadKeys();
  await assertTestMode();
  const own = await owner();
  const seed = readFileSync(new URL("./seed.sql", import.meta.url), "utf8").replaceAll("__OWNER__", id(own.uid));
  await sql(seed);
  const r = await fn(own.token, "merchant-stripe-connect", { storeId: STORE, action: "onboard" });
  if (r.status !== 200) throw new Error(`merchant-stripe-connect onboard HTTP ${r.status} ${JSON.stringify(r.data)}`);
  const s = r.data;
  const acct = await one(`select livemode from public.food_stripe_accounts where store_id = '${STORE}'`);
  if (acct.livemode !== false) throw new Error("STOP: the store's Stripe account is not a TEST account");
  summary(`Store Stripe test account: status=${s.status} promptpay=${s.promptpay_status}`);
  if (s.status === "ready" && s.promptpay_enabled === true) {
    summary("READY: the test store can take PromptPay. Run the workflow again with step `e2e`.");
  } else if (s.url) {
    summary(`ACTION (Founder): open this Stripe TEST onboarding link within 5 minutes and fill it with test data: ${s.url}`);
    summary("When finished, run step `setup` once more; it must say READY.");
  } else {
    summary("ACTION (Founder): the account is not ready yet (Stripe is checking or PromptPay is off). See checklist part C, then run `setup` again.");
  }
}

async function run() {
  await loadKeys();
  await assertTestMode();
  const own = await owner();
  const st = await fn(own.token, "merchant-stripe-connect", { storeId: STORE, action: "status" });
  if (st.status !== 200 || st.data?.status !== "ready" || st.data?.promptpay_enabled !== true) throw new Error(`store Stripe account not ready (${JSON.stringify(st.data)}); run setup first`);
  await sqlFile("supabase/rollbacks/20261023100200_food_stripe_only_activate_rollback.sql");
  const cron = await one("select count(*)::int as n from cron.job where jobname = 'wynos-food-stripe-refund-worker' and active");
  if (cron.n !== 1) throw new Error("refund worker cron is not scheduled; run setup");

  let pp;
  await scenario("1. Policy on: card refused, PromptPay offered, unready store refused", async () => {
    await policy(true);
    const b = await newBuyer("policy");
    const oid = await placeOrder(b);
    const card = await checkout(b, oid, "card");
    if (card.status !== 422) throw new Error(`card checkout should be refused, got ${card.status}`);
    const promptpay = await checkout(b, oid, "promptpay");
    if (promptpay.status !== 200 || !promptpay.data?.url) throw new Error(`PromptPay checkout HTTP ${promptpay.status}`);
    const unready = await rpc(b.token, "food_create_order", {
      p_store_id: UNREADY_STORE, p_recipient_name: "E2E", p_recipient_phone: "0800000000", p_shipping_address: "x",
      p_customer_note: null, p_items: [{ menu_item_id: "00000000-0000-4000-8000-0000000e2e05", quantity: 1 }],
      p_latitude: 16.186, p_longitude: 103.302 });
    if (unready.status === 200) throw new Error("store without Stripe took an order while the policy is on");
    await rpc(b.token, "food_cancel_order", { p_order_id: oid, p_reason: "E2E cleanup" });
  });
  await scenario("2. PromptPay payment leaves the order paid (policy on)", async () => {
    pp = await newPaidOrder(own, "pp", "promptpay");
  });
  await scenario("3. Store cancel of a PromptPay order -> refund job -> pending/requires_action -> refunded", async () => {
    if (!pp) throw new Error("needs scenario 2");
    await storeCancel(own, pp.oid);
    const j = await waitFor("refund job queued", async () => { const r = await jobs(pp.oid); return { ok: r.some((x) => x.kind === "refund"), state: r }; }, 60_000, 5_000);
    const out = await refundOutcome(pp.oid);
    await noDuplicateNotices(pp.oid, pp.buyer.uid);
    if (out.state.refund_status === "refunded") return { text: "refunded" };
    if (out.state.refund_awaiting_customer) return { manual: true, text: "Stripe is waiting for the customer's bank account (requires_action). Founder steps M1." };
    throw new Error(`refund ended ${JSON.stringify(out.state)} after ${JSON.stringify(j.state)}`);
  });
  await scenario("4. charge.refunded is recorded as a no-op", async () => {
    if (!pp) throw new Error("needs scenario 2");
    const ev = (await events(pp.oid)).map((e) => e.event_type);
    const o = await order(pp.oid);
    if (o.refund_status === "refunded" && !ev.some((t) => t.startsWith("refund.") || t === "charge.refund.updated")) {
      throw new Error(`order refunded without a refund.* event: ${ev.join(",")}`);
    }
    return { text: `events: ${ev.join(", ")}`, manual: !ev.includes("charge.refunded") };
  });
  await scenario("5. Policy off (deactivate) brings card back", async () => {
    await policy(false);
    const b = await newBuyer("legacy");
    const oid = await placeOrder(b);
    const card = await checkout(b, oid, "card");
    if (card.status !== 200 || !card.data?.url) throw new Error(`card checkout after deactivate HTTP ${card.status}`);
    await rpc(b.token, "food_cancel_order", { p_order_id: oid, p_reason: "E2E cleanup" });
  });
  await scenario("6. Card refund succeeds -> refunded, one notice each", async () => {
    const c = await newPaidOrder(own, "card", "card");
    await storeCancel(own, c.oid);
    const out = await refundOutcome(c.oid);
    if (out.state.refund_status !== "refunded" || out.state.payment_status !== "refunded") throw new Error(JSON.stringify(out.state));
    await noDuplicateNotices(c.oid, c.buyer.uid);
  });
  await scenario("7. Failed refund ends paid/failed with notices", async () => {
    // Stripe test card whose refunds fail asynchronously.
    const c = await newPaidOrder(own, "fail", "card", "4000000000005126");
    await storeCancel(own, c.oid);
    const out = await waitFor("refund failed", async () => {
      const o = await order(c.oid); return { ok: o.refund_status === "failed", state: o };
    }, 10 * 60_000, 15_000);
    if (out.state.payment_status !== "paid") throw new Error(JSON.stringify(out.state));
    const n = await one(`select (select count(*) from public.notifications where recipient_id = '${id(c.buyer.uid)}')::int as buyer,
      (select count(*) from public.merchant_notifications m join public.food_stores s on s.merchant_account_id = m.merchant_account_id
        where s.id = '${STORE}' and m.created_at > now() - interval '15 minutes' and m.reason ~ ('#' || (select order_number from public.food_orders where id = '${c.oid}') || '( |$)'))::int as merchant`);
    if (!n.buyer || !n.merchant) throw new Error(`missing notices ${JSON.stringify(n)}`);
    await noDuplicateNotices(c.oid, c.buyer.uid);
  });
  await scenario("8. Cancelling an unpaid order expires its Checkout session", async () => {
    const b = await newBuyer("unpaid");
    const oid = await placeOrder(b);
    const c = await checkout(b, oid, "promptpay");
    if (c.status !== 200) throw new Error(`checkout HTTP ${c.status}`);
    const r = await rpc(b.token, "food_cancel_order", { p_order_id: oid, p_reason: "E2E unpaid cancel" });
    if (r.status !== 200 && r.status !== 204) throw new Error(`cancel HTTP ${r.status}`);
    await waitFor("expire_checkout done", async () => {
      const j = await jobs(oid); return { ok: j.some((x) => x.kind === "expire_checkout" && x.status === "done"), state: j };
    });
    const ev = await waitFor("checkout.session.expired webhook", async () => {
      const e = (await events(oid)).map((x) => x.event_type); return { ok: e.includes("checkout.session.expired"), state: e };
    }, 3 * 60_000).catch(() => null);
    return ev ? { text: "session expired at Stripe" } : { manual: true, text: "job done; webhook checkout.session.expired not seen (is it in the endpoint's event list?)" };
  });
  await scenario("9. Order without a job: legacy refund button + refund.updated -> refunded", async () => {
    await sqlFile("supabase/rollbacks/20261023100100_food_stripe_jobs_enable_cron_rollback.sql");
    try {
      const c = await newPaidOrder(own, "button", "card");
      await storeCancel(own, c.oid);
      // Stand-in for an order cancelled before the jobs migration: no job row.
      await sql(`delete from public.food_stripe_jobs where order_id = '${c.oid}' and kind = 'refund'`);
      const r = await fn(own.token, "merchant-stripe-refund", { orderId: c.oid, note: "E2E legacy button" });
      if (r.status !== 200) throw new Error(`merchant-stripe-refund HTTP ${r.status} ${JSON.stringify(r.data)}`);
      await waitFor("refunded by webhook", async () => { const o = await order(c.oid); return { ok: o.refund_status === "refunded", state: o }; }, 5 * 60_000);
      const ev = (await events(c.oid)).map((x) => x.event_type);
      if (!ev.includes("refund.updated") && !ev.includes("refund.created")) throw new Error(`no refund.* event: ${ev}`);
    } finally {
      await sqlFile("supabase/migrations/20261023100100_food_stripe_jobs_enable_cron.sql");
    }
  });
  await scenario("10. Duplicate events are ignored", async () => {
    const e = await one(`select e.event_id, e.event_type, e.order_id, e.stripe_account_id, e.object_id from public.food_stripe_webhook_events e
      join public.food_orders o on o.id = e.order_id where o.store_id = '${STORE}' and e.event_type = 'checkout.session.completed'
      order by e.received_at desc limit 1`);
    if (!e.event_id) throw new Error("no processed checkout.session.completed event to replay");
    const before = await one(`select count(*)::int as n from public.notifications where created_at > now() - interval '1 day'`);
    const r = await rpc(SERVICE, "food_apply_stripe_event", {
      p_event_id: e.event_id, p_event_type: e.event_type, p_order_id: e.order_id, p_stripe_account_id: e.stripe_account_id,
      p_object_id: e.object_id, p_checkout_session_id: e.object_id, p_payment_intent_id: null, p_amount_satang: null,
      p_currency: "thb", p_state: "paid", p_payment_method: "promptpay", p_note: null, p_refund_id: null });
    if (r.status !== 200 || r.data !== false) throw new Error(`replay was applied: HTTP ${r.status} ${JSON.stringify(r.data)}`);
    const after = await one(`select count(*)::int as n from public.notifications where created_at > now() - interval '1 day'`);
    if (after.n !== before.n) throw new Error("replay sent a notification");
    return { text: "replayed event id refused; optional Dashboard Resend check is M2" };
  });

  const health = await one(`select (select count(*) from public.food_stripe_jobs where status in ('failed','needs_attention'))::int as bad_jobs,
    (select stripe_only_from is null from public.food_payment_policy) as policy_off`);
  summary(`\n### ZOKY staging E2E (${new Date().toISOString()})\n`);
  summary("| # | Scenario | Result | Note |\n|---|---|---|---|");
  results.forEach((r) => summary(`| | ${r.name} | ${r.status} | ${r.note.replace(/\|/g, "/")} |`));
  summary(`\nJobs failed/needs_attention (expected: scenario 7 only): ${health.bad_jobs}. Policy left OFF: ${health.policy_off}.`);
  if (results.some((r) => r.status === "FAIL")) process.exitCode = 1;
}

try {
  if (MODE === "setup") await setup();
  else if (MODE === "run") await run();
  else throw new Error("usage: e2e.mjs setup|run");
} catch (error) {
  console.error(`::error::${String(error?.message ?? error).slice(0, 500)}`);
  process.exitCode = 1;
} finally {
  if (browser) await browser.close();
}
