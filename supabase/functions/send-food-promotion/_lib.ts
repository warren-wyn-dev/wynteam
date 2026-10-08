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

/**
 * Default Food marketing quiet hours in Thailand: 22:00–08:00.
 * Order notifications do not use this worker and are unaffected.
 */
export function isFoodPromoQuietTime(now: Date): boolean {
  const hour = Number(new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Bangkok", hour: "2-digit", hourCycle: "h23",
  }).format(now));
  return hour >= 22 || hour < 8;
}
