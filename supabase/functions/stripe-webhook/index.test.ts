import assert from "node:assert/strict";

const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));

Deno.test("webhook verifies signatures before parsing Stripe events", () => {
  const verify = source.indexOf("verifyAgainstConfiguredSecrets(raw, signature)");
  const parse = source.indexOf("try { event = JSON.parse(raw)");
  assert.ok(verify >= 0);
  assert.ok(parse > verify);
  assert.match(source, /STRIPE_WEBHOOK_SECRET/);
  assert.match(source, /STRIPE_V2_WEBHOOK_SECRET/);
  assert.match(source, /food_get_stripe_webhook_secret/);
  assert.match(source, /configuredSecrets/);
});

Deno.test("Accounts v2 thin events are scoped to the account object", () => {
  assert.match(source, /V2_ACCOUNT_SYNC_EVENTS/);
  assert.match(source, /v2\.core\.account\[configuration\.merchant\]\.capability_status_updated/);
  assert.match(source, /v2\.core\.account\[requirements\]\.updated/);
  assert.match(source, /related\?\.type\) !== "v2\.core\.account"/);
});

Deno.test("account sync webhooks claim event ids before external sync and release claims on failure", () => {
  assert.match(source, /food_claim_stripe_webhook_event/);
  assert.match(source, /food_release_stripe_webhook_event_claim/);
  const claim = source.indexOf("claimed = await claimAccountSyncEvent");
  const sync = source.indexOf("const mapped = await syncMappedAccount");
  assert.ok(claim >= 0);
  assert.ok(sync > claim);
  assert.match(source, /if \(claimed\) await releaseAccountSyncEventClaim/);
});

Deno.test("paid state stays webhook-authoritative and payout events are recorded server-side", () => {
  assert.match(source, /checkout\.session\.completed/);
  assert.match(source, /checkout\.session\.async_payment_succeeded/);
  assert.match(source, /payment_intent\.payment_failed/);
  assert.match(source, /food_apply_stripe_event/);
  assert.match(source, /payout\.paid/);
  assert.match(source, /payout\.failed/);
  assert.match(source, /food_record_stripe_payout_event/);
});

Deno.test("technical payment failures are logged but customer-facing notes are Thai", () => {
  assert.match(source, /decline_code/);
  assert.match(source, /request_id|request-id/);
  assert.match(source, /การชำระเงินไม่สำเร็จ/);
});
