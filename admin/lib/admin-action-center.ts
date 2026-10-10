import { createClient } from "@/lib/supabase/server";
import { fetchAdminFoodOverview } from "@/lib/admin-food";
import { fetchMerchantApplications, MERCHANT_APPLICATION_LIMIT } from "@/lib/admin-merchants";
import type { AdminRole } from "@/lib/auth";

export type ActionCenterItem = {
  id: string;
  label: string;
  href: string;
  createdAt: string;
};

export type ActionCenterSection = {
  id: "reports" | "merchants" | "food";
  title: string;
  description: string;
  href: string;
  countLabel: string | null;
  checkedAt: string;
  state: "ready" | "unavailable";
  items: ActionCenterItem[];
};

type OpenReports = {
  count: number | null;
  items: ActionCenterItem[];
};

/** Minimal read-only projection: no report body, user contact or PII. */
async function fetchOpenReportPreview(): Promise<OpenReports> {
  const supabase = await createClient();
  const { data, count, error } = await supabase
    .from("moderation_queue")
    .select("id, target_type, created_at", { count: "exact" })
    .in("status", ["pending", "reviewing"])
    .order("created_at", { ascending: true })
    .limit(5);
  if (error) throw error;
  return {
    count,
    items: (data ?? []).map((row) => ({
      id: String(row.id),
      label: `รายงานประเภท ${String(row.target_type)}`,
      href: `/reports/${encodeURIComponent(String(row.id))}`,
      createdAt: String(row.created_at),
    })),
  };
}

async function settle<T>(load: () => Promise<T>): Promise<
  { state: "ready"; value: T } | { state: "unavailable" }
> {
  try {
    return { state: "ready", value: await load() };
  } catch {
    // Fail independently per source; never mask an outage as zero tasks or
    // leak privileged server/database error text into the Admin browser.
    return { state: "unavailable" };
  }
}

/**
 * Staff-only, read-only hub. The page calls requireAdminRole() before this.
 * The existing Supabase RLS / scoped RPCs remain the authority for every read.
 * Food finances/order signals are never fetched for a Moderator.
 */
export async function fetchActionCenter(role: AdminRole): Promise<ActionCenterSection[]> {
  const [reports, merchants, food] = await Promise.all([
    settle(fetchOpenReportPreview),
    settle(() => fetchMerchantApplications("pending")),
    role === "admin" ? settle(fetchAdminFoodOverview) : Promise.resolve(null),
  ]);
  const checkedAt = new Date().toISOString();

  const sections: ActionCenterSection[] = [
    {
      id: "reports",
      title: "รายงานที่รอตรวจสอบ",
      description: "รายการค้างตรวจจาก Social (แสดงเก่าสุดก่อน)",
      href: "/reports",
      checkedAt,
      state: reports.state,
      countLabel: reports.state === "ready" && reports.value.count !== null
        ? String(reports.value.count) : null,
      items: reports.state === "ready" ? reports.value.items : [],
    },
    {
      id: "merchants",
      title: "คำขอสมัคร Merchant",
      description: "คำขอเปิดร้านที่รอเจ้าหน้าที่ตรวจสอบ",
      href: "/merchants",
      checkedAt,
      state: merchants.state,
      countLabel: merchants.state === "ready"
        ? (merchants.value.length >= MERCHANT_APPLICATION_LIMIT
          ? `${MERCHANT_APPLICATION_LIMIT}+` : String(merchants.value.length))
        : null,
      // Never return merchant applicant PII in the rendered action preview.
      items: [],
    },
  ];

  if (role === "admin" && food !== null) {
    sections.push({
      id: "food",
      title: "ออเดอร์ Food ที่กำลังดำเนินการ",
      description: "ข้อมูลสรุปออเดอร์ ไม่ใช่จำนวนรายการร้องเรียนหรือรอตรวจชำระ",
      href: "/food/orders",
      checkedAt,
      state: food.state,
      countLabel: food.state === "ready" ? String(food.value.active_orders) : null,
      items: [],
    });
  }
  return sections;
}
