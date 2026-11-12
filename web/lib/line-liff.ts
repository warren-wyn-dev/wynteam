// ZOKY: LINE in-app browser helpers kept only for the login guidance (Google
// sign-in is blocked inside LINE's browser). LINE notifications, the /line
// LIFF entry and store friend prompts were removed 2026-11-12.
// No secrets: LIFF IDs are public identifiers.

export type LineAudience = "food" | "merchant";

const LIFF_ID = /^\d{10}-[A-Za-z0-9]{8}$/;

export function liffIdFor(audience: LineAudience, ids: { food?: string; merchant?: string }): string | null {
  const id = (audience === "food" ? ids.food : ids.merchant)?.trim() ?? "";
  return LIFF_ID.test(id) ? id : null;
}

/** LIFF IDs from the build environment (inlined by Next.js). */
export function configuredLiffIds(): { food?: string; merchant?: string } {
  return {
    food: process.env.NEXT_PUBLIC_LIFF_ID_FOOD,
    merchant: process.env.NEXT_PUBLIC_LIFF_ID_MERCHANT,
  };
}

/** LINE's in-app browser (also the LIFF browser). */
export function isLineInAppBrowser(userAgent: string): boolean {
  return /\bLine\/\d/i.test(userAgent);
}

/** ZOKY-LINE-002 F: the only URL opened externally. No query, hash, token or basket. */
export function foodLoginExternalUrl(origin: string): string {
  return `${origin}/food/login`;
}
