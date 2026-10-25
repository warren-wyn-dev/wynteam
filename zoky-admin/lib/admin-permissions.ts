import { createClient } from "@/lib/supabase/server";
import type { AdminSystemAccess } from "@/lib/admin-systems";

/** `available` is false until the WYN-219 foundation migration is applied. */
export type AdminAccess = AdminSystemAccess;

/**
 * The signed-in user's own access (admin_my_access, WYN-219). Fails closed:
 * any error -- including the RPC not existing yet -- means no super admin
 * and no permissions, which keeps ZOKY Admin closed (mayEnterZokyAdmin).
 */
export async function fetchAdminAccess(): Promise<AdminAccess> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_my_access");
  if (error || !data) {
    return { available: false, superAdmin: false, permissions: {} };
  }
  const access = data as { super_admin?: boolean; permissions?: AdminAccess["permissions"] };
  return {
    available: true,
    superAdmin: access.super_admin === true,
    permissions: access.permissions ?? {},
  };
}
