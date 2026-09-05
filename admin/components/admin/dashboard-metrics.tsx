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
  MessagesSquare,
  Flag,
  ShieldAlert,
  Radio,
  CheckCircle2,
  Zap,
  RotateCcw,
  AlertTriangle,
} from "lucide-react";

import { KpiTile } from "@/components/admin/kpi-tile";
import { StatCard } from "@/components/admin/stat-card";
import { TopSourcesCard } from "@/components/admin/top-sources-card";
import { ActivityTrendChart } from "@/components/admin/activity-trend-chart";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import {
  deltaPct,
  fetchAdminActivityTrend,
  fetchAdminDashboardMetrics,
  fetchAdminDashboardTrends,
  fetchSignupCounts,
} from "@/lib/admin-metrics";

/**
 * 0/1-5/>5 traffic-light status, shared by Section 1's combined
 * "ต้องดำเนินการ" tile and Section 6's per-queue tiles -- exact
 * thresholds from the Admin Dashboard restructure spec ("0 = ปกติ,
 * 1-5 = ต้องตรวจสอบ, มากกว่า 5 = ต้องดำเนินการ").
 */
function actionStatusFor(count: number): { level: "ok" | "watch" | "urgent"; label: string } {
  if (count === 0) return { level: "ok", label: "ปกติ" };
  if (count <= 5) {
    return { level: "watch", label: `มี ${count.toLocaleString("th-TH")} รายการที่ต้องตรวจสอบ` };
  }
  return { level: "urgent", label: `มี ${count.toLocaleString("th-TH")} รายการที่ต้องดำเนินการ` };
}

/**
 * Admin Dashboard restructure (Founder spec, 2026-09-05): a full
 * reflow of the Dashboard around 7 sections, priority-ordered so the
 * platform's state reads in a few seconds instead of scrolling past a
 * wall of equally-sized cards --
 *
 * 1. ภาพรวมวันนี้ -- the 4 things that matter most, first, each
 *    clickable through to its own detail page where one exists.
 * 2. ผู้ใช้งาน -- DAU/WAU/MAU (now calendar-anchored, see
 *    admin_dashboard_metrics()'s comment) + a 7/30/90-day trend.
 * 3. สมาชิกใหม่ -- signup counts by calendar period, "ทั้งหมด" added.
 * 4. เนื้อหาและ Engagement -- today's content activity + its own trend.
 * 5. การสื่อสารและกิจกรรม -- only real metrics (messages_today,
 *    active_conversations); no invented "recent activity" feed.
 * 6. สิ่งที่ต้องดำเนินการ -- the queues an Admin/Moderator actually
 *    works from, each with its own status. System Alerts has no real
 *    metric behind it yet (this app has no monitoring/alerting at
 *    all) -- shown as a disabled placeholder, never a fake "0",
 *    exactly per the spec's "ห้ามสร้างข้อมูล ... หากระบบยังไม่มี Metric
 *    จริง".
 * 7. Growth & Retention -- the funnel, for Management/Executive
 *    analysis, unchanged in substance from the existing WYN-077 work
 *    (still real cohort data, still null instead of a misleading "0%"
 *    for an empty cohort) but redrawn as an explicit flow per the spec.
 *
 * Every vs-yesterday delta on this page reads from
 * AdminDashboardTrends' *_yesterday_matched fields, never the plain
 * *_yesterday ones -- see that type's own doc comment for why a
 * still-in-progress "today" can only fairly compare against yesterday
 * up to the same elapsed clock time, not yesterday in full.
 */
export async function DashboardMetrics() {
  const [m, t, s, activity] = await Promise.all([
    fetchAdminDashboardMetrics(),
    fetchAdminDashboardTrends(),
    fetchSignupCounts(),
    fetchAdminActivityTrend(90),
  ]);

  const engagementToday = m.likes_today + m.comments_today + m.redrops_today;
  const engagementYesterdayMatched =
    t.likes_yesterday_matched + t.comments_yesterday_matched + t.redrops_yesterday_matched;
  const actionNeeded = m.reports_pending + m.appeals_pending;
  const overallStatus = actionStatusFor(actionNeeded);

  return (
    <div className="flex flex-col gap-8 p-6">
      {/* Section 1 -- ภาพรวมวันนี้ */}
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">ภาพรวมวันนี้</h2>
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
          <KpiTile
            label="ผู้ใช้งานวันนี้"
            value={m.dau}
            icon={Users}
            sublabel="Active Users"
            href="/users"
            deltaPct={deltaPct(m.dau, t.active_users_yesterday_matched)}
          />
          <KpiTile
            label="ผู้ใช้ใหม่วันนี้"
            value={m.new_users_today}
            icon={UserPlus}
            sublabel="New Users"
            href="/users"
            deltaPct={deltaPct(m.new_users_today, t.new_users_yesterday_matched)}
          />
          <KpiTile
            label="Engagement วันนี้"
            value={engagementToday}
            icon={Zap}
            sublabel="Interactions"
            deltaPct={deltaPct(engagementToday, engagementYesterdayMatched)}
          />
          <KpiTile
            label="ต้องดำเนินการ"
            value={actionNeeded}
            icon={AlertTriangle}
            href="/reports"
            status={overallStatus}
          />
        </div>
      </section>

      {/* Section 2 -- ผู้ใช้งาน */}
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">ผู้ใช้งาน</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          นับจากผู้ใช้ที่มีกิจกรรมบนแพลตฟอร์ม (โพสต์/ถูกใจ/คอมเมนต์/ReDrop/ส่งข้อความ) ไม่ใช่จำนวนครั้งที่เปิดแอป
          — ตามวันปฏิทินเวลาไทย: DAU = วันนี้ 00:00 ถึงตอนนี้, WAU/MAU = 7/30 วันปฏิทินล่าสุด (รวมวันนี้)
        </p>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          <StatCard label="DAU" value={m.dau} icon={Activity} sublabel="Active วันนี้" />
          <StatCard label="WAU" value={m.wau} icon={Activity} sublabel="Active ใน 7 วันล่าสุด" />
          <StatCard label="MAU" value={m.mau} icon={Activity} sublabel="Active ใน 30 วันล่าสุด" />
        </div>
        <ActivityTrendChart title="Active Users Trend" unitLabel="คน/วัน" days={activity} series="active_users" />
      </section>

      {/* Section 3 -- สมาชิกใหม่ */}
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">สมาชิกใหม่</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          จำนวนบัญชีที่สมัครสำเร็จ นับแยกตามช่วงเวลาปัจจุบัน (แต่ละช่วงนับซ้อนกัน เช่น &quot;เดือนนี้&quot;
          รวม &quot;วันนี้&quot; อยู่ในนั้นแล้ว) — สัปดาห์เริ่มวันจันทร์ เวลาไทย
        </p>
        <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-5">
          <StatCard label="วันนี้" value={s.today} icon={UserPlus} />
          <StatCard label="สัปดาห์นี้" value={s.this_week} icon={UserPlus} />
          <StatCard label="เดือนนี้" value={s.this_month} icon={UserPlus} />
          <StatCard label="ปีนี้" value={s.this_year} icon={UserPlus} />
          <StatCard label="ทั้งหมด" value={s.all_time} icon={UserPlus} />
        </div>
      </section>

      {/* Section 4 -- เนื้อหาและ Engagement */}
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">เนื้อหาและการมีส่วนร่วม</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          กิจกรรมวันนี้ (นับตั้งแต่ 00:00 น. เวลาไทย) — Club เดียวที่นับ &quot;ทั้งหมด&quot; แทน
          &quot;วันนี้&quot; เพราะเป็นตัวเลขสะสม ไม่ใช่กิจกรรมรายวัน
        </p>
        <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
          <StatCard
            label="Drop"
            value={m.drops_today}
            icon={ImageIcon}
            deltaPct={deltaPct(m.drops_today, t.drops_yesterday_matched)}
          />
          <StatCard
            label="ยอดดู Drop"
            value={m.views_today}
            icon={Eye}
            deltaPct={deltaPct(m.views_today, t.views_yesterday_matched)}
          />
          <StatCard
            label="ถูกใจ"
            value={m.likes_today}
            icon={Heart}
            deltaPct={deltaPct(m.likes_today, t.likes_yesterday_matched)}
          />
          <StatCard
            label="คอมเมนต์"
            value={m.comments_today}
            icon={MessageCircle}
            deltaPct={deltaPct(m.comments_today, t.comments_yesterday_matched)}
          />
          <StatCard
            label="ReDrop"
            value={m.redrops_today}
            icon={Repeat2}
            deltaPct={deltaPct(m.redrops_today, t.redrops_yesterday_matched)}
          />
          <StatCard
            label="Club"
            value={m.clubs_total}
            icon={Users}
            secondaryValue={m.clubs_new_today}
            secondaryLabel="สร้างใหม่วันนี้ (เวลาไทย)"
          />
        </div>
        <ActivityTrendChart title="Engagement Trend" unitLabel="ครั้ง/วัน" days={activity} series="engagement" />
      </section>

      {/* Section 5 -- การสื่อสารและกิจกรรม */}
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">การสื่อสารและกิจกรรม</h2>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <StatCard
            label="ข้อความใหม่"
            value={m.messages_today}
            icon={Mail}
            sublabel="วันนี้ (เวลาไทย)"
            deltaPct={deltaPct(m.messages_today, t.messages_yesterday_matched)}
          />
          <StatCard
            label="การสนทนาที่ Active"
            value={m.active_conversations}
            icon={MessagesSquare}
          />
        </div>
      </section>

      {/* Section 6 -- สิ่งที่ต้องดำเนินการ */}
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">สิ่งที่ต้องดำเนินการ</h2>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          <KpiTile
            label="Reports Pending"
            value={m.reports_pending}
            icon={Flag}
            href="/reports"
            status={actionStatusFor(m.reports_pending)}
          />
          <KpiTile
            label="Moderation Pending"
            value={m.appeals_pending}
            icon={ShieldAlert}
            sublabel="อุทธรณ์ที่รอการตัดสิน"
            status={actionStatusFor(m.appeals_pending)}
          />
          <Card className="opacity-60">
            <CardHeader className="flex-row items-start justify-between space-y-0">
              <span className="text-sm font-medium text-muted-foreground">System Alerts</span>
              <Radio className="size-4 text-zinc-400" aria-hidden="true" />
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                ยังไม่มีระบบ Monitoring/Alert ในแพลตฟอร์มนี้ — จะเพิ่มตัวเลขจริงเมื่อมี Metric รองรับ
              </p>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Section 7 -- Growth & Retention */}
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">การเติบโตและ Retention</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          D1/D7 Retention นับจากผู้ใช้ที่สมัครสำเร็จเมื่อ 2-3 / 8-9 วันก่อน (ให้เวลาครบรอบพอดี ไม่ใช่ของวันนี้) และ
          &quot;กลับมา&quot; หมายถึงมีกิจกรรมจริงบนแพลตฟอร์ม ไม่ใช่แค่เปิดเว็บทิ้งไว้ · ช่องทางนับจากลิงก์ที่มี UTM
          parameter เท่านั้น
        </p>
        <div className="flex flex-col gap-2">
          <StatCard label="สมัครใหม่" value={m.signup_started_24h} icon={UserPlus} sublabel="ใน 24 ชม.ล่าสุด" />
          <p className="text-center text-muted-foreground" aria-hidden="true">↓</p>
          <StatCard
            label="สมัครสำเร็จ"
            value={m.signup_completed_24h}
            icon={CheckCircle2}
            secondaryValue={m.signup_conversion_pct ?? 0}
            secondaryLabel="อัตราสมัครสำเร็จ (%)"
          />
          <p className="text-center text-muted-foreground" aria-hidden="true">↓</p>
          <StatCard
            label="Activation"
            value={m.activation_pct_24h ?? 0}
            icon={Zap}
            secondaryValue={m.activation_count_24h}
            secondaryLabel="คน"
          />
          <p className="text-center text-muted-foreground" aria-hidden="true">↓</p>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <StatCard label="D1 Retention" value={m.retention_d1_pct ?? 0} icon={RotateCcw} sublabel="% กลับมาใช้วันที่ 1" />
            <StatCard label="D7 Retention" value={m.retention_d7_pct ?? 0} icon={RotateCcw} sublabel="% กลับมาใช้วันที่ 7" />
          </div>
        </div>
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-4">
          <TopSourcesCard sources={m.top_sources} />
        </div>
      </section>
    </div>
  );
}
