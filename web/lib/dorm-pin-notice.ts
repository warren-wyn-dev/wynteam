/**
 * Who is responsible for the dorm-pin data and how a customer reaches them (shown in the box's detail text).
 * The Founder fills these two in; until BOTH are set the box is not shown at all, so the feature cannot go
 * live with an incomplete notice. Retention (stated in the same text): kept until the customer withdraws,
 * offers the reviewer rejects are deleted after 90 days (norswor-backend `dorm_pin_prune`).
 */
export const DORM_PIN_CONTROLLER: string | null = "Norswor Maps"; // Founder, 2026-11-16 (a product name: check with the legal reviewer whether a company name is needed)
export const DORM_PIN_CONTACT: string | null = "WynChat"; // Founder, 2026-11-16: contact through WynChat (a specific account or link can be added later)

export type DormPinNotice = { controller: string | null; contact: string | null };

export function dormPinNoticeComplete(notice: DormPinNotice = { controller: DORM_PIN_CONTROLLER, contact: DORM_PIN_CONTACT }): boolean {
  return Boolean(notice.controller?.trim()) && Boolean(notice.contact?.trim());
}
