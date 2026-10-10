import { createClient } from "@/lib/supabase/server";
import type { AdminLevel, AdminSystem } from "@/lib/admin-systems";

export type AdminAccess = {
  /** False until the WYN-219 foundation migration is applied to this database. */
  available: boolean;
  superAdmin: boolean;
  permissions: Partial<Record<AdminSystem, AdminLevel>>;
};

/**
 * The signed-in user's own access (admin_my_access, WYN-219). Fails closed:
 * any error -- including the RPC not existing yet -- means no super admin
 * and no permissions, so this page can ship before the database apply.
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

export type AdminPermissionRow = {
  user_id: string;
  username: string | null;
  system: AdminSystem;
  level: AdminLevel;
  granted_by: string | null;
  granted_by_username: string | null;
  granted_at: string;
};

/** Every granted permission (admin_list_permissions -- super admin only). */
export async function fetchAdminPermissions(): Promise<AdminPermissionRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_list_permissions");
  if (error) throw error;
  return (data ?? []) as AdminPermissionRow[];
}
