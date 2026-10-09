import Link from "next/link";
import { notFound } from "next/navigation";
import { Bell, ArrowUpRight, RefreshCcw, Info } from "lucide-react";

import { requireAdminRole } from "@/lib/auth";
import { fetchAdminWorkSignalFeed } from "@/lib/admin-notification-feed";

function formatDate(value: string) {
  const parsed = new Date(value);
  return Number.isNaN(parsed.valueOf()) ? "เวลาไม่พร้อม" : parsed.toLocaleString("th-TH", {
    timeZone: "Asia/Bangkok", dateStyle: "medium", timeStyle: "short",
  });
}

export default async function AdminNotificationsPage() {
  await requireAdminRole();
  // Pre-release preview gate: OFF unless a reviewed build opts in.
  if (process.env.NEXT_PUBLIC_ADMIN_NOTIFICATIONS_ENABLED !== "true") notFound();

  const feed = await fetchAdminWorkSignalFeed();

  return (
    <div className="flex flex-col gap-5 p-4 sm:p-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="space-y-2">
          <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            WYNOS Admin · ระบบส่วนกลาง
          </p>
          <h1 className="text-2xl font-semibold tracking-tight">แจ้งงานสำหรับผู้ดูแล</h1>
          <p className="max-w-3xl text-sm leading-relaxed text-muted-foreground">
            แสดงงานที่รอตรวจจากระบบต้นทางตามสิทธิ์ของคุณ รุ่นนี้ยังไม่มี
            การส่งแจ้งเตือนหรือสถานะอ่านแล้วแบบถาวร
          </p>
        </div>
        <Link href="/admin-notifications" className="inline-flex min-h-11 items-center gap-2 rounded-lg border bg-background px-3 text-sm font-medium hover:bg-accent">
          <RefreshCcw aria-hidden="true" className="size-4" /> ตรวจรายการอีกครั้ง
        </Link>
      </header>

      <div role="note" className="flex items-start gap-3 rounded-xl border bg-background p-4 text-sm text-muted-foreground">
        <Info aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
        <p>นี่คือภาพรวมรายการค้างดำเนินการ ไม่ใช่ Inbox ที่ได้รับแจ้งเตือนแล้ว
          จำนวนรายการไม่ใช่จำนวนยังไม่อ่าน และไม่มี Email Notifications</p>
      </div>

      <section aria-label="รายการงานจากระบบต้นทาง" className="grid gap-4 lg:grid-cols-2">
        {feed.sources.map((source) => (
          <article key={source.id} className="min-w-0 overflow-hidden rounded-xl border bg-background">
            <div className="flex items-center justify-between gap-2 border-b p-4">
              <h2 className="font-semibold">{source.label}</h2>
              <span className="rounded-lg bg-muted px-2.5 py-1 text-xs font-medium">
                {source.status === "ready" ? `${source.items.length} รายการล่าสุด` : "ตรวจสอบไม่ได้"}
              </span>
            </div>
            {source.status === "unavailable" ? (
              <p role="status" className="p-4 text-sm text-muted-foreground">
                แหล่งข้อมูลนี้ไม่พร้อมใช้งาน ไม่ได้หมายความว่าไม่มีงานค้าง
              </p>
            ) : source.items.length === 0 ? (
              <p className="p-4 text-sm text-muted-foreground">ไม่พบรายการรอตรวจในช่วงข้อมูลที่ดึงมา</p>
            ) : (
              <ul className="divide-y">
                {source.items.map((item) => (
                  <li key={item.key}>
                    <Link href={item.href} className="flex min-h-14 items-center justify-between gap-3 px-4 py-3 hover:bg-accent">
                      <span className="flex min-w-0 items-start gap-2">
                        <Bell aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
                        <span className="min-w-0">
                          <span className="block text-sm font-medium">{item.label}</span>
                          <span className="block text-xs text-muted-foreground">{formatDate(item.createdAt)}</span>
                        </span>
                      </span>
                      <ArrowUpRight aria-hidden="true" className="size-4 shrink-0 text-muted-foreground" />
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </article>
        ))}
      </section>
      <p className="text-xs text-muted-foreground">
        ตรวจข้อมูลเมื่อ {formatDate(feed.checkedAt)} · ไม่แสดงข้อมูลติดต่อร้านค้า
        หรือรายละเอียดผู้ร้องเรียน · ไม่มีการเปลี่ยนข้อมูลจากการเปิดหน้านี้
      </p>
    </div>
  );
}
