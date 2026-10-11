import { Suspense } from "react";
import {
  UserPlus,
  Activity,
  ImageIcon,
  Eye,
  Users,
  Heart,
  MessageCircle,
  Repeat2,
  Mail,
  Flag,
  CheckCircle2,
  Zap,
  RotateCcw,
  AlertTriangle,
} from "lucide-react";

import { StatCard } from "@/components/admin/stat-card";
import { TopSourcesCard } from "@/components/admin/top-sources-card";
import { DauTrendChart } from "@/components/admin/dau-trend-chart";
import { FeedAlgorithmObservability } from "@/components/admin/feed-algorithm-observability";
import {
  deltaPct,
  fetchAdminDashboardMetrics,
  fetchAdminDashboardTrends,
  fetchSignupCounts,
} from "@/lib/admin-metrics";

/**
 * The actual data-fetching grid, per Design spec's Screen -- lives in
 * its own async component (not inline in page.tsx) so `<Suspense>` in
 * page.tsx can show DashboardSkeleton while this specific fetch is in
 * flight, without delaying the rest of the page (header/refresh button).
 *
 * Section order is priority order, not a fixed layout -- reordered per
 * the Founder's ask to see what matters most first:
 * 1. A reports-pending alert (only when there's actually something to
 *    act on -- wyn-admin-design-system.md section 3.3's "critical alert
 *    that's active" case, the one place besides destructive actions
 *    color is allowed at all).
 * 2. The DAU trend chart -- the platform's pulse at a glance.
 * 3. ผู้ใช้งาน / เนื้อหา / การมีส่วนร่วม -- now with a vs-yesterday badge on
 *    every "_today" count, not just the raw number.
 * 4. รายงาน (the full card, kept even when nothing's pending, since
 *    reports_total is still useful context) and การเติบโต last, same as
 *    before -- both less immediately actionable day-to-day.
 */
export async function DashboardMetrics({ showFeed }: { showFeed: boolean }) {
  // Each source fails on its own: one RPC error hides only the sections that
  // need it (with a notice) instead of taking down the whole Dashboard.
  const [mResult, tResult, sResult] = await Promise.allSettled([
    fetchAdminDashboardMetrics(),
    fetchAdminDashboardTrends(),
    fetchSignupCounts(),
  ]);
  const m = settledValue(mResult, "admin_dashboard_metrics");
  const t = settledValue(tResult, "admin_dashboard_trends");
  const s = settledValue(sResult, "admin_signup_counts");
  const failed = [!m && "ตัวเลขหลัก", !t && "กราฟ DAU และการเทียบกับเมื่อวาน", !s && "ผู้สมัครสมาชิกใหม่"].filter(Boolean);

  return (
    <div className="flex flex-col gap-6 p-6">
      {failed.length > 0 ? (
        <p role="alert" className="flex items-center gap-2 rounded-lg border p-4 text-sm text-muted-foreground">
          <AlertTriangle className="size-4 shrink-0" aria-hidden="true" />
          {`โหลดข้อมูลบางส่วนไม่สำเร็จ: ${failed.join(", ")} — ลองกดรีเฟรชอีกครั้ง`}
        </p>
      ) : null}

      {m && m.reports_pending > 0 ? (
        <div
          role="alert"
          className="flex items-center gap-3 rounded-lg border border-destructive bg-destructive/10 p-4"
        >
          <AlertTriangle className="size-5 shrink-0 text-destructive" aria-hidden="true" />
          <p className="text-sm text-destructive">
            มีรายงานรอดำเนินการ <span className="font-bold">{m.reports_pending.toLocaleString("th-TH")}</span> รายการ
            — ไปที่ Report Center เพื่อตรวจสอบ
          </p>
        </div>
      ) : null}

      {t ? <DauTrendChart days={t.dau_last_14d} /> : null}

      {/* Needs social:view (admin_feed_algorithm_dashboard re-checks); it
          catches its own errors so it never blanks the page. */}
      {showFeed ? (
        <Suspense fallback={null}>
          <FeedAlgorithmObservability />
        </Suspense>
      ) : null}

      {m ? (
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">ผู้ใช้งาน</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          DAU/WAU/MAU นับจากผู้ใช้ที่มีกิจกรรมบนแพลตฟอร์ม (โพสต์/ถูกใจ/คอมเมนต์/ReDrop/ส่งข้อความ)
          ไม่ใช่จำนวนครั้งที่เปิดแอป — DAU/WAU/MAU เป็นค่าเฉลี่ยนับย้อนหลัง จึงไม่มีตัวเลขเทียบกับเมื่อวาน
          เหมือน &quot;ผู้ใช้ใหม่&quot;
        </p>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatCard
            label="ผู้ใช้ใหม่"
            value={m.new_users_today}
            icon={UserPlus}
            sublabel="ใน 24 ชม.ล่าสุด"
            deltaPct={t ? deltaPct(m.new_users_today, t.new_users_yesterday) : undefined}
          />
          <StatCard label="DAU" value={m.dau} icon={Activity} sublabel="Active ใน 1 วัน" />
          <StatCard label="WAU" value={m.wau} icon={Activity} sublabel="Active ใน 7 วัน" />
          <StatCard label="MAU" value={m.mau} icon={Activity} sublabel="Active ใน 30 วัน" />
        </div>
      </section>
      ) : null}

      {s ? (
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">ผู้สมัครสมาชิกใหม่</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          จำนวนบัญชีที่สมัครสำเร็จ นับแยกตามช่วงเวลาปัจจุบัน (แต่ละช่วงนับซ้อนกัน เช่น
          &quot;เดือนนี้&quot; รวม &quot;วันนี้&quot; อยู่ในนั้นแล้ว) — สัปดาห์เริ่มวันจันทร์
        </p>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatCard label="วันนี้" value={s.today} icon={UserPlus} />
          <StatCard label="สัปดาห์นี้" value={s.this_week} icon={UserPlus} />
          <StatCard label="เดือนนี้" value={s.this_month} icon={UserPlus} />
          <StatCard label="ปีนี้" value={s.this_year} icon={UserPlus} />
        </div>
      </section>
      ) : null}

      {m ? (
        <>
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">เนื้อหา</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          กิจกรรมสร้างเนื้อหาใหม่บนแพลตฟอร์มใน 24 ชม.ล่าสุด — Club เดียวที่นับ &quot;ทั้งหมด&quot; แทน
          &quot;วันนี้&quot; เพราะเป็นตัวเลขสะสม ไม่ใช่กิจกรรมรายวัน
        </p>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatCard
            label="Drop"
            value={m.drops_today}
            icon={ImageIcon}
            sublabel="ใน 24 ชม.ล่าสุด"
            deltaPct={t ? deltaPct(m.drops_today, t.drops_yesterday) : undefined}
          />
          <StatCard
            label="ยอดดู Drop"
            value={m.views_today}
            icon={Eye}
            sublabel="ใน 24 ชม.ล่าสุด"
            deltaPct={t ? deltaPct(m.views_today, t.views_yesterday) : undefined}
          />
          <StatCard
            label="Club"
            value={m.clubs_total}
            icon={Users}
            secondaryValue={m.clubs_new_today}
            secondaryLabel="สร้างใหม่ใน 24 ชม.ล่าสุด"
          />
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">การมีส่วนร่วม</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          ปฏิกิริยาที่ผู้ใช้มีต่อเนื้อหา (ถูกใจ/คอมเมนต์/ReDrop) และการพูดคุยส่วนตัว (ข้อความ) ใน 24 ชม.ล่าสุด
        </p>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatCard
            label="ถูกใจ"
            value={m.likes_today}
            icon={Heart}
            sublabel="ใน 24 ชม.ล่าสุด"
            deltaPct={t ? deltaPct(m.likes_today, t.likes_yesterday) : undefined}
          />
          <StatCard
            label="คอมเมนต์"
            value={m.comments_today}
            icon={MessageCircle}
            sublabel="ใน 24 ชม.ล่าสุด"
            deltaPct={t ? deltaPct(m.comments_today, t.comments_yesterday) : undefined}
          />
          <StatCard
            label="ReDrop"
            value={m.redrops_today}
            icon={Repeat2}
            sublabel="ใน 24 ชม.ล่าสุด"
            deltaPct={t ? deltaPct(m.redrops_today, t.redrops_yesterday) : undefined}
          />
          <StatCard
            label="ข้อความ"
            value={m.messages_today}
            icon={Mail}
            sublabel="ใน 24 ชม.ล่าสุด"
            deltaPct={t ? deltaPct(m.messages_today, t.messages_yesterday) : undefined}
          />
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">รายงาน</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          ยอดสะสมทั้งหมดตั้งแต่เปิดระบบ ไม่ใช่แค่วันนี้ — ตัวเลข &quot;รอดำเนินการ&quot; คือสิ่งที่ต้องรีบตรวจสอบ
        </p>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatCard
            label="รายงาน"
            value={m.reports_total}
            icon={Flag}
            secondaryValue={m.reports_pending}
            secondaryLabel="รอดำเนินการ"
            secondaryTone="warn"
          />
        </div>
      </section>

      {/*
        WYN-077: always appended last, never inserted between existing
        sections -- keeps the Admin's existing mental model of section
        order intact. See .wyn/docs/design/wyn-077-basic-product-analytics.md.
      */}
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">การเติบโต</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          Retention นับจากผู้ใช้ที่กลับมามีกิจกรรมบนแพลตฟอร์ม ไม่ใช่แค่เปิดเว็บทิ้งไว้ ·
          ช่องทางนับจากลิงก์ที่มี UTM parameter เท่านั้น ผู้ใช้ที่พิมพ์ URL เข้าเองจะขึ้นเป็น
          &quot;ไม่ระบุที่มา&quot;
        </p>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatCard label="สมัครใหม่" value={m.signup_started_24h} icon={UserPlus} sublabel="ใน 24 ชม.ล่าสุด" />
          <StatCard
            label="สมัครสำเร็จ"
            value={m.signup_completed_24h}
            icon={CheckCircle2}
            // Cohort with 0 signups today -> the RPC returns null, not a
            // misleading "0%" -- shown as plain 0 here, same convention
            // every other stat card in this dashboard already uses for
            // "genuinely nothing happened yet" (e.g. new_users_today).
            secondaryValue={m.signup_conversion_pct ?? 0}
            secondaryLabel="อัตราสมัครสำเร็จ (%)"
          />
          <StatCard
            label="Activation"
            value={m.activation_pct_24h ?? 0}
            icon={Zap}
            secondaryValue={m.activation_count_24h}
            secondaryLabel="คน"
          />
          <StatCard label="D1 Retention" value={m.retention_d1_pct ?? 0} icon={RotateCcw} sublabel="% กลับมาใช้วันที่ 1" />
          <StatCard label="D7 Retention" value={m.retention_d7_pct ?? 0} icon={RotateCcw} sublabel="% กลับมาใช้วันที่ 7" />
        </div>
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
          <TopSourcesCard sources={m.top_sources} />
        </div>
      </section>
        </>
      ) : null}
    </div>
  );
}

function settledValue<T>(result: PromiseSettledResult<T>, source: string): T | null {
  if (result.status === "fulfilled") return result.value;
  // Server log only (the browser gets the generic notice above).
  console.error(`[admin dashboard] ${source} failed:`, result.reason instanceof Error ? result.reason.message : result.reason);
  return null;
}
