import { createClient } from "@/lib/supabase/server";
import type { AdminLevel, AdminSystem, AdminSystemAccess } from "@/lib/admin-systems";

/** `available` is false until the WYN-219 foundation migration is applied. */
export type AdminAccess = AdminSystemAccess;

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

/**
 * ZOKY Team Leads (ZOKY-ADMIN-001), read through admin_zoky_list_team --
 * super admin only on this page. null until that migration is applied, so
 * the page can ship first and hide the Team Lead controls.
 */
export async function fetchZokyTeamLeads(): Promise<Array<{ userId: string; username: string | null }> | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_zoky_list_team");
  if (error) {
    if (error.code === "PGRST202" || error.code === "42883") return null;
    throw error;
  }
  const leads = new Map<string, string | null>();
  for (const row of (data ?? []) as Array<{ user_id: string; username: string | null; is_team_lead: boolean }>) {
    if (row.is_team_lead) leads.set(row.user_id, row.username);
  }
  return [...leads].map(([userId, username]) => ({ userId, username }));
}
