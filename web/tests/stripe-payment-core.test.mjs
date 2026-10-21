import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const root = new URL("..", import.meta.url).pathname;
const read = (path) => readFileSync(join(root, path), "utf8");

const coreMigration = read("../supabase/migrations_wynos_stripe_payment_core_v1.sql");
const v2Migration = read("../supabase/migrations_wynos_stripe_connect_v2_embedded.sql");
const checkout = read("../supabase/functions/food-stripe-checkout/index.ts");
const checkoutLib = read("../supabase/functions/food-stripe-checkout/_lib.ts");
const connect = read("../supabase/functions/merchant-stripe-connect/index.ts");
const refund = read("../supabase/functions/merchant-stripe-refund/index.ts");
const cancelStripe = read("../supabase/functions/food-stripe-cancel/index.ts");
const webhook = read("../supabase/functions/stripe-webhook/index.ts");
const foodUi = read("components/food/wynos-food-developer-app.tsx");
const merchantUi = read("components/merchant/wynos-merchant-app.tsx");
const paymentUi = read("components/merchant/merchant-payment-setup.tsx");
const financeUi = read("components/merchant/merchant-finance.tsx");
const refundUi = read("components/merchant/merchant-core-panels.tsx");
const merchantCore = read("lib/merchant-core.ts");

test("Stripe secrets and raw gateway data stay server-side", () => {
  assert.match(coreMigration, /alter table public\.food_stripe_accounts enable row level security/i);
  assert.match(coreMigration, /revoke all on table public\.food_stripe_accounts from public, anon, authenticated/i);
  assert.match(v2Migration, /revoke all on table public\.food_stripe_payouts from public, anon, authenticated/i);
  assert.match(v2Migration, /revoke all on table public\.food_stripe_account_creation_locks from public, anon, authenticated/i);
  assert.match(v2Migration, /revoke all on table public\.food_stripe_account_mapping_archive from public, anon, authenticated/i);
  assert.match(v2Migration, /food_archive_stripe_account_mapping/);
  assert.match(v2Migration, /grant execute on function public\.food_record_stripe_payout_event[\s\S]*to service_role/i);
  assert.match(v2Migration, /food_get_stripe_webhook_secret/);
  assert.match(v2Migration, /food_set_stripe_webhook_secret/);
  assert.match(v2Migration, /vault\.decrypted_secrets/);
  assert.match(v2Migration, /grant execute on function public\.food_get_stripe_webhook_secret\(text\)[\s\S]*to service_role/i);
  assert.match(v2Migration, /grant execute on function public\.food_set_stripe_webhook_secret\(text,text\)[\s\S]*to service_role/i);
  for (const clientFile of [foodUi, merchantUi, paymentUi, financeUi, refundUi, merchantCore]) {
    assert.doesNotMatch(clientFile, /STRIPE_SECRET_KEY|STRIPE_WEBHOOK_SECRET|STRIPE_V2_WEBHOOK_SECRET|sk_live_|sk_test_/);
  }
});

test("Checkout remains a direct connected-account charge with server-calculated amount", () => {
  assert.match(checkout, /"Stripe-Account": account/);
  assert.match(checkout, /headers\["Idempotency-Key"\]\s*=\s*idempotencyKey/);
  assert.match(checkout, /Math\.round\(Number\(order\.total\) \* 100\)/);
  assert.doesNotMatch(checkout, /payment_method_types/);
  assert.match(checkout, /connected account's active payment-method/);
  assert.match(checkout, /livemode: stripeLiveMode/);
  // ZOKY-135: live mode only for the exact Food web origins (ZOKY + legacy
  // food.wynos.online); return URLs never use an arbitrary request origin.
  assert.match(checkout, /if \(stripeLiveMode && !isFoodWebOrigin\(requestOrigin\)\)/);
  assert.match(checkout, /const returnBaseUrl = foodReturnBaseUrl\(\s*requestOrigin, stripeLiveMode, Deno\.env\.get\("STRIPE_TEST_RETURN_ORIGINS"\)/);
  assert.match(checkoutLib, /FOOD_WEB_ORIGINS: ReadonlySet<string> = new Set\(\[\s*FOOD_WEB_ORIGIN,\s*"https:\/\/food\.wynos\.online",\s*\]\)/);
  assert.match(checkoutLib, /FOOD_WEB_ORIGIN = "https:\/\/zoky\.wynos\.online"/);
  assert.match(cancelStripe, /if \(stripeLiveMode && !isFoodWebOrigin\(req\.headers\.get\("origin"\)\)\)/);
  assert.doesNotMatch(checkout, /transfer_data|destination/);
  // GP v1 (Founder, 2026-10-11): WYNOS GP is an application fee on the direct
  // charge, only when the database quote says GP > 0 (every store is 0% until
  // the super admin sets a rate), never computed in the function itself.
  assert.match(checkout, /if \(feeSatang > 0\) \{\s*params\.set\("payment_intent_data\[application_fee_amount\]", String\(feeSatang\)\)/);
  assert.match(checkout, /admin\.rpc\("food_order_gp_quote"/);
  assert.match(checkout, /applicationFeeSatang\(quote, amountSatang\)/);
});

test("new merchants use Accounts v2 and legacy v1 is retrieval-only compatibility", () => {
  assert.match(connect, /https:\/\/api\.stripe\.com\/v2\/core\/accounts/);
  assert.match(connect, /"Stripe-Version": STRIPE_V2_VERSION/);
  assert.match(connect, /identity: \{ country: "th" \}/);
  assert.match(connect, /card_payments: \{ requested: true \}/);
  assert.doesNotMatch(connect, /promptpay_payments: \{ requested: true \}/);
  assert.match(connect, /\/v1\/payment_method_configurations\?active=true&limit=100/);
  assert.match(connect, /promptpay\[display_preference\]\[preference\]/);
  assert.match(connect, /wynos-promptpay-/);
  assert.match(connect, /fees_collector: "stripe"/);
  assert.match(connect, /losses_collector: "stripe"/);
  assert.match(connect, /dashboard: "none"/);
  assert.match(connect, /wynos-connect-v2-/);
  assert.match(connect, /v1_account_instead_of_v2_account/);
  assert.match(connect, /return \{ account, api: "v1" as const \}/);
  assert.match(connect, /stripe_environment_mismatch/);
  assert.match(connect, /livemode: stripeLiveMode/);
  assert.match(connect, /https:\/\/merchant\.wynos\.online/);
  assert.doesNotMatch(connect, /https:\/\/api\.stripe\.com\/v1\/accounts["'`]/);
  assert.match(connect, /\/v1\/accounts\/\$\{encodeURIComponent\(accountId\)\}/);
});

test("double tap and retry protection uses a store lock, unique mapping and Stripe idempotency", () => {
  assert.match(v2Migration, /food_stripe_account_creation_locks/);
  assert.match(v2Migration, /store_id uuid primary key references public\.food_stores/);
  assert.match(v2Migration, /food_claim_stripe_account_creation/);
  assert.match(connect, /food_claim_stripe_account_creation/);
  assert.match(connect, /Idempotency-Key/);
  assert.match(connect, /wynos-connect-v2-/);
  assert.match(coreMigration, /store_id uuid primary key references public\.food_stores/);
  assert.match(coreMigration, /stripe_account_id text not null unique/);
  assert.match(v2Migration, /add column if not exists livemode boolean not null default false/);
  assert.match(v2Migration, /food_stripe_account_mapping_archive/);
});

test("embedded onboarding is primary and hosted Account Links are fallback", () => {
  assert.match(connect, /https:\/\/api\.stripe\.com\/v1\/account_sessions/);
  assert.match(connect, /components\[account_onboarding\]\[enabled\]/);
  assert.match(connect, /components\[account_management\]\[enabled\]/);
  assert.match(connect, /components\[notification_banner\]\[enabled\]/);
  assert.match(connect, /external_account_collection/);
  assert.match(connect, /surface: "embedded"/);
  assert.match(connect, /https:\/\/api\.stripe\.com\/v2\/core\/account_links/);
  assert.match(connect, /collection_options: \{ fields: "currently_due" \}/);
  assert.match(paymentUi, /https:\/\/connect-js\.stripe\.com\/v1\.0\/connect\.js/);
  assert.match(paymentUi, /StripeConnect\.init/);
  assert.match(paymentUi, /setOnExit/);
  assert.match(paymentUi, /locale: "th-TH"/);
  assert.doesNotMatch(connect, /disable_stripe_user_authentication/);
});

test("Merchant payment UX is WYNOS-first and return URLs refresh automatically", () => {
  assert.match(merchantUi, /การรับชำระเงิน/);
  assert.match(paymentUi, /เปิดรับชำระเงิน/);
  assert.match(paymentUi, /พร้อมรับเงิน/);
  assert.match(paymentUi, /ต้องยืนยันข้อมูล/);
  assert.match(paymentUi, /กำลังตั้งค่า/);
  assert.match(paymentUi, /มีปัญหา กรุณาดำเนินการต่อ/);
  assert.match(paymentUi, /searchParams\.get\("payments"\)/);
  assert.match(paymentUi, /stripeReturn === "refresh"/);
  assert.match(connect, /payments=refresh/);
  assert.match(connect, /payments=return/);
  assert.doesNotMatch(merchantUi, /เชื่อม Stripe|ตรวจสถานะ|ดำเนินการต่อใน Stripe/);
  assert.doesNotMatch(paymentUi, /Accounts v2|capabilit|webhook|connected account/i);
});

test("readiness requires card, payouts, requirements, bank and a verified payout schedule", () => {
  assert.match(connect, /const automaticPayouts = settings !== "manual" && settings !== "unknown"/);
  assert.match(connect, /charges && payoutsEnabled && !core\.needsInfo && bank\.ready && payoutReady/);
  assert.match(connect, /settings === "manual" && managedPayouts/);
  assert.match(connect, /food_store_managed_payouts/);
  assert.match(connect, /requirements_due_count/);
  assert.match(connect, /bank_last4/);
  assert.match(connect, /stripe_payments_enabled: state\.status === "ready"/);
  assert.match(v2Migration, /bank_last4/);
  assert.doesNotMatch(v2Migration, /bank_account_number/);
});

test("payout schedule uses Balance Settings and only reports actual interval", () => {
  assert.match(connect, /https:\/\/api\.stripe\.com\/v1\/balance_settings/);
  assert.match(connect, /payments\[payouts\]\[schedule\]\[interval\]/);
  assert.match(connect, /"daily"/);
  assert.match(paymentUi, /payout_interval === "daily"/);
  assert.match(paymentUi, /อัตโนมัติ · ทุกวัน/);
  assert.match(paymentUi, /เงินจะถูกโอนตามรอบที่ผู้ให้บริการกำหนด/);
});

test("Webhook verifies signatures, scopes Accounts v2 thin events and records payouts idempotently", () => {
  assert.match(webhook, /verifyAgainstConfiguredSecrets/);
  assert.match(webhook, /STRIPE_V2_WEBHOOK_SECRET/);
  assert.match(webhook, /food_get_stripe_webhook_secret/);
  assert.match(webhook, /configuredSecrets/);
  assert.match(webhook, /V2_ACCOUNT_SYNC_EVENTS/);
  assert.match(webhook, /v2\.core\.account\[configuration\.merchant\]\.capability_status_updated/);
  assert.match(webhook, /v2\.core\.account\[requirements\]\.updated/);
  assert.match(webhook, /related\?\.type\) !== "v2\.core\.account"/);
  assert.match(webhook, /payout\.paid/);
  assert.match(webhook, /payout\.failed/);
  assert.match(webhook, /food_record_stripe_payout_event/);
  assert.match(v2Migration, /on conflict \(event_id\) do nothing/i);
  assert.match(coreMigration, /amount mismatch/);
  assert.match(coreMigration, /stripe account mismatch/);
});

test("Paid remains webhook-authoritative and browser redirects cannot mark orders paid", () => {
  assert.match(webhook, /checkout\.session\.completed/);
  assert.match(webhook, /checkout\.session\.async_payment_succeeded/);
  assert.match(webhook, /checkout\.session\.async_payment_failed/);
  assert.match(webhook, /payment_intent\.payment_failed/);
  assert.match(webhook, /state = "paid"/);
  assert.doesNotMatch(foodUi, /stripe=success[\s\S]{0,400}payment_status\s*[:=]\s*["']paid/);
});

test("Manual slip fallback expires open Stripe Checkout first", () => {
  assert.match(cancelStripe, /checkout\/sessions\/\$\{encodeURIComponent\(sessionId\)\}\/expire/);
  assert.match(cancelStripe, /payment_status === "paid"/);
  assert.match(cancelStripe, /stripe_checkout_session_id: null/);
  assert.match(cancelStripe, /food_stripe_payments/);
  assert.match(cancelStripe, /stripe_account_id,livemode/);
  assert.match(cancelStripe, /stripe_environment_mismatch/);
  assert.match(coreMigration, /cancel stripe checkout before submitting slip/);
  assert.match(foodUi, /prepareFoodManualPayment/);
});

test("Refunds use the gateway and never surface raw gateway messages", () => {
  assert.match(refundUi, /requestStripeRefund/);
  assert.match(refund, /payment_provider !== "stripe"/);
  assert.match(refund, /payment_intent/);
  assert.match(refund, /food_stripe_payments/);
  assert.match(refund, /stripe_account_id,livemode/);
  assert.match(refund, /stripe_environment_mismatch/);
  assert.match(refund, /request_id/);
  assert.match(refund, /คืนเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง/);
  assert.doesNotMatch(refund, /message: error instanceof Error \? error\.message/);
});

test("Merchant Finance uses server-sanitized balance/payout data and only bank last4", () => {
  assert.match(financeUi, /fetchMerchantStripeFinance/);
  assert.match(financeUi, /ยอดขายวันนี้/);
  assert.match(financeUi, /กำลังดำเนินการ/);
  assert.match(financeUi, /พร้อมโอน/);
  assert.match(financeUi, /โอนเข้าธนาคารแล้ววันนี้/);
  assert.match(financeUi, /คืนเงิน/);
  assert.match(financeUi, /bank_last4/);
  assert.match(financeUi, /พร้อมรับเงิน/);
  assert.doesNotMatch(financeUi, /stripe_account_id|bank_account_number/);
});

test("Merchant errors are localized and raw gateway errors stay out of client UI", () => {
  assert.match(merchantCore, /context instanceof Response/);
  assert.match(merchantCore, /\/\[ก-๙\]\//);
  assert.match(merchantCore, /อัปเดตสถานะการรับเงินไม่สำเร็จ/);
  assert.match(merchantCore, /เปิดหน้าตั้งค่ารับเงินไม่สำเร็จ/);
  assert.doesNotMatch(merchantCore, /return raw\.message/);
});

const compileEdge = (input) => ts.transpileModule(input, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const returnLibrary = { exports: {} };
runInNewContext(compileEdge(checkoutLib), { module: returnLibrary, exports: returnLibrary.exports, URL });

test("test return origins require an explicit exact HTTPS origin and known test mode", () => {
  const preview = "https://zoky-qa.example.test";
  const otherPreview = "https://merchant-qa.example.test";
  const config = ` ${otherPreview}, ${preview} `;
  const { foodReturnBaseUrl, merchantReturnBaseUrl } = returnLibrary.exports;
  assert.equal(foodReturnBaseUrl(preview, false, config), `${preview}/food`);
  assert.equal(merchantReturnBaseUrl(otherPreview, false, config), `${otherPreview}/merchant`);
  for (const mode of [true, null, undefined]) {
    assert.equal(foodReturnBaseUrl(preview, mode, config), "https://zoky.wynos.online");
    assert.equal(merchantReturnBaseUrl(preview, mode, config), "https://merchant.wynos.online");
  }
  for (const configValue of [undefined, null, "", "*", "https://*.example.test", otherPreview]) {
    assert.equal(foodReturnBaseUrl(preview, false, configValue), "https://zoky.wynos.online");
    assert.equal(merchantReturnBaseUrl(preview, false, configValue), "https://merchant.wynos.online");
  }
  assert.equal(foodReturnBaseUrl("https://food.wynos.online", true, config), "https://food.wynos.online");
  assert.equal(foodReturnBaseUrl("https://zoky.wynos.online", false, "https://zoky.wynos.online"), "https://zoky.wynos.online");
  assert.equal(merchantReturnBaseUrl("https://merchant.wynos.online", false, "https://merchant.wynos.online"), "https://merchant.wynos.online");
});

test("malformed, normalized and lookalike URLs cannot become Stripe return targets", () => {
  const preview = "https://zoky-qa.example.test";
  const { foodReturnBaseUrl, merchantReturnBaseUrl } = returnLibrary.exports;
  const rejected = [
    "http://zoky-qa.example.test", "http://localhost:3000", "//zoky-qa.example.test",
    `${preview}/`, `${preview}/food`, `${preview}?next=evil`, `${preview}#fragment`,
    "https://user:password@zoky-qa.example.test", "https://zoky-qa.example.test@evil.test",
    "https://ZOKY-QA.example.test", "https://zoky-qa.example.test:443",
    " https://zoky-qa.example.test", "https://zoky-qa.example.test ",
    "https://zoky-qa.example.test.evil.test", "https://zoky-qa.example.test\\evil",
    "https:////zoky-qa.example.test", "javascript:alert(1)", "data:text/html,test", "null", "",
  ];
  for (const origin of rejected) {
    assert.equal(foodReturnBaseUrl(origin, false, preview), "https://zoky.wynos.online", origin);
    assert.equal(merchantReturnBaseUrl(origin, false, preview), "https://merchant.wynos.online", origin);
  }
  // URL accepts '*' as a literal hostname character. An exact string match
  // must still reject wildcard-like configuration, even when both inputs match.
  for (const wildcard of ["https://*.example.test", "https://qa*.example.test"]) {
    assert.equal(foodReturnBaseUrl(wildcard, false, wildcard), "https://zoky.wynos.online", wildcard);
    assert.equal(merchantReturnBaseUrl(wildcard, false, wildcard), "https://merchant.wynos.online", wildcard);
  }
  // An explicitly configured attacker-controlled-looking but valid origin is a
  // deliberate operator choice. Malformed entries cannot authorize the clean
  // origin through URL normalization, credentials, a path or a default port.
  for (const invalidEntry of rejected.filter((value) => value === value.trim() && !value.endsWith(".evil.test"))) {
    assert.equal(foodReturnBaseUrl(preview, false, invalidEntry), "https://zoky.wynos.online", invalidEntry);
    assert.equal(merchantReturnBaseUrl(preview, false, invalidEntry), "https://merchant.wynos.online", invalidEntry);
  }
});

test("hosted v1 and v2 Merchant onboarding use the mode-bound preview app route", async () => {
  const preview = "https://zoky-qa.example.test";
  for (const api of ["v1", "v2"]) {
    for (const [secret, origin, configured, expectedBase] of [
      ["sk_test_fixture_only", preview, preview, `${preview}/merchant`],
      ["rk_test_fixture_only", preview, undefined, "https://merchant.wynos.online"],
      ["sk_live_fixture_only", preview, preview, "https://merchant.wynos.online"],
      ["unknown_fixture_only", preview, preview, "https://merchant.wynos.online"],
    ]) {
      const requests = [];
      const context = {
        exports: {},
        require: (path) => path.includes("_lib.ts") ? returnLibrary.exports : { createClient: () => assert.fail("No database call expected") },
        Deno: { serve: () => {} },
        URLSearchParams, Response, btoa, console,
        fetch: async (url, init) => {
          requests.push({ url, init });
          return Response.json({ url: "https://connect.stripe.test/onboarding" });
        },
      };
      runInNewContext(compileEdge(`${connect}\nglobalThis.onboardingLinkForTest = createOnboardingLink;`), context);
      await context.onboardingLinkForTest(secret, "acct_fixture", "store/fixture", api, origin, configured);
      assert.equal(requests.length, 1);
      assert.equal(requests[0].url, `https://api.stripe.com/${api === "v1" ? "v1" : "v2/core"}/account_links`);
      const body = requests[0].init.body;
      const config = api === "v1" ? body : JSON.parse(body).use_case.account_onboarding;
      const get = (key) => api === "v1" ? config.get(key) : config[key];
      assert.equal(get("return_url"), `${expectedBase}/?payments=return&store=store%2Ffixture`);
      assert.equal(get("refresh_url"), `${expectedBase}/?payments=refresh&store=store%2Ffixture`);
    }
  }
});
