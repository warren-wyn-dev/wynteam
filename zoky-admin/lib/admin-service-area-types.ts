// Shared by the server loader and the client manager (no server imports).
/** One service area: the whole country ("TH") or a province ("TH-10" ... "TH-96"). */
export type ServiceArea = {
  group_code: string;
  kind: "country" | "province" | "custom";
  name: string;
  name_en: string | null;
  active: boolean;
  updated_at: string;
};

export type ServiceAreaData = { canEdit: boolean; areas: ServiceArea[] };

/** Thai message for the RPC's known errors. */
export function serviceAreaError(error: unknown): string {
  const message = error instanceof Error ? error.message : String((error as { message?: unknown })?.message ?? error ?? "");
  if (message.includes("At least one service area must stay open")) return "ต้องเปิดให้บริการอย่างน้อย 1 พื้นที่";
  if (message.includes("Only the super admin")) return "เฉพาะ Super admin เท่านั้นที่เปลี่ยนพื้นที่ให้บริการได้";
  if (message.includes("Service area not found")) return "ไม่พบพื้นที่นี้ กรุณาโหลดหน้าใหม่";
  return "บันทึกไม่สำเร็จ กรุณาลองใหม่";
}
