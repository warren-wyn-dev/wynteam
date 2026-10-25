/**
 * WYN-219: the WYNOS systems an admin permission can cover, and the two
 * levels (Founder decision 2026-10-10). Must match the check constraints on
 * public.admin_permissions.
 */
export const ADMIN_SYSTEMS = ["account", "social", "food", "merchant", "maps"] as const;
export type AdminSystem = (typeof ADMIN_SYSTEMS)[number];

/** The WYN-219 systems ZOKY Admin covers (ZOKY-ADMIN-001). */
export const ZOKY_SYSTEMS = ["food", "merchant"] as const satisfies readonly AdminSystem[];
export type ZokySystem = (typeof ZOKY_SYSTEMS)[number];

export function isAdminSystem(value: string): value is AdminSystem {
  return (ADMIN_SYSTEMS as readonly string[]).includes(value);
}

export const ADMIN_LEVELS = ["view", "edit"] as const;
export type AdminLevel = (typeof ADMIN_LEVELS)[number];

export const ADMIN_SYSTEM_LABEL: Record<AdminSystem, string> = {
  account: "WYNOS Account",
  social: "WYNOS Social",
  food: "ZOKY Food",
  merchant: "ZOKY Merchant",
  maps: "WYNOS Maps",
};

export const ADMIN_LEVEL_LABEL: Record<AdminLevel, string> = {
  view: "ดูอย่างเดียว",
  edit: "แก้ไขได้",
};

export type AdminSystemAccess = {
  available: boolean;
  superAdmin: boolean;
  /** ZOKY-ADMIN-001: may manage the ZOKY team's food/merchant permissions. */
  teamLead: boolean;
  permissions: Partial<Record<AdminSystem, AdminLevel>>;
};

/**
 * Whether the caller may use `system` at `level` (edit includes view), or
 * null before the WYN-219 foundation exists in this database, in which case
 * callers keep the older platform_role behaviour. UI only: the database
 * re-checks every call.
 */
export function hasSystemAccess(access: AdminSystemAccess, system: AdminSystem, level: AdminLevel = "view"): boolean | null {
  if (!access.available) return null;
  if (access.superAdmin) return true;
  const granted = access.permissions[system];
  return granted === "edit" || (granted === "view" && level === "view");
}
