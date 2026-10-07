import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const here=path.dirname(fileURLToPath(import.meta.url));
const read=(p)=>fs.readFileSync(path.resolve(here,p),"utf8");

const schema=read("../../supabase/migrations_wynos_finance_control_center_v1.sql");
const engine=read("../../supabase/migrations_wynos_finance_engine_v1.sql");
const adminApi=read("../../supabase/migrations_wynos_finance_admin_api_v1.sql");
const hardening=read("../../supabase/migrations_wynos_finance_hardening_v1.sql");
const stripeHardening=read("../../supabase/migrations_wynos_finance_stripe_hardening_v1.sql");
const checkout=read("../../supabase/functions/food-stripe-checkout/index.ts");
const refund=read("../../supabase/functions/merchant-stripe-refund/index.ts");
const webhook=read("../../supabase/functions/stripe-webhook/index.ts");
const food=read("../lib/food-customer.ts");
const adminPage=read("../../admin/app/(admin)/finance/page.tsx");
const adminActions=read("../../admin/app/(admin)/finance/actions.ts");

test("GP uses temporary > custom > default and is snapshotted",()=>{
  assert.match(engine,/food_store_gp_promotions/);
  assert.match(engine,/return query select p\.gp_bps,'promotion'/);
  assert.match(engine,/o\.custom_gp_bps/);
  assert.match(engine,/c\.default_gp_bps/);
  assert.match(engine,/food_orders_financial_snapshot/);
  assert.match(schema,/gp_bps integer not null/);
  assert.match(schema,/default_gp_bps integer not null default 1000/);
});

test("delivery is backend-configurable with zone and province pricing",()=>{
  assert.match(engine,/create or replace function internal\.food_delivery_fee/);
  assert.match(engine,/delivery_base_fee_satang/);
  assert.match(engine,/delivery_per_km_satang/);
  assert.match(engine,/delivery_rounding_m/);
  assert.match(engine,/delivery_min_fee_satang/);
  assert.match(engine,/delivery_max_fee_satang/);
  assert.match(engine,/free_delivery_threshold/);
  assert.ok(hardening.includes("Store override > service-area rule > province rule > platform default"));
  assert.match(hardening,/r\.province/);
  assert.match(adminApi,/admin_set_delivery_zone_pricing/);
});

test("rider earning and payout are separate from delivery fee",()=>{
  assert.match(engine,/create or replace function internal\.food_rider_earning/);
  assert.match(schema,/create table if not exists public\.food_rider_jobs/);
  assert.match(schema,/create table if not exists public\.food_rider_payouts/);
  assert.match(hardening,/admin_rider_finance/);
  assert.match(hardening,/admin_create_rider_payout/);
  assert.match(hardening,/admin_mark_rider_payout_paid/);
  assert.match(schema,/rider_platform_fee_bps/);
});

test("payment methods come from central flags and checkout is PromptPay-only",()=>{
  assert.match(schema,/\('promptpay_enabled','-infinity',true/);
  assert.match(schema,/\('card_enabled','-infinity',false/);
  assert.match(schema,/\('apple_pay_enabled','-infinity',false/);
  assert.match(schema,/\('google_pay_enabled','-infinity',false/);
  assert.match(engine,/food_payment_configuration/);
  assert.match(checkout,/food_feature_flags/);
  assert.match(checkout,/promptPayFlag\?\.enabled !== true/);
  assert.match(checkout,/account\.promptpay_enabled !== true/);
  assert.match(checkout,/payment_method_types\[0\].*promptpay/);
  assert.doesNotMatch(checkout,/payment_method_types\[0\].*card/);
});

test("Stripe fee is separate from GP and actual Stripe balance transaction wins",()=>{
  assert.match(schema,/stripe_fee_satang bigint/);
  assert.match(schema,/gp_amount_satang bigint/);
  assert.match(engine,/food_record_stripe_fee/);
  assert.match(engine,/balance_transaction_id/);
  assert.match(webhook,/syncStripeProcessingFee/);
  assert.match(webhook,/food_record_stripe_fee/);
});

test("customer fees and risky surcharges default OFF",()=>{
  for(const key of ["service_fee_enabled","small_order_fee_enabled","surge_pricing_enabled","peak_pricing_enabled","rain_surcharge_enabled"]){
    assert.ok(schema.includes("('"+key+"','-infinity',false"));
  }
  assert.match(engine,/food_customer_fee_components/);
});

test("promotion funding snapshots merchant and WYNOS cost separately",()=>{
  assert.match(engine,/food_snapshot_campaign_funding/);
  assert.match(engine,/merchant_funded_satang/);
  assert.match(engine,/platform_funded_satang/);
  assert.match(schema,/platform_discount_satang bigint/);
  assert.match(schema,/merchant_discount_satang bigint/);
});

test("merchant settlement is transparent and prevents duplicate orders",()=>{
  assert.match(schema,/create table if not exists public\.food_merchant_settlements/);
  assert.match(schema,/gross_sales_satang/);
  assert.match(schema,/merchant_discount_satang/);
  assert.match(schema,/payment_fees_satang/);
  assert.match(schema,/refunds_satang/);
  assert.match(schema,/adjustments_satang/);
  assert.match(schema,/unique \(order_id\)/);
  assert.ok(adminApi.includes("pg_advisory_xact_lock(hashtext('merchant-settlement:"));
  assert.match(adminApi,/not exists\([\s\S]*food_merchant_settlement_lines/);
});

test("refund supports full/partial policy and is pinned to original payment",()=>{
  assert.match(refund,/amountSatang/);
  assert.match(refund,/partial_refund_admin_only/);
  assert.match(refund,/liability/);
  assert.match(refund,/refundGp/);
  assert.match(refund,/refundDelivery/);
  assert.ok(refund.includes("Original payment identity is mandatory"));
  assert.match(engine,/food_create_refund_request/);
  assert.match(engine,/food_apply_refund_result/);
  assert.ok(engine.includes("refund_status in ('none','pending','failed','partial','refunded')"));
});

test("VAT structure exists but stays OFF by default",()=>{
  assert.match(schema,/tax_enabled boolean not null default false/);
  assert.match(schema,/vat_registered boolean not null default false/);
  assert.match(schema,/vat_percent_bps integer not null default 700/);
  assert.ok(schema.includes("false, false, 700"));
});

test("finance/config ledgers are deny-by-default RLS and finance audit is immutable",()=>{
  assert.match(schema,/enable row level security/);
  assert.ok(schema.includes("revoke all on table public.%I from public, anon, authenticated"));
  assert.match(hardening,/audit_log_finance_immutable/);
  assert.match(hardening,/before update or delete on public\.audit_log/);
  assert.ok(adminApi.includes("coalesce(internal.current_platform_role(),'') <> 'admin'"));
});

test("every new order receives backend pricing and integer financial snapshot",()=>{
  assert.match(engine,/food_orders_financial_pricing/);
  assert.match(engine,/before insert on public\.food_orders/);
  assert.match(engine,/food_orders_financial_snapshot/);
  assert.match(engine,/after insert on public\.food_orders/);
  assert.match(schema,/subtotal_satang bigint/);
  assert.match(schema,/customer_total_satang bigint/);
  assert.match(food,/food_quote_order_financial/);
});

test("web does not own the finance formulas",()=>{
  assert.match(food,/client\.rpc\("food_quote_order_financial"/);
  assert.doesNotMatch(food,/gp_amount_satang\s*=|merchant_net_satang\s*=|stripe_fee_satang\s*=/);
});

test("webhook remains payment source of truth and deduplicates events",()=>{
  assert.match(stripeHardening,/on conflict\(event_id\) do nothing/);
  assert.ok(stripeHardening.includes("original Stripe account mismatch"));
  assert.match(webhook,/checkout\.session\.completed/);
  assert.match(webhook,/food_apply_stripe_event/);
  assert.match(webhook,/duplicate: true/);
});

test("Admin UI exposes requested control categories via server actions",()=>{
  for(const text of [
    "Finance / Platform Control","Pricing · GP / Commission","Delivery Pricing","Payments",
    "Customer Fees","Merchant Controls / GP","Riders","Tax / VAT","Platform Feature Flags",
    "Settlement / Refund Operations","Security / Audit"
  ]) assert.ok(adminPage.includes(text), text);
  assert.ok(adminActions.startsWith('"use server"'));
  assert.match(adminActions,/requireAdminRole/);
  assert.match(adminActions,/auditMetadata/);
  assert.match(adminActions,/admin_set_finance_config/);
  assert.match(adminActions,/admin_set_feature_flag/);
});

test("Preview Admin cannot execute live Stripe refund",()=>{
  assert.ok(adminActions.includes('process.env.VERCEL_ENV !== "production"'));
  assert.ok(adminActions.includes('Origin:"https://admin.wynos.online"'));
  assert.ok(refund.includes('origin !== "https://merchant.wynos.online" && origin !== "https://admin.wynos.online"'));
});
