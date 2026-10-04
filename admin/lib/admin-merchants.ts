import { createClient } from "@/lib/supabase/server";

export type MerchantApplicationStatus = "pending" | "approved" | "rejected";
export type MerchantBusinessType = "food" | "retail" | "service" | "other";

export type AdminMerchantApplication = {
  id: string;
  user_id: string;
  applicant_username: string | null;
  applicant_display_name: string | null;
  business_name: string;
  business_type: MerchantBusinessType;
  contact_name: string;
  phone: string;
  address: string;
  note: string | null;
  status: MerchantApplicationStatus;
  rejection_reason: string | null;
  reviewed_at: string | null;
  reviewer_username: string | null;
  created_at: string;
  updated_at: string;
  food_store_id: string | null;
  merchant_access_enabled: boolean;
};

/** The RPC returns at most this many; the page says so when it is full. */
export const MERCHANT_APPLICATION_LIMIT = 200;

export async function fetchMerchantApplications(
  status?: MerchantApplicationStatus,
): Promise<AdminMerchantApplication[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_merchant_applications", {
    p_status: status ?? null,
    p_limit: MERCHANT_APPLICATION_LIMIT,
  });

  if (error) throw error;
  return (data ?? []) as AdminMerchantApplication[];
}
