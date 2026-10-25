import { ADMIN_LEVEL_LABEL, ADMIN_SYSTEM_LABEL } from "@/lib/admin-systems";
import { ZOKY_SYSTEMS, requireAdminRole } from "@/lib/auth";

/**
 * ZOKY Admin overview: which ZOKY systems the signed-in account can use.
 * Each system's numbers live on its own dashboard (/food, /merchant).
 */
export default async function OverviewPage() {
  const { access } = await requireAdminRole();

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <section className="rounded-xl border bg-background p-5">
        <h2 className="text-lg font-semibold">ยินดีต้อนรับสู่ ZOKY Admin</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          หลังบ้านของ ZOKY Food และ ZOKY Merchant (ย้ายมาจาก WYNOS Admin) — เลือกเมนูจากแถบด้านข้าง
          ส่วน Account, Social, Maps และ Audit Log ยังอยู่ที่ WYNOS Admin
        </p>
      </section>

      <section aria-labelledby="zoky-access-heading" className="rounded-xl border bg-background p-5">
        <h2 id="zoky-access-heading" className="text-base font-semibold">
          สิทธิ์ของคุณ
        </h2>
        <ul className="mt-3 flex flex-col gap-2">
          {ZOKY_SYSTEMS.map((system) => {
            const level = access.superAdmin ? "edit" : access.permissions[system];
            return (
              <li key={system} className="flex min-h-11 items-center justify-between gap-3 rounded-md bg-muted/50 px-3">
                <span className="text-sm font-medium">{ADMIN_SYSTEM_LABEL[system]}</span>
                <span className="text-sm text-muted-foreground">{level ? ADMIN_LEVEL_LABEL[level] : "ไม่มีสิทธิ์"}</span>
              </li>
            );
          })}
          {access.teamLead ? (
            <li className="flex min-h-11 items-center justify-between gap-3 rounded-md bg-muted/50 px-3">
              <span className="text-sm font-medium">หัวหน้าทีม ZOKY</span>
              <span className="text-sm text-muted-foreground">จัดการสมาชิกและสิทธิ์ได้</span>
            </li>
          ) : null}
        </ul>
      </section>
    </div>
  );
}
