import { createClient } from "@/lib/supabase/server";
import { requireAdminRole, type AdminRole } from "@/lib/auth";

export type AdminWorkSignal = {
  key: string;
  source: "report" | "merchant";
  label: string;
  href: string;
  createdAt: string;
};

export type AdminWorkSignalSource = {
  id: "reports" | "merchants";
  label: string;
  status: "ready" | "unavailable";
  items: AdminWorkSignal[];
};

const FEED_LIMIT = 10;

/**
 * This is a snapshot of existing, pending work, NOT a delivered notification.
 * No claim of sent/read status; no writes or event delivery is performed.
 * Queries use the session-scoped client. Moderator cannot query merchant
 * applications, which may include applicant PII.
 */
async function recentReportSignals(): Promise<AdminWorkSignal[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("moderation_queue")
    .select("id, target_type, created_at")
    .in("status", ["pending", "reviewing"])
    .order("created_at", { ascending: false })
    .limit(FEED_LIMIT);

  if (error) throw new Error("Report signal unavailable");
  return (data ?? []).filter((row) => typeof row.id === "string").map((row) => ({
    key: "report:" + String(row.id),
    source: "report" as const,
    label: "รายงานใหม่ที่รอตรวจสอบ",
    href: "/reports/" + encodeURIComponent(String(row.id)),
    createdAt: String(row.created_at),
  }));
}

async function recentMerchantSignals(): Promise<AdminWorkSignal[]> {
  const supabase = await createClient();
  // Existing Admin RPC returns applicant details. We deliberately project
  // only record ID + creation timestamp and discard all PII on the server.
  const { data, error } = await supabase.rpc("admin_merchant_applications", {
    p_status: "pending",
    p_limit: FEED_LIMIT,
  });
  if (error) throw new Error("Merchant signal unavailable");

  const rows = (data ?? []) as Array<{ id: string; created_at: string }>;
  return rows.filter((row) => typeof row.id === "string").slice(0, FEED_LIMIT).map((row) => ({
    key: "merchant:" + row.id,
    source: "merchant" as const,
    label: "คำขอเปิดร้านที่รอตรวจสอบ",
    href: "/merchants",
    createdAt: String(row.created_at),
  }));
}

async function getSource(
  id: AdminWorkSignalSource["id"],
  label: string,
  load: () => Promise<AdminWorkSignal[]>,
): Promise<AdminWorkSignalSource> {
  try {
    const results = await load();
    const seen = new Set<string>();
    const items = results.filter((item) => {
      if (seen.has(item.key)) return false;
      seen.add(item.key);
      return true;
    });
    return { id, label, status: "ready", items };
  } catch {
    return { id, label, status: "unavailable", items: [] };
  }
}

export async function fetchAdminWorkSignalFeed(): Promise<{
  checkedAt: string;
  sources: AdminWorkSignalSource[];
  mode: "pending_work_snapshot";
}> {
  const { role }: { role: AdminRole } = await requireAdminRole();
  const reports = getSource("reports", "รายงาน Social", recentReportSignals);

  const sources = role === "admin"
    ? await Promise.all([reports, getSource("merchants", "คำขอ Merchant", recentMerchantSignals)])
    : [await reports];

  return {
    checkedAt: new Date().toISOString(),
    sources,
    mode: "pending_work_snapshot",
  };
}
