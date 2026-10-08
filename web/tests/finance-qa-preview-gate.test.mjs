import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here=dirname(fileURLToPath(import.meta.url));
const preview=readFileSync(resolve(here,"../components/merchant/merchant-finance-qa-preview.tsx"),"utf8");
const finance=readFileSync(resolve(here,"../components/merchant/merchant-finance.tsx"),"utf8");

test("QA preview must require env flag AND exact Supabase QA project URL",()=>{
  assert.match(preview,/NEXT_PUBLIC_WYNOS_FINANCE_QA_PREVIEW === "true"/);
  assert.match(preview,/process\.env\.NEXT_PUBLIC_SUPABASE_URL === QA_PROJECT_URL/);
  assert.match(preview,/https:\/\/pcatuxtenluqzjzzwsvl\.supabase\.co/);
  assert.match(preview,/if \(!qaEnabled\) return null/);
});

test("Merchant real finance remains separate from simulated QA preview",()=>{
  assert.match(finance,/fetchFinanceSummary\(client, store\.id, range\)/);
  assert.match(finance,/fetchMerchantStripeFinance\(client, store\.id\)/);
  assert.match(finance,/<MerchantFinanceQaPreview client=\{client\} storeId=\{store\.id\} \/>/);
  assert.match(preview,/ข้อมูลจำลองเท่านั้น/);
  assert.match(preview,/ไม่ใช่รายได้จริง/);
});

test("QA preview only uses the merchant-owner Finance v2 read-only reporting RPCs",()=>{
  assert.match(preview,/merchant_food_finance_buckets_v2_qa/);
  assert.match(preview,/merchant_food_finance_order_details_v2_qa/);
  assert.doesNotMatch(preview,/(application_fee_amount|stripe\.refunds|transfers\.create|payouts\.create)/);
  assert.match(preview,/stripe_fee_status|Stripe: ไม่ทราบ/);
});
