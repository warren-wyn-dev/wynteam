import { createClient } from "@/lib/supabase/server";

export type MapReportStatus = "open" | "reviewing" | "resolved" | "dismissed";
export type AdminMapReport = {
  id: string; place_id: string | null; place_name: string;
  kind: "wrong_info" | "closed" | "duplicate" | "unsafe" | "other";
  note: string; status: MapReportStatus; version: number; created_at: string; updated_at: string;
};
export type MapReportEvent = { before_status: MapReportStatus | null; after_status: MapReportStatus; version: number; reason: string; created_at: string };

export async function fetchAdminMapReports(): Promise<AdminMapReport[]> {
  const client = await createClient();
  const { data, error } = await client.rpc("admin_wynos_map_reports", { p_status: "open", p_limit: 100 }).abortSignal(AbortSignal.timeout(10_000));
  if (error) throw error;
  if (!Array.isArray(data)) throw new Error("Unexpected Maps report response");
  return data as AdminMapReport[];
}
