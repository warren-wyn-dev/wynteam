/** GP v1 helpers shared by server pages and client dialogs (no server imports). */

/** A rate row's label: null means the store follows the default again. */
export function gpRowLabel(rateBp: number | null): string {
  return rateBp === null ? "ใช้ GP เริ่มต้น" : formatGpRate(rateBp);
}

/** 1550 -> "15.5%", 2000 -> "20%". */
export function formatGpRate(rateBp: number): string {
  const whole = Math.trunc(rateBp / 100);
  const frac = Math.abs(rateBp % 100);
  return `${whole}${frac ? `.${String(frac).padStart(2, "0").replace(/0$/, "")}` : ""}%`;
}

/**
 * "15", "15.5", "15.25" -> basis points. Up to two decimals, 0-100.
 * Returns null for anything else (including "1e2", "-1", "15.255").
 */
export function parseGpPercent(input: string): number | null {
  const match = /^(\d{1,3})(?:\.(\d{1,2}))?$/.exec(input.trim());
  if (!match) return null;
  const bp = Number(match[1]) * 100 + Number((match[2] ?? "").padEnd(2, "0"));
  return bp <= 10000 ? bp : null;
}

/**
 * GP on a food value (after the store's own discount), in satang: round half
 * up, the same rule as internal.food_order_gp. For the preview only -- the
 * database works out the real figure on each order.
 */
export function previewGpSatang(baseSatang: number, rateBp: number): number {
  return Math.floor((baseSatang * rateBp + 5000) / 10000);
}

/** "2026-10-12T09:30" typed in Bangkok time -> ISO with +07:00, or null. */
export function bangkokLocalToIso(value: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) return null;
  const date = new Date(`${value}:00+07:00`);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

export function adminGpError(error: unknown): string {
  const message = (error as { message?: string } | null)?.message ?? "";
  if (message.includes("needs a rate")) return "GP เริ่มต้นต้องระบุอัตรา";
  if (message.includes("different change")) return "คำขอนี้ถูกส่งไปแล้วด้วยค่าที่ต่างกัน ปิดหน้าต่างแล้วลองใหม่";
  if (message.includes("Only the super admin")) return "เฉพาะ super admin เท่านั้นที่แก้ GP ได้";
  if (message.includes("between 0 and 100")) return "GP ต้องอยู่ระหว่าง 0–100%";
  if (message.includes("reason")) return "กรุณาใส่เหตุผล 3–300 ตัวอักษร";
  if (message.includes("past")) return "ตั้ง GP ย้อนหลังไม่ได้ เลือกเวลาตั้งแต่ตอนนี้เป็นต้นไป";
  if (message.includes("end must be after start")) return "วันสิ้นสุดต้องอยู่หลังวันเริ่ม";
  if (message.includes("already in effect")) return "GP ที่มีผลแล้วยกเลิกไม่ได้ ให้ตั้งอัตราใหม่แทน";
  if (message.includes("already cancelled")) return "รายการนี้ถูกยกเลิกไปแล้ว";
  if (message.includes("store not found")) return "ไม่พบร้านนี้";
  return "บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง";
}
