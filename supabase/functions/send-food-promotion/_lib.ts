// Pure helpers for Food marketing notifications. Never target unclassified tokens.
export function foodPromoTokenQuery(userId: string): string {
  return `push_tokens?user_id=eq.${encodeURIComponent(userId)}&platform=eq.web&app=eq.food&select=token`;
}
export function foodPromoPushPayload(campaignId: string, deliveryId: string, title: string, body: string, code: string | null) {
  return {
    app: "food", type: "food_promotion",
    broadcast_id: campaignId, delivery_id: deliveryId,
    push_title: title, push_body: body, coupon_code: code ?? "",
  };
}
