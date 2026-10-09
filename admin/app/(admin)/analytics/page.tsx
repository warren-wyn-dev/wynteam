import Link from "next/link";
import { BarChart3, ArrowUpRight, RefreshCcw, ShieldCheck } from "lucide-react";
import {
  fetchAdminAnalytics,
  type AnalyticsPanel,
  type AnalyticsPoint,
} from "@/lib/admin-analytics";
import { requireAdminRole } from "@/lib/auth";
import { notFound } from "next/navigation";

const nf = new Intl.NumberFormat("th-TH", { maximumFractionDigits: 2 });

function TrendRows({ points, label }: { points: AnalyticsPoint[]; label: string }) {
  if (points.length === 0) {
    return <p className="text-sm text-muted-foreground">ไม่มีข้อมูลแนวโน้มจากแหล่งข้อมูลที่ตรวจสอบได้</p>;
  }
  const max = Math.max(1, ...points.map((p) => p.count));
  return (
    <div role="group" aria-label={label} className="space-y-2">
      {points.map((point) => (
        <div key={point.day} className="grid grid-cols-[4.6rem_minmax(0,1fr)_3.5rem] items-center gap-3 text-xs sm:grid-cols-[6rem_minmax(0,1fr)_4rem]">
          <time dateTime={point.day} className="truncate text-muted-foreground">
            {new Date(point.day + "T00:00:00Z").toLocaleDateString("th-TH", { day: "numeric", month: "short", timeZone: "UTC" })}
          </time>
          <div className="h-3 overflow-hidden rounded-full bg-muted" aria-hidden="true">
            <div className="h-full rounded-full bg-foreground/70" style={{ width: `${(point.count / max) * 100}%` }} />
          </div>
          <span className="text-right font-medium tabular-nums">{nf.format(point.count)}</span>
        </div>
      ))}
    </div>
  );
}

function AnalyticsCard({ panel }: { panel: AnalyticsPanel }) {
  return (
    <article className="flex min-w-0 flex-col gap-4 rounded-xl border bg-background p-4 sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="space-y-1">
          <h2 className="font-semibold">{panel.title}</h2>
          <p className="text-xs text-muted-foreground">แหล่งข้อมูล: {panel.source}</p>
        </div>
        <span className="rounded-full bg-muted px-2.5 py-1 text-xs text-muted-foreground">
          {panel.status === "ready" ? "ข้อมูลจากระบบจริง" : "ตรวจสอบไม่ได้"}
        </span>
      </div>
      {panel.status === "unavailable" ? (
        <p role="status" className="rounded-lg border border-dashed p-3 text-sm text-muted-foreground">
          {panel.note}
        </p>
      ) : (
        <>
          {panel.metrics.length > 0 ? (
            <dl className="grid grid-cols-2 gap-3">
              {panel.metrics.map((metric) => (
                <div key={metric.label} className="min-w-0 rounded-lg bg-muted/40 p-3">
                  <dt className="text-xs leading-relaxed text-muted-foreground">{metric.label}</dt>
                  <dd className="mt-1 break-words text-xl font-semibold tabular-nums">
                    {nf.format(metric.count)}{metric.unit ? ` ${metric.unit}` : ""}
                  </dd>
                </div>
              ))}
            </dl>
          ) : null}
          {panel.trend && panel.trendLabel ? (
            <section className="space-y-3" aria-label={panel.trendLabel}>
              <h3 className="text-sm font-medium">{panel.trendLabel}</h3>
              <TrendRows points={panel.trend} label={panel.trendLabel} />
            </section>
          ) : null}
          <p className="text-xs leading-relaxed text-muted-foreground">{panel.note}</p>
        </>
      )}
      <p className="mt-auto border-t pt-3 text-xs text-muted-foreground">
        เริ่มตรวจเมื่อ {new Date(panel.checkedAt).toLocaleString("th-TH", {
          timeZone: "Asia/Bangkok", dateStyle: "medium", timeStyle: "short",
        })}
      </p>
    </article>
  );
}

/**
 * Read-only Analytics Center, deliberately Admin-only in MVP.
 * Live staff authentication is checked in the page AND service before RPCs.
 */
export default async function AdminAnalyticsCenterPage() {
  const { role } = await requireAdminRole();
  if (role !== "admin") notFound();

  const panels = await fetchAdminAnalytics();

  return (
    <div className="flex flex-col gap-5 p-4 sm:p-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="space-y-2">
          <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            WYNOS Admin · Analytics Center
          </p>
          <h1 className="text-2xl font-semibold tracking-tight">รายงานภาพรวม WYNOS</h1>
          <p className="max-w-3xl text-sm leading-relaxed text-muted-foreground">
            เปรียบเทียบแนวโน้มภายในแต่ละบริการโดยแยกหน่วยและช่วงเวลา
            ไม่มีคะแนนรวมหรือยอดสมมติที่นำข้อมูลคนละประเภทมาบวกกัน
          </p>
        </div>
        <Link href="/analytics" className="inline-flex min-h-11 items-center gap-2 rounded-lg border bg-background px-3 text-sm font-medium hover:bg-accent">
          <RefreshCcw aria-hidden="true" className="size-4" /> ตรวจข้อมูลอีกครั้ง
        </Link>
      </header>

      <div role="note" className="flex items-start gap-2 rounded-xl border bg-background p-4 text-xs leading-relaxed text-muted-foreground">
        <ShieldCheck aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
        <p>เฉพาะ Admin · ทุกตัวเลขอ่านจาก RPC ตามสิทธิ์ปัจจุบัน
          เมื่อไม่มีข้อมูลหรือระบบไม่พร้อมจะไม่แทนค่าด้วยศูนย์
          ตัวเลขสมัครสมาชิกและออเดอร์ใช้คำนิยาม/ช่วงเวลาของแหล่งข้อมูลต้นทางแต่ละบริการ</p>
      </div>

      <section aria-label="สถิติบริการ WYNOS" className="grid items-start gap-4 lg:grid-cols-2">
        {panels.map((panel) => <AnalyticsCard key={panel.id} panel={panel} />)}
      </section>

      <p className="flex items-start gap-2 text-xs leading-relaxed text-muted-foreground">
        <BarChart3 aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
        Analytics Center รุ่นแรกเป็นรายงานอ่านอย่างเดียว ไม่มีการส่งออกข้อมูล
        หรือการเปิดดูออเดอร์/ข้อมูลติดต่อจากหน้านี้
        สำหรับรายงานเชิงลึกเพิ่มเติม โปรดใช้ Dashboard ของแต่ละ Workspace
        <ArrowUpRight aria-hidden="true" className="mt-0.5 size-3 shrink-0" />
      </p>
    </div>
  );
}
