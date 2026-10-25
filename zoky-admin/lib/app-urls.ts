/**
 * WYNOS Admin keeps Account, Social, Maps, the audit log and Roles &
 * Permissions (ZOKY-ADMIN-001); links to those pages leave ZOKY Admin.
 * Overridable for staging/preview builds.
 */
const WYNOS_ADMIN_ORIGIN = (process.env.NEXT_PUBLIC_WYNOS_ADMIN_URL || "https://admin.wynos.online").replace(/\/+$/, "");

export function wynosAdminUrl(path: string): string {
  return `${WYNOS_ADMIN_ORIGIN}${path}`;
}
