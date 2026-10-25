import { createClient } from "@/lib/supabase/server";
import type { AdminLevel, ZokySystem } from "@/lib/admin-systems";

export type ZokyTeamMember = {
  userId: string;
  username: string | null;
  displayName: string | null;
  isTeamLead: boolean;
  permissions: Array<{ system: ZokySystem; level: AdminLevel; grantedByUsername: string | null; grantedAt: string }>;
};

type ZokyTeamRow = {
  user_id: string;
  username: string | null;
  display_name: string | null;
  is_team_lead: boolean;
  system: ZokySystem | null;
  level: AdminLevel | null;
  granted_by_username: string | null;
  granted_at: string | null;
};

/**
 * The ZOKY team (admin_zoky_list_team, ZOKY-ADMIN-001): every food/merchant
 * permission plus Team Leads without one, grouped per person. Super admin
 * or Team Lead only -- the RPC refuses anyone else.
 */
export async function fetchZokyTeam(): Promise<ZokyTeamMember[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_zoky_list_team");
  if (error) throw error;

  const byUser = new Map<string, ZokyTeamMember>();
  for (const row of (data ?? []) as ZokyTeamRow[]) {
    const member = byUser.get(row.user_id) ?? {
      userId: row.user_id,
      username: row.username,
      displayName: row.display_name,
      isTeamLead: row.is_team_lead,
      permissions: [],
    };
    if (row.system && row.level && row.granted_at) {
      member.permissions.push({ system: row.system, level: row.level, grantedByUsername: row.granted_by_username, grantedAt: row.granted_at });
    }
    byUser.set(row.user_id, member);
  }
  return [...byUser.values()];
}
