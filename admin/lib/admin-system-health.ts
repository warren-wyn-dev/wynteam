import { createClient } from "@/lib/supabase/server";
import { requireAdminRole } from "@/lib/auth";
import { probePublicReachability } from "@/lib/system-health-probe.mjs";

export type HealthState = "reachable" | "degraded" | "unknown";

export type AdminHealthObservation = {
  id: "social" | "food" | "merchant" | "admin_backend";
  label: string;
  source: string;
  checkedAt: string;
  status: HealthState;
  detail: string;
};

async function checkAdminDatabaseRead(): Promise<AdminHealthObservation> {
  const checkedAt = new Date().toISOString();
  try {
    const supabase = await createClient();
    // Minimal RLS-constrained read; never counts users, scans orders or
    // mutates system state. This proves *only* authenticated database access.
    const { error } = await supabase.from("profiles").select("id").limit(1);
    if (error) throw new Error("Read failed");
    return {
      id: "admin_backend",
      label: "Admin · ฐานข้อมูล",
      source: "Supabase · สิทธิ์อ่านของเจ้าหน้าที่",
      checkedAt,
      status: "reachable",
      detail: "อ่านข้อมูลทดสอบได้ ไม่ได้ยืนยันธุรกรรมหรือทุก RPC",
    };
  } catch {
    return {
      id: "admin_backend",
      label: "Admin · ฐานข้อมูล",
      source: "Supabase · สิทธิ์อ่านของเจ้าหน้าที่",
      checkedAt,
      status: "unknown",
      detail: "ยังไม่สามารถยืนยันการอ่านข้อมูลในขณะนี้",
    };
  }
}

/** Authenticated-only, read-only status summary. No credentials or PII. */
export async function fetchAdminHealthObservations(): Promise<AdminHealthObservation[]> {
  await requireAdminRole();
  const [social, food, merchant, adminBackend] = await Promise.all([
    probePublicReachability("social"),
    probePublicReachability("food"),
    probePublicReachability("merchant"),
    checkAdminDatabaseRead(),
  ]);
  return [
    {
      ...social,
      label: "WYNOS Social",
      source: "HTTP HEAD · wynos.online",
    },
    {
      ...food,
      label: "WYNOS Food",
      source: "HTTP HEAD · food.wynos.online",
    },
    {
      ...merchant,
      label: "WYNOS Merchant",
      source: "HTTP HEAD · merchant.wynos.online",
    },
    adminBackend,
  ];
}
