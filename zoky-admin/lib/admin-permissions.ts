import { createClient } from "@/lib/supabase/server";
import type { AdminSystemAccess } from "@/lib/admin-systems";

export type AdminAccess = AdminSystemAccess;

const NO_ACCESS: AdminAccess = { available: false, superAdmin: false, teamLead: false, permissions: {} };

/**
 * The signed-in user's own ZOKY Admin access (zoky_admin_my_access,
 * ZOKY-ADMIN-001): super admin, ZOKY Team Lead and food/merchant levels.
 * Until that migration is applied it falls back to WYN-219's
 * admin_my_access (no Team Leads). Fails closed: any other error means no
 * access, which keeps ZOKY Admin closed (mayEnterZokyAdmin).
 */
export async function fetchAdminAccess(): Promise<AdminAccess> {
  const supabase = await createClient();
  let { data, error } = await supabase.rpc("zoky_admin_my_access");
  if (error && (error.code === "PGRST202" || error.code === "42883")) {
    ({ data, error } = await supabase.rpc("admin_my_access"));
  }
  if (error || !data) return NO_ACCESS;
  const access = data as { super_admin?: boolean; team_lead?: boolean; permissions?: AdminAccess["permissions"] };
  return {
    available: true,
    superAdmin: access.super_admin === true,
    teamLead: access.team_lead === true,
    permissions: access.permissions ?? {},
  };
}
