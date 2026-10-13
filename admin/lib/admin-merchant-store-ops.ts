import { createClient } from "@/lib/supabase/server";
export type MerchantStoreOps = {
 id: string;
 name: string;
 is_open: boolean;
 temporary_closed_until: string | null;
 temporary_closed_reason: string | null;
 prep_time_min_minutes: number;
 prep_time_max_minutes: number;
 published: boolean;
 admin_suspended: boolean;
};
export async function fetchMerchantStoreOps(): Promise<MerchantStoreOps[]> {
 const c=await createClient();
 const {data,error}=await c.rpc("admin_merchant_store_operations");
 if(error) throw error;
 return Array.isArray(data)?data as MerchantStoreOps[]:[];
}
