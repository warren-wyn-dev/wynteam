import type { AdminMenuOptionGroup, AdminMerchantMenuItem } from "@/lib/admin-merchant-menu";

export type MenuOptionDraft = Omit<AdminMenuOptionGroup, "choices"> & {
  choices: Array<{ id: string; name: string; price: string }>;
};
export type AdminMenuForm = {
  name: string; category: string; description: string; price: string;
  is_available: boolean; daily_stock_limit: string; sold_out_until: string;
  image_path: string; options: MenuOptionDraft[];
};

export function bangkokMenuDate(value: string | null): string {
  if (!value) return "";
  const time = new Date(value).getTime();
  return Number.isFinite(time) ? new Date(time + 7 * 60 * 60 * 1000).toISOString().slice(0, 16) : "";
}

export function menuForm(item?: AdminMerchantMenuItem): AdminMenuForm {
  return {
    name: item?.name ?? "", category: item?.category ?? "อาหาร",
    description: item?.description ?? "", price: item ? String(item.price) : "",
    is_available: item?.is_available ?? false,
    daily_stock_limit: item?.daily_stock_limit == null ? "" : String(item.daily_stock_limit),
    sold_out_until: bangkokMenuDate(item?.sold_out_until ?? null),
    image_path: item?.image_path ?? "",
    options: (item?.options ?? []).map(group => ({ ...group,
      choices: group.choices.map(choice => ({ ...choice, price: String(choice.price) })),
    })),
  };
}

export function menuValues(form: AdminMenuForm, original?: AdminMerchantMenuItem | null) {
  return {
    name: form.name.trim(), category: form.category.trim(), description: form.description.trim() || null,
    price: form.price.trim() ? Number(form.price) : NaN,
    is_available: form.is_available,
    daily_stock_limit: form.daily_stock_limit.trim() ? Number(form.daily_stock_limit) : null,
    sold_out_until: form.sold_out_until
      ? original && form.sold_out_until === bangkokMenuDate(original.sold_out_until)
        ? original.sold_out_until : new Date(`${form.sold_out_until}:00+07:00`).toISOString()
      : null,
    image_path: form.image_path || null,
    options: form.options.map(group => ({
      id: group.id, name: group.name.trim(), required: group.required, max_select: group.max_select,
      choices: group.choices.map(choice => ({
        id: choice.id, name: choice.name.trim(), price: choice.price.trim() ? Number(choice.price) : NaN,
      })),
    })),
  };
}

export function menuFormError(form: AdminMenuForm): string | null {
  if (!form.name.trim() || form.name.trim().length > 160) return "ชื่อเมนูต้องมี 1–160 ตัวอักษร";
  if (!form.category.trim() || form.category.trim().length > 60) return "หมวดหมู่ต้องมี 1–60 ตัวอักษร";
  if (form.description.trim().length > 1000) return "รายละเอียดต้องไม่เกิน 1,000 ตัวอักษร";
  const price = Number(form.price);
  if (!form.price.trim() || !Number.isFinite(price) || price < 0 || price > 100000 || Math.abs(price * 100 - Math.round(price * 100)) > 0.00001) {
    return "ราคาต้องอยู่ระหว่าง 0–100,000 บาท และมีทศนิยมไม่เกิน 2 ตำแหน่ง";
  }
  if (form.daily_stock_limit.trim()) {
    const stock = Number(form.daily_stock_limit);
    if (!Number.isInteger(stock) || stock < 1 || stock > 9999) return "สต็อกต่อวันต้องเป็นจำนวนเต็ม 1–9,999";
  }
  if (form.sold_out_until && (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(form.sold_out_until)
    || !Number.isFinite(new Date(`${form.sold_out_until}:00+07:00`).getTime())
    || bangkokMenuDate(`${form.sold_out_until}:00+07:00`) !== form.sold_out_until)) return "เวลาหยุดขายไม่ถูกต้อง";
  if (form.options.length > 20) return "เพิ่มกลุ่มตัวเลือกได้สูงสุด 20 กลุ่ม";
  const groupIds = new Set<string>();
  for (const group of form.options) {
    if (!group.id.trim() || group.id.trim().length > 80 || groupIds.has(group.id.trim())) return "รหัสกลุ่มตัวเลือกซ้ำหรือไม่ถูกต้อง";
    groupIds.add(group.id.trim());
    if (!group.name.trim() || group.name.trim().length > 160) return "ชื่อกลุ่มตัวเลือกต้องมี 1–160 ตัวอักษร";
    if (!group.choices.length || group.choices.length > 50) return "แต่ละกลุ่มต้องมีตัวเลือก 1–50 รายการ";
    if (!Number.isInteger(group.max_select) || group.max_select < 1 || group.max_select > Math.min(20, group.choices.length)) return "จำนวนที่เลือกได้ต้องไม่เกินจำนวนตัวเลือก และไม่เกิน 20";
    const ids = new Set<string>();
    for (const choice of group.choices) {
      if (!choice.id.trim() || choice.id.trim().length > 80 || ids.has(choice.id.trim())) return "รหัสตัวเลือกซ้ำหรือไม่ถูกต้อง";
      ids.add(choice.id.trim());
      if (!choice.name.trim() || choice.name.trim().length > 160) return "ชื่อตัวเลือกต้องมี 1–160 ตัวอักษร";
      const surcharge = Number(choice.price);
      if (!choice.price.trim() || !Number.isFinite(surcharge) || surcharge < 0 || surcharge > 100000
        || Math.abs(surcharge * 100 - Math.round(surcharge * 100)) > 0.00001) return "ราคาเพิ่มต้องอยู่ระหว่าง 0–100,000 บาท และมีทศนิยมไม่เกิน 2 ตำแหน่ง";
    }
  }
  return null;
}

export function menuErrorMessage(error: unknown): string {
  const message = error && typeof error === "object" && "message" in error ? String(error.message) : String(error);
  if (/changed|stale|refresh/i.test(message)) return "ข้อมูลถูกแก้ไขแล้ว กรุณาโหลดข้อมูลล่าสุดก่อนบันทึกอีกครั้ง";
  if (/Not authorized|permission denied/i.test(message)) return "ไม่มีสิทธิ์ดำเนินการนี้ ต้องมีสิทธิ์ Merchant ที่ตรงกับการทำรายการ";
  if (/image/i.test(message)) return "รูปภาพไม่พร้อมใช้งาน หรือไม่ได้เป็นรูปของร้านนี้ กรุณาเลือกรูปใหม่";
  if (/archived/i.test(message)) return "เมนูถูกเก็บแล้ว กรุณากู้คืนก่อนแก้ไข";
  if (/reason/i.test(message)) return "กรุณาระบุเหตุผล 5–300 ตัวอักษร";
  return "ทำรายการไม่สำเร็จ กรุณาตรวจข้อมูลและลองอีกครั้ง";
}
