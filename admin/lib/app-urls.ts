/**
 * Food and Merchant moved to ZOKY Admin (ZOKY-ADMIN-001); links and
 * redirects to those pages leave WYNOS Admin. Overridable for
 * staging/preview builds. next.config.ts reads the same variable.
 */
export const ZOKY_ADMIN_ORIGIN = (process.env.NEXT_PUBLIC_ZOKY_ADMIN_URL || "https://zoky-admin.wynos.online").replace(/\/+$/, "");

export function zokyAdminUrl(path: string): string {
  return `${ZOKY_ADMIN_ORIGIN}${path}`;
}
