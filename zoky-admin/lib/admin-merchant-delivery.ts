import { createClient } from "@/lib/supabase/server";

export type MerchantDeliveryStore = {
  id: string;
  name: string;
  published: boolean;
  geocoded: boolean;
  delivery_fee: number;
  delivery_radius_km: number;
  delivery_base_km: number;
  delivery_fee_per_km: number;
};

/** Server-side list of all stores. No customer/secret/payment details returned. */
export async function fetchMerchantDeliveryStores(): Promise<MerchantDeliveryStore[]> {
  const client = await createClient();
  const { data, error } = await client.rpc("admin_merchant_delivery_stores");
  if (error) throw error;
  if (!Array.isArray(data)) return [];
  return data as MerchantDeliveryStore[];
}
