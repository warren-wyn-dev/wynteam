/**
 * WYN-219: the WYNOS systems an admin permission can cover, and the two
 * levels (Founder decision 2026-10-10). Must match the check constraints on
 * public.admin_permissions.
 */
export const ADMIN_SYSTEMS = ["account", "social", "food", "merchant", "maps"] as const;
export type AdminSystem = (typeof ADMIN_SYSTEMS)[number];

export const ADMIN_LEVELS = ["view", "edit"] as const;
export type AdminLevel = (typeof ADMIN_LEVELS)[number];

export const ADMIN_SYSTEM_LABEL: Record<AdminSystem, string> = {
  account: "WYNOS Account",
  social: "WYNOS Social",
  food: "WYNOS Food",
  merchant: "WYNOS Merchant",
  maps: "WYNOS Maps",
};

export const ADMIN_LEVEL_LABEL: Record<AdminLevel, string> = {
  view: "ดูอย่างเดียว",
  edit: "แก้ไขได้",
};
