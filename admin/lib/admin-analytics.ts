import { notFound } from "next/navigation";

import { requireAdminRole } from "@/lib/auth";
import {
  fetchAdminDashboardMetrics,
  fetchAdminDashboardTrends,
  fetchSignupCounts,
} from "@/lib/admin-metrics";
import { fetchAdminFoodOverview } from "@/lib/admin-food";
import { fetchMerchantApplications, MERCHANT_APPLICATION_LIMIT } from "@/lib/admin-merchants";
import { safeDaySeries, safeMerchantSample, safeMetric } from "@/lib/analytics-series.mjs";

export type AnalyticsMetric = {
  label: string;
  count: number;
  unit?: string;
};

export type AnalyticsPoint = { day: string; count: number };

export type AnalyticsPanel = {
  id: "social" | "social_signups" | "social_trend" | "food" | "merchant";
  title: string;
  source: string;
  checkedAt: string;
  status: "ready" | "unavailable";
  metrics: AnalyticsMetric[];
  trend: AnalyticsPoint[] | null;
  trendLabel: string | null;
  note: string;
};

function numeric(label: string, value: unknown, options?: { integer?: boolean }): AnalyticsMetric {
  const count = safeMetric(value, options);
  if (count === null) throw new Error("Invalid analytics value");
  return { label, count };
}

/**
 * Every section is independent: an unavailable RPC must not be displayed as
 * zero, or erase healthy data from other services.
 */
async function panel(
  id: AnalyticsPanel["id"],
  title: string,
  source: string,
  load: () => Promise<Pick<AnalyticsPanel, "metrics" | "trend" | "trendLabel" | "note">>,
): Promise<AnalyticsPanel> {
  const checkedAt = new Date().toISOString();
  try {
    const result = await load();
    return { id, title, source, checkedAt, status: "ready", ...result };
  } catch {
    // Deliberately never return raw Supabase exception details to the UI.
    return {
      id, title, source, checkedAt, status: "unavailable",
      metrics: [], trend: null, trendLabel: null,
      note: "ตรวจสอบข้อมูลไม่ได้ในขณะนี้ ไม่ได้หมายความว่ายอดเป็นศูนย์",
    };
  }
}

/**
 * Read-only Admin-only aggregation. This is intentionally stricter than
 * the Social dashboard: Finance and Merchant applicant APIs are not
 * queried for Moderator accounts, even as invisible background calls.
 */
export async function fetchAdminAnalytics(): Promise<AnalyticsPanel[]> {
  const { role } = await requireAdminRole();
  if (role !== "admin") notFound();

  return Promise.all([
    panel("social", "WYNOS Social · ผู้ใช้งาน", "admin_dashboard_metrics()", async () => {
      const value = await fetchAdminDashboardMetrics();
      return {
        metrics: [
          numeric("ผู้ใช้กิจกรรมรายวัน (DAU)", value.dau),
          numeric("ผู้ใช้กิจกรรม 7 วัน (WAU)", value.wau),
          numeric("ผู้ใช้กิจกรรม 30 วัน (MAU)", value.mau),
        ],
        trend: null, trendLabel: null,
        note: "นับจากกิจกรรมบน Social ตามนิยาม RPC ไม่ใช่ยอดการเปิดแอป",
      };
    }),
    panel("social_signups", "WYNOS Social · สมัครสมาชิก", "admin_signup_counts()", async () => {
      const value = await fetchSignupCounts();
      return {
        metrics: [
          numeric("วันนี้", value.today),
          numeric("สัปดาห์นี้", value.this_week),
          numeric("เดือนนี้", value.this_month),
          numeric("ปีนี้", value.this_year),
        ],
        trend: null, trendLabel: null,
        note: "ช่วงเวลาซ้อนทับกันตามนิยาม RPC ต้นทาง ห้ามนำมารวมยอด",
      };
    }),
    panel("social_trend", "WYNOS Social · แนวโน้ม DAU", "admin_dashboard_trends()", async () => {
      const value = await fetchAdminDashboardTrends();
      const trend = safeDaySeries(value.dau_last_14d, {
        dateKey: "date", countKey: "count", limit: 14,
      });
      if (trend === null) throw new Error("Invalid DAU series");
      return {
        metrics: [], trend, trendLabel: "จำนวนบัญชีที่มีกิจกรรม (DAU) ต่อวัน",
        note: "แสดงเฉพาะวันที่ RPC ส่งมา ไม่มีการเติมตัวเลขศูนย์ให้วันที่ข้อมูลหาย",
      };
    }),
    panel("food", "WYNOS Food · คำสั่งซื้อ", "admin_food_overview()", async () => {
      const value = await fetchAdminFoodOverview();
      const trend = safeDaySeries(value.days, {
        dateKey: "day", countKey: "orders", limit: 7,
      });
      if (trend === null) throw new Error("Invalid Food order series");
      return {
        metrics: [
          numeric("ออเดอร์วันนี้", value.orders_today),
          numeric("กำลังดำเนินการ", value.active_orders),
          numeric("ร้านอาหารทั้งหมด", value.stores_total),
          numeric("ยอดขายวันนี้ (บาท)", value.sales_today, { integer: false }),
        ],
        trend, trendLabel: "จำนวนออเดอร์ต่อวันจาก Admin Food RPC",
        note: "ยอดขายตามนิยาม RPC ต้นทาง (ออเดอร์ที่ส่งแล้ว) · ข้อมูลการเงินแสดงเฉพาะ Admin",
      };
    }),
    panel("merchant", "WYNOS Merchant · คำขอเปิดร้าน", "admin_merchant_applications()", async () => {
      // This existing Admin RPC exposes applicant PII internally. The
      // original records MUST NOT be passed on, logged or serialized.
      const rows = await fetchMerchantApplications();
      const sample = safeMerchantSample(rows, MERCHANT_APPLICATION_LIMIT);
      if (sample === null) throw new Error("Invalid Merchant sample");
      return {
        metrics: [
          numeric("คำขอในชุดข้อมูลที่มองเห็น", sample.sampled),
          numeric("รอตรวจในชุดข้อมูล", sample.pending),
          numeric("อนุมัติในชุดข้อมูล", sample.approved),
        ],
        trend: null, trendLabel: null,
        note: sample.capped
          ? "ข้อมูลถึงเพดาน 200 รายการ: ไม่ใช่ยอดคำขอทั้งหมด และยังไม่มีแนวโน้มที่ตรวจรับแล้ว"
          : "นับเฉพาะคำขอที่ RPC ส่งกลับ (สูงสุด 200 รายการ) ไม่ใช่ยอด Merchant ทั้งระบบ · ยังไม่มีแนวโน้มรายวันที่ตรวจรับแล้ว",
      };
    }),
  ]);
}
