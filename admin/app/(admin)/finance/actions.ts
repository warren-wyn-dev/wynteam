"use server";

import { headers } from "next/headers";
import { revalidatePath } from "next/cache";

import { requireAdminRole } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

function requiredText(formData: FormData, key: string) {
  const value = String(formData.get(key) ?? "").trim();
  if (!value) throw new Error(`${key} is required`);
  return value;
}
function optionalNumber(formData: FormData, key: string) {
  const raw = String(formData.get(key) ?? "").trim();
  if (!raw) return null;
  const value = Number(raw);
  if (!Number.isFinite(value)) throw new Error(`${key} is invalid`);
  return value;
}
function numberValue(formData: FormData, key: string) {
  const value = optionalNumber(formData,key);
  if (value == null) throw new Error(`${key} is required`);
  return value;
}
function baht(value: number | null) {
  return value == null ? null : Math.round(value*100);
}
function km(value: number | null) {
  return value == null ? null : Math.round(value*1000);
}
function bps(value: number | null) {
  return value == null ? null : Math.round(value*100);
}
function bangkokTime(raw: FormDataEntryValue | null) {
  const value=String(raw ?? "").trim();
  if (!value) return new Date().toISOString();
  if (/Z$|[+-]\d\d:\d\d$/.test(value)) return new Date(value).toISOString();
  return new Date(`${value.length===16 ? value+":00" : value}+07:00`).toISOString();
}
async function auditMetadata() {
  const h=await headers();
  return {
    ip: (h.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null)?.slice(0,64) ?? null,
    user_agent: h.get("user-agent")?.slice(0,300) ?? null,
  };
}
async function adminClient() {
  const auth=await requireAdminRole();
  if (auth.role!=="admin") throw new Error("Only admins can change financial configuration");
  return createClient();
}
async function rpc(name: string,args: Record<string,unknown>) {
  const supabase=await adminClient();
  const { data,error }=await supabase.rpc(name,args);
  if (error) throw new Error(error.message);
  return data;
}
function refresh() {
  revalidatePath("/finance");
  revalidatePath("/food");
}

export async function updateDefaultGpAction(formData: FormData) {
  await rpc("admin_set_finance_config",{
    p_patch:{ default_gp_bps:bps(numberValue(formData,"default_gp_percent")) },
    p_effective_from:bangkokTime(formData.get("effective_from")),
    p_reason:requiredText(formData,"reason"),
    p_metadata:await auditMetadata(),
  });
  refresh();
}

export async function updateDeliveryPricingAction(formData: FormData) {
  await rpc("admin_set_finance_config",{
    p_patch:{
      delivery_base_fee_satang:baht(numberValue(formData,"base_fee")),
      delivery_base_distance_m:km(numberValue(formData,"base_distance_km")),
      delivery_per_km_satang:baht(numberValue(formData,"per_km")),
      delivery_min_fee_satang:baht(numberValue(formData,"min_fee")),
      delivery_max_fee_satang:baht(optionalNumber(formData,"max_fee")),
      delivery_rounding_m:km(numberValue(formData,"rounding_km")),
      free_delivery_threshold_satang:baht(optionalNumber(formData,"free_delivery_threshold")),
      peak_surcharge_satang:baht(numberValue(formData,"peak_surcharge")),
      rain_surcharge_satang:baht(numberValue(formData,"rain_surcharge")),
      long_distance_threshold_m:km(optionalNumber(formData,"long_distance_km")),
      long_distance_surcharge_satang:baht(numberValue(formData,"long_distance_surcharge")),
    },
    p_effective_from:bangkokTime(formData.get("effective_from")),
    p_reason:requiredText(formData,"reason"),
    p_metadata:await auditMetadata(),
  });
  refresh();
}

export async function updateRiderEarningsAction(formData: FormData) {
  await rpc("admin_set_finance_config",{
    p_patch:{
      rider_base_pay_satang:baht(numberValue(formData,"base_pay")),
      rider_pay_per_km_satang:baht(numberValue(formData,"per_km")),
      rider_min_earning_satang:baht(numberValue(formData,"min_earning")),
      rider_long_distance_threshold_m:km(optionalNumber(formData,"long_distance_km")),
      rider_long_distance_bonus_satang:baht(numberValue(formData,"long_distance_bonus")),
      rider_peak_bonus_satang:baht(numberValue(formData,"peak_bonus")),
      rider_rain_bonus_satang:baht(numberValue(formData,"rain_bonus")),
      rider_incentive_order_count:optionalNumber(formData,"incentive_order_count"),
      rider_incentive_bonus_satang:baht(numberValue(formData,"incentive_bonus")),
      rider_platform_fee_bps:bps(numberValue(formData,"platform_fee_percent")),
    },
    p_effective_from:bangkokTime(formData.get("effective_from")),
    p_reason:requiredText(formData,"reason"),
    p_metadata:await auditMetadata(),
  });
  refresh();
}

export async function updatePaymentPolicyAction(formData: FormData) {
  const effective=bangkokTime(formData.get("effective_from"));
  const reason=requiredText(formData,"reason");
  const metadata=await auditMetadata();
  const payer=requiredText(formData,"stripe_fee_payer");
  if (!["wynos","merchant","shared"].includes(payer)) throw new Error("invalid fee payer");

  await rpc("admin_set_finance_config",{
    p_patch:{
      stripe_fee_payer:payer,
      stripe_shared_merchant_bps:bps(numberValue(formData,"stripe_shared_merchant_percent")),
    },
    p_effective_from:effective,p_reason:reason,p_metadata:metadata,
  });

  for (const key of ["promptpay_enabled","card_enabled","apple_pay_enabled","google_pay_enabled"]) {
    await rpc("admin_set_feature_flag",{
      p_flag_key:key,
      p_enabled:String(formData.get(key) ?? "false")==="true",
      p_effective_from:effective,p_reason:reason,p_metadata:metadata,
    });
  }
  refresh();
}

export async function updateCustomerFeesAction(formData: FormData) {
  const effective=bangkokTime(formData.get("effective_from"));
  const reason=requiredText(formData,"reason");
  const metadata=await auditMetadata();
  const serviceMode=requiredText(formData,"service_fee_mode");
  const smallMode=requiredText(formData,"small_order_fee_mode");
  const surgeMode=requiredText(formData,"surge_fee_mode");
  const modeValue=(mode:string,value:number)=>mode==="percent" ? bps(value) : baht(value);

  await rpc("admin_set_finance_config",{
    p_patch:{
      service_fee_mode:serviceMode,
      service_fee_value:modeValue(serviceMode,numberValue(formData,"service_fee_value")),
      service_fee_min_satang:baht(numberValue(formData,"service_fee_min")),
      service_fee_max_satang:baht(optionalNumber(formData,"service_fee_max")),
      small_order_threshold_satang:baht(numberValue(formData,"small_order_threshold")),
      small_order_fee_mode:smallMode,
      small_order_fee_value:modeValue(smallMode,numberValue(formData,"small_order_fee_value")),
      small_order_fee_max_satang:baht(optionalNumber(formData,"small_order_fee_max")),
      surge_fee_mode:surgeMode,
      surge_fee_value:modeValue(surgeMode,numberValue(formData,"surge_fee_value")),
      surge_fee_max_satang:baht(optionalNumber(formData,"surge_fee_max")),
    },
    p_effective_from:effective,p_reason:reason,p_metadata:metadata,
  });
  for (const key of ["service_fee_enabled","small_order_fee_enabled","surge_pricing_enabled"]) {
    await rpc("admin_set_feature_flag",{
      p_flag_key:key,p_enabled:String(formData.get(key) ?? "false")==="true",
      p_effective_from:effective,p_reason:reason,p_metadata:metadata,
    });
  }
  refresh();
}

export async function updateTaxAction(formData: FormData) {
  await rpc("admin_set_finance_config",{
    p_patch:{
      tax_enabled:String(formData.get("tax_enabled") ?? "false")==="true",
      vat_registered:String(formData.get("vat_registered") ?? "false")==="true",
      vat_percent_bps:bps(numberValue(formData,"vat_percent")),
    },
    p_effective_from:bangkokTime(formData.get("effective_from")),
    p_reason:requiredText(formData,"reason"),
    p_metadata:await auditMetadata(),
  });
  refresh();
}

export async function setFeatureFlagAction(formData: FormData) {
  await rpc("admin_set_feature_flag",{
    p_flag_key:requiredText(formData,"flag_key"),
    p_enabled:requiredText(formData,"enabled")==="true",
    p_effective_from:bangkokTime(formData.get("effective_from")),
    p_reason:requiredText(formData,"reason"),
    p_metadata:await auditMetadata(),
  });
  refresh();
}

export async function setStoreFinanceAction(formData: FormData) {
  const gp=optionalNumber(formData,"custom_gp_percent");
  await rpc("admin_set_store_finance_override",{
    p_store_id:requiredText(formData,"store_id"),
    p_patch:{
      custom_gp_bps:bps(gp),
      payment_enabled:requiredText(formData,"payment_enabled")==="true",
      payout_suspended:requiredText(formData,"payout_suspended")==="true",
      promotion_eligible:requiredText(formData,"promotion_eligible")==="true",
    },
    p_effective_from:bangkokTime(formData.get("effective_from")),
    p_reason:requiredText(formData,"reason"),
    p_metadata:await auditMetadata(),
  });
  refresh();
}

export async function createTemporaryGpAction(formData: FormData) {
  await rpc("admin_create_store_gp_promotion",{
    p_store_id:requiredText(formData,"store_id"),
    p_gp_bps:bps(numberValue(formData,"gp_percent")),
    p_starts_at:bangkokTime(formData.get("starts_at")),
    p_ends_at:bangkokTime(formData.get("ends_at")),
    p_reason:requiredText(formData,"reason"),
    p_metadata:await auditMetadata(),
  });
  refresh();
}

export async function setRiderStatusAction(formData: FormData) {
  await rpc("admin_set_rider_status",{
    p_user_id:requiredText(formData,"user_id"),
    p_status:requiredText(formData,"status"),
    p_active:requiredText(formData,"active")==="true",
    p_service_area_code:String(formData.get("service_area_code") ?? "").trim() || null,
    p_payout_suspended:requiredText(formData,"payout_suspended")==="true",
    p_reason:requiredText(formData,"reason"),
    p_metadata:await auditMetadata(),
  });
  refresh();
}
