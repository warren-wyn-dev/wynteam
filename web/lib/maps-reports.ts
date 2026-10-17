import type { SupabaseClient } from "@supabase/supabase-js";

export type MapReportKind = "wrong_info" | "closed" | "duplicate" | "unsafe" | "other";
export type MapReportStatus = "open" | "reviewing" | "resolved" | "dismissed";
export type MyMapReport = {
  id: string; place_id: string | null; place_name: string; kind: MapReportKind;
  status: MapReportStatus; created_at: string; updated_at: string;
};
export type ReportableMapPlace = { id: string; name_th: string; address: string | null };

export const mapReportKinds: Record<MapReportKind, string> = {
  wrong_info: "ข้อมูลสถานที่ไม่ถูกต้อง", closed: "สถานที่ปิดแล้ว", duplicate: "สถานที่ซ้ำ", unsafe: "ข้อกังวลด้านความปลอดภัย", other: "อื่น ๆ",
};
export const mapReportStatuses: Record<MapReportStatus, string> = {
  open: "รอรับเรื่อง", reviewing: "กำลังตรวจสอบ", resolved: "ตรวจสอบเสร็จแล้ว", dismissed: "ปิดเรื่องโดยไม่ดำเนินการ",
};

export function canReportMapPlace(id: unknown): id is string {
  return typeof id === "string" && /^wynos_place_[0-9a-f]{32}$/.test(id);
}
export function mapReportErrorCopy(error: unknown): string {
  const message = error && typeof error === "object" && "message" in error ? String(error.message) : "";
  const code = error && typeof error === "object" && "code" in error ? String(error.code) : "";
  if (message.includes("Active report already exists")) return "คุณมีรายงานสถานที่นี้ที่รอตรวจสอบอยู่แล้ว ดูสถานะด้านล่างได้";
  if (message.includes("Report rate limit")) return "ส่งรายงานครบ 5 เรื่องใน 24 ชั่วโมงแล้ว กรุณาลองใหม่ภายหลัง";
  if (message.includes("Public place not available")) return "สถานที่นี้ไม่ได้เปิดสาธารณะแล้ว กรุณาค้นหาใหม่";
  if (message.includes("Not authorized") || code === "42501") return "กรุณาเข้าสู่ระบบด้วยบัญชีที่มีสิทธิ์ทดสอบฟีเจอร์นี้";
  if (code === "PGRST202" || code === "42883") return "ระบบรายงานยังไม่พร้อมใช้งาน กรุณาลองใหม่ภายหลัง";
  if (message.includes("Invalid report input")) return "กรุณาเลือกสถานที่และระบุรายละเอียด 10–500 ตัวอักษร";
  return "ดำเนินการไม่สำเร็จ กรุณาลองใหม่";
}
export async function loadMyMapReports(client: SupabaseClient): Promise<MyMapReport[]> {
  const { data, error } = await client.rpc("wynos_my_map_reports", { p_limit: 50 }).abortSignal(AbortSignal.timeout(10_000));
  if (error) throw error;
  if (!Array.isArray(data)) throw new Error("Unexpected report response");
  return data as MyMapReport[];
}
export async function searchReportableMapPlaces(client: SupabaseClient, query: string): Promise<ReportableMapPlace[]> {
  const term = query.trim();
  if (term.length < 2 || term.length > 100) return [];
  // Use the existing active-place RLS, selecting only public fields. Escape
  // LIKE wildcards so a name search cannot accidentally enumerate the catalog.
  const pattern = term.replace(/[\\%_]/g, "\\$&");
  const { data, error } = await client.from("wynos_places").select("id,name_th,address")
    .eq("is_active", true).ilike("name_th", `%${pattern}%`).order("name_th").limit(10)
    .abortSignal(AbortSignal.timeout(10_000));
  if (error) throw error;
  return (data ?? []).filter(place => canReportMapPlace(place.id)) as ReportableMapPlace[];
}
export async function submitMapReport(client: SupabaseClient, placeId: string, kind: MapReportKind, note: string): Promise<string> {
  if (!canReportMapPlace(placeId) || !Object.hasOwn(mapReportKinds, kind) || note.trim().length < 10 || note.trim().length > 500) {
    throw new Error("Invalid report input");
  }
  const { data, error } = await client.rpc("submit_wynos_map_report", { p_place_id: placeId, p_kind: kind, p_note: note.trim() })
    .abortSignal(AbortSignal.timeout(15_000));
  if (error) throw error;
  if (typeof data !== "string") throw new Error("Unexpected report response");
  return data;
}
