"use client";

import { createClient } from "@/lib/supabase/client";
import type { AdminLevel, AdminSystem } from "@/lib/admin-systems";

// The RPCs re-check that the caller is the super admin; the UI never decides.

export async function grantAdminPermission(userId: string, system: AdminSystem, level: AdminLevel): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_grant_permission", {
    p_user_id: userId,
    p_system: system,
    p_level: level,
  });
  if (error) throw error;
}

export async function revokeAdminPermission(userId: string, system: AdminSystem): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_revoke_permission", {
    p_user_id: userId,
    p_system: system,
  });
  if (error) throw error;
}

/** Thai messages for the errors admin_grant/revoke_permission raise. */
export function permissionErrorMessage(error: unknown, fallback: string): string {
  const message = error instanceof Error ? error.message : String((error as { message?: string })?.message ?? "");
  if (message.includes("Only the super admin")) return "เฉพาะ super admin เท่านั้นที่ให้หรือถอนสิทธิ์ได้";
  if (message.includes("already has every permission")) return "super admin มีสิทธิ์ทุกระบบอยู่แล้ว";
  if (message.includes("User not found")) return "ไม่พบผู้ใช้นี้ ลองรีเฟรช";
  if (message.includes("Invalid system") || message.includes("Invalid level")) return "ระบบหรือระดับสิทธิ์ไม่ถูกต้อง";
  return fallback;
}
