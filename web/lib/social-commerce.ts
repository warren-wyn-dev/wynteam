import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import type { FoodCustomerOrder } from "@/lib/food-customer";

export type SocialCommerceOffer = {
  drop_id: string;
  store_id: string;
  menu_item_id: string;
  store_name: string;
  item_name: string;
  item_description: string | null;
  price: number | string;
  image_path: string | null;
  delivery_fee: number | string;
  minimum_order: number | string;
  store_open: boolean;
  payment_ready: boolean;
  is_orderable: boolean;
};

export async function fetchSocialCommerceOffer(
  client: SupabaseClient,
  dropId: string,
): Promise<SocialCommerceOffer | null> {
  const { data, error } = await client.rpc("food_social_offers_for_drops", {
    p_drop_ids: [dropId],
  });
  if (error) throw new Error(error.message);
  const row = Array.isArray(data) ? data[0] : null;
  return row ? row as SocialCommerceOffer : null;
}

export async function createSocialCommerceOrder(
  client: SupabaseClient,
  dropId: string,
  input: {
    recipientName: string;
    recipientPhone: string;
    shippingAddress: string;
    customerNote?: string;
    quantity: number;
  },
) {
  const { data, error } = await client.rpc("food_create_social_order", {
    p_drop_id: dropId,
    p_recipient_name: input.recipientName,
    p_recipient_phone: input.recipientPhone,
    p_shipping_address: input.shippingAddress,
    p_customer_note: input.customerNote || null,
    p_quantity: input.quantity,
  });
  if (error) throw new Error(error.message);
  return String(data);
}

export async function fetchSocialCommerceOrder(
  client: SupabaseClient,
  orderId: string,
): Promise<FoodCustomerOrder | null> {
  const { data, error } = await client
    .from("food_orders")
    .select("*,food_order_items(*),food_delivery_proofs(*)")
    .eq("id", orderId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data as FoodCustomerOrder | null;
}

export function subscribeSocialCommerceOrder(
  client: SupabaseClient,
  orderId: string,
  onChange: () => void,
): RealtimeChannel {
  return client
    .channel(`wynos-social-order:${orderId}`)
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "food_orders", filter: `id=eq.${orderId}` },
      onChange,
    )
    .subscribe();
}

export function socialCommerceError(error: unknown, fallback = "ดำเนินการไม่สำเร็จ") {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.includes("social offer not found")) return "โพสต์นี้ไม่มีสินค้าที่เปิดขายแล้ว";
  if (message.includes("social offer is not accepting orders")) return "ร้านยังไม่พร้อมรับออเดอร์จากโพสต์นี้";
  if (message.includes("merchant payment is not configured")) return "ร้านยังไม่ได้ตั้งค่า PromptPay";
  if (message.includes("minimum order not met")) return "ยอดสั่งซื้อยังไม่ถึงขั้นต่ำของร้าน";
  if (message.includes("recipient information is required")) return "กรุณากรอกชื่อ เบอร์โทร และที่อยู่ให้ครบ";
  if (message.includes("permanent account required")) return "ต้องใช้บัญชี WYNOS ที่ลงทะเบียนแล้ว";
  return message || fallback;
}
