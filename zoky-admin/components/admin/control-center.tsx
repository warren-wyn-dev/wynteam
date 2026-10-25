import Link from "next/link";
import { ArrowUpRight, CheckCircle2, CircleDashed, LockKeyhole, Settings2, ShieldCheck } from "lucide-react";

import { adminCan, type AdminContext } from "@/lib/auth";
import {
  FOOD_CONTROLS,
  MERCHANT_CONTROLS,
  SHARED_CONTROLS,
  controlCount,
  type ControlArea,
  type ControlGroup,
  type ControlItem,
} from "@/lib/admin-control-catalog";
import { DeliveryPolicyPreview } from "@/components/admin/delivery-policy-preview";

function availableFor(ctx: AdminContext, area: ControlArea, item: ControlItem) {
  if (item.superAdminOnly && !ctx.access.superAdmin) return false;
  return adminCan(ctx, item.access ?? area, item.editOnly ? "edit" : "view");
}

function ModuleGroups({
  groups,
  area,
  ctx,
}: {
  groups: ControlGroup[];
  area: ControlArea;
  ctx: AdminContext;
}) {
  return (
    <div className="space-y-5">
      {groups.map((group) => (
        <section key={group.name} className="overflow-hidden rounded-2xl border bg-background">
          <h3 className="border-b bg-muted/30 px-5 py-4 text-sm font-semibold">{group.name}</h3>
          <ul className="divide-y">
            {group.items.map((item) => {
              const allowed = availableFor(ctx, area, item);
              const canOpen = Boolean(item.href && allowed);
              return (
                <li key={item.name} className="flex flex-wrap items-center justify-between gap-3 px-5 py-4 sm:flex-nowrap">
                  <div className="min-w-0 space-y-1">
                    <p className="text-sm font-medium">{item.name}</p>
                    <p className="text-xs leading-relaxed text-muted-foreground">{item.description}</p>
                  </div>
                  {canOpen ? (
                    <Link
                      href={item.href!}
                      className="inline-flex min-h-10 shrink-0 items-center gap-1.5 rounded-lg border px-3 text-xs font-semibold hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                      aria-label={`เปิด ${item.name}`}
                    >
                      เปิดเครื่องมือ <ArrowUpRight aria-hidden className="size-3.5" />
                    </Link>
                  ) : item.href && !allowed ? (
                    <span className="inline-flex shrink-0 items-center gap-1 rounded-full bg-muted px-3 py-1.5 text-xs text-muted-foreground">
                      <LockKeyhole className="size-3.5" aria-hidden /> จำกัดสิทธิ์
                    </span>
                  ) : (
                    <span className="inline-flex shrink-0 items-center gap-1 rounded-full border px-3 py-1.5 text-xs text-muted-foreground">
                      <CircleDashed className="size-3.5" aria-hidden /> รอพัฒนา
                    </span>
                  )}
                </li>
              );
            })}
          </ul>
        </section>
      ))}
    </div>
  );
}

export function AdminControlCenter({ area, ctx }: { area: ControlArea; ctx: AdminContext }) {
  const groups = area === "food" ? FOOD_CONTROLS : MERCHANT_CONTROLS;
  const hasFood = adminCan(ctx, "food");
  const hasMerchant = adminCan(ctx, "merchant");
  const liveCount = groups.flatMap((group) => group.items).filter((item) => item.href && availableFor(ctx, area, item)).length;
  const label = area === "food" ? "WYNOS Food" : "WYNOS Merchant";
  const subtitle = area === "food"
    ? "การจัดการฝั่งลูกค้า หน้าแรก คำสั่งซื้อ โปรโมชัน การชำระเงิน และบริการ"
    : "การจัดการร้าน เมนู แคมเปญ GP การเงิน ค่าส่ง และพื้นที่บริการ";

  return (
    <div className="flex flex-col gap-6 p-4 pb-12 sm:p-6">
      <header className="space-y-2">
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <Settings2 aria-hidden className="size-4" /> WYNOS Admin / ศูนย์ควบคุม
        </div>
        <h1 className="text-2xl font-bold tracking-tight">{label}</h1>
        <p className="max-w-3xl text-sm leading-relaxed text-muted-foreground">{subtitle}</p>
      </header>

      <nav aria-label="เลือกระบบ" className="flex flex-wrap gap-2">
        {hasFood ? <Link href="/food/control" aria-current={area === "food" ? "page" : undefined} className={`rounded-lg px-4 py-2.5 text-sm font-semibold ${area === "food" ? "bg-foreground text-background" : "border bg-background hover:bg-accent"}`}>Food</Link> : null}
        {hasMerchant ? <Link href="/merchant/control" aria-current={area === "merchant" ? "page" : undefined} className={`rounded-lg px-4 py-2.5 text-sm font-semibold ${area === "merchant" ? "bg-foreground text-background" : "border bg-background hover:bg-accent"}`}>Merchant</Link> : null}
      </nav>

      <div className="grid gap-3 sm:grid-cols-3">
        <Summary label="หมวดที่วางโครงสร้างไว้" value={controlCount(groups).toString()} />
        <Summary label="ลิงก์เครื่องมือที่มีอยู่" value={liveCount.toString()} />
        <Summary label="อยู่ในแผนพัฒนาต่อ" value={(controlCount(groups) - groups.flatMap((group) => group.items).filter((item) => item.href).length).toString()} />
      </div>

      <div className="rounded-xl border bg-muted/30 p-4 text-sm leading-relaxed">
        <p className="flex items-center gap-2 font-semibold"><ShieldCheck className="size-4" aria-hidden /> การควบคุมจริงและความปลอดภัย</p>
        <p className="mt-1 text-muted-foreground">
          ปุ่ม “เปิดเครื่องมือ” เชื่อมไปยังหน้าที่มีอยู่แล้วโดยใช้สิทธิ์และการตรวจสอบฝั่งเซิร์ฟเวอร์เดิม
          ส่วนรายการ “รอพัฒนา” ยังไม่เปลี่ยนข้อมูล Food หรือ Merchant และจะเปิดใช้เมื่อมี API, สิทธิ์, Audit Log และการทดสอบครบเท่านั้น
          บางหน้าที่มีอยู่แล้วอาจต้องรอการติดตั้ง backend หรือการกำหนดสิทธิ์เพิ่มเติม
        </p>
      </div>

      {area === "merchant" ? <DeliveryPolicyPreview /> : null}

      <div className="flex items-center justify-between gap-2">
        <h2 className="text-lg font-semibold">รายการควบคุม {label}</h2>
        <span className="text-xs text-muted-foreground">{controlCount(groups)} รายการ</span>
      </div>
      <ModuleGroups groups={groups} area={area} ctx={ctx} />

      <section className="space-y-3">
        <div className="flex items-center gap-2">
          <h2 className="text-lg font-semibold">ระบบร่วม Food / Merchant</h2>
          <CheckCircle2 className="size-4 text-muted-foreground" aria-hidden />
        </div>
        <p className="text-xs leading-relaxed text-muted-foreground">
          ระบบร่วมจำเป็นต้องพัฒนาที่ Backend/API กลาง เพื่อไม่ให้ข้อมูลออเดอร์ การเงิน และการจัดส่งของสองบริการขัดแย้งกัน
        </p>
        <ModuleGroups groups={SHARED_CONTROLS} area={area} ctx={ctx} />
      </section>
    </div>
  );
}

function Summary({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border bg-background p-4">
      <p className="text-xs leading-relaxed text-muted-foreground">{label}</p>
      <p className="mt-2 text-2xl font-semibold tabular-nums">{value}</p>
    </div>
  );
}
