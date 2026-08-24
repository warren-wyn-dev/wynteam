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
} from "lucide-react";

import { StatCard } from "@/components/admin/stat-card";
import { fetchAdminDashboardMetrics } from "@/lib/admin-metrics";

/**
 * The actual data-fetching grid, per Design spec's Screen -- lives in
 * its own async component (not inline in page.tsx) so `<Suspense>` in
 * page.tsx can show DashboardSkeleton while this specific fetch is in
 * flight, without delaying the rest of the page (header/refresh button).
 */
export async function DashboardMetrics() {
  const m = await fetchAdminDashboardMetrics();

  return (
    <div className="flex flex-col gap-6 p-6">
      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">ผู้ใช้งาน</h2>
        <p className="-mt-2 text-xs text-muted-foreground">
          DAU/WAU/MAU นับจากผู้ใช้ที่มีกิจกรรมบนแพลตฟอร์ม (โพสต์/ถูกใจ/คอมเมนต์/ReDrop/ส่งข้อความ)
          ไม่ใช่จำนวนครั้งที่เปิดแอป
        </p>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatCard label="ผู้ใช้ใหม่" value={m.new_users_today} icon={UserPlus} sublabel="ใน 24 ชม.ล่าสุด" />
          <StatCard label="DAU" value={m.dau} icon={Activity} sublabel="Active ใน 1 วัน" />
          <StatCard label="WAU" value={m.wau} icon={Activity} sublabel="Active ใน 7 วัน" />
          <StatCard label="MAU" value={m.mau} icon={Activity} sublabel="Active ใน 30 วัน" />
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">เนื้อหา</h2>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatCard label="Drop" value={m.drops_today} icon={ImageIcon} sublabel="ใน 24 ชม.ล่าสุด" />
          <StatCard label="ยอดดู Drop" value={m.views_today} icon={Eye} sublabel="ใน 24 ชม.ล่าสุด" />
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
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatCard label="ถูกใจ" value={m.likes_today} icon={Heart} sublabel="ใน 24 ชม.ล่าสุด" />
          <StatCard label="คอมเมนต์" value={m.comments_today} icon={MessageCircle} sublabel="ใน 24 ชม.ล่าสุด" />
          <StatCard label="ReDrop" value={m.redrops_today} icon={Repeat2} sublabel="ใน 24 ชม.ล่าสุด" />
          <StatCard label="ข้อความ" value={m.messages_today} icon={Mail} sublabel="ใน 24 ชม.ล่าสุด" />
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <h2 className="text-sm font-medium text-muted-foreground">รายงาน</h2>
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
    </div>
  );
}
