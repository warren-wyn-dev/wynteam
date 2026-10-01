import type { SupabaseClient } from "@supabase/supabase-js";

export type MerchantApplicationStatus = "pending" | "approved" | "rejected";
export type MerchantBusinessType = "food" | "retail" | "service" | "other";

export type MerchantApplication = {
  id: string;
  user_id: string;
  business_name: string;
  business_type: MerchantBusinessType;
  contact_name: string;
  phone: string;
  address: string;
  note: string | null;
  status: MerchantApplicationStatus;
  rejection_reason: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
};

export type MerchantApplicationDraft = {
  businessName: string;
  businessType: MerchantBusinessType;
  contactName: string;
  phone: string;
  address: string;
  note: string;
};

export async function fetchMerchantApplication(client: SupabaseClient, userId: string) {
  const { data, error } = await client
    .from("merchant_applications")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw new Error(error.message);
  return (data as MerchantApplication | null) ?? null;
}

export async function submitMerchantApplication(
  client: SupabaseClient,
  userId: string,
  draft: MerchantApplicationDraft,
  existing: MerchantApplication | null,
) {
  const businessName = draft.businessName.trim();
  const contactName = draft.contactName.trim();
  const phone = draft.phone.trim();
  const address = draft.address.trim();
  const note = draft.note.trim();

  if (!businessName) throw new Error("กรุณากรอกชื่อร้านหรือชื่อธุรกิจ");
  if (!contactName) throw new Error("กรุณากรอกชื่อผู้ติดต่อ");
  if (!phone) throw new Error("กรุณากรอกเบอร์โทร");
  if (!address) throw new Error("กรุณากรอกที่อยู่ร้านหรือที่อยู่ธุรกิจ");

  const payload = {
    business_name: businessName,
    business_type: draft.businessType,
    contact_name: contactName,
    phone,
    address,
    note: note || null,
    updated_at: new Date().toISOString(),
  };

  if (existing) {
    const { error } = await client
      .from("merchant_applications")
      .update({ ...payload, status: "pending" })
      .eq("id", existing.id)
      .eq("user_id", userId);
    if (error) throw new Error(error.message);
    return;
  }

  const { error } = await client
    .from("merchant_applications")
    .insert({ user_id: userId, ...payload });
  if (error) throw new Error(error.message);
}
