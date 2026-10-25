"use client";

import { createClient } from "@/lib/supabase/client";
import type { AdminLevel, ZokySystem } from "@/lib/admin-systems";

// The admin_zoky_* RPCs decide who may change what (ZOKY-ADMIN-001); the UI never does.

export type ZokyTeamCandidate = { userId: string; username: string; displayName: string | null };

/** Exact username lookup (a leading @ and case are ignored); null when there is no such account. */
export async function findZokyTeamCandidate(username: string): Promise<ZokyTeamCandidate | null> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_zoky_find_user", { p_username: username });
  if (error) throw error;
  const row = (data as Array<{ user_id: string; username: string; display_name: string | null }> | null)?.[0];
  return row ? { userId: row.user_id, username: row.username, displayName: row.display_name } : null;
}

export async function grantZokyPermission(userId: string, system: ZokySystem, level: AdminLevel): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_zoky_grant_permission", { p_user_id: userId, p_system: system, p_level: level });
  if (error) throw error;
}

export async function revokeZokyPermission(userId: string, system: ZokySystem): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_zoky_revoke_permission", { p_user_id: userId, p_system: system });
  if (error) throw error;
}

/** Thai messages for the errors the admin_zoky_* RPCs raise. */
export function zokyTeamErrorMessage(error: unknown, fallback: string): string {
  const message = error instanceof Error ? error.message : String((error as { message?: string })?.message ?? "");
  if (message.includes("Only the super admin or a ZOKY Team Lead")) return "เฉพาะหัวหน้าทีม ZOKY หรือ super admin เท่านั้นที่จัดการทีมได้";
  if (message.includes("ZOKY Team Lead's permissions")) return "สิทธิ์ของหัวหน้าทีม ZOKY (รวมถึงของคุณเอง) แก้ได้เฉพาะ super admin";
  if (message.includes("already has every permission")) return "super admin มีสิทธิ์ทุกระบบอยู่แล้ว";
  if (message.includes("only hold food or merchant")) return "ทีม ZOKY ให้ได้เฉพาะสิทธิ์ Food และ Merchant";
  if (message.includes("User not found")) return "ไม่พบผู้ใช้นี้ ลองรีเฟรช";
  if (message.includes("Invalid level")) return "ระดับสิทธิ์ไม่ถูกต้อง";
  return fallback;
}
