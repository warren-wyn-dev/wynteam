import { ADMIN_LEVEL_LABEL, ADMIN_SYSTEM_LABEL } from "@/lib/admin-systems";
import { ZOKY_SYSTEMS, requireAdminRole } from "@/lib/auth";

/**
 * ZOKY Admin overview. Food and Merchant pages move here from WYNOS Admin
 * one PR at a time (ZOKY-ADMIN-001); until then this page only shows which
 * ZOKY systems the signed-in account can use.
 */
export default async function OverviewPage() {
  const { access } = await requireAdminRole();

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <section className="rounded-xl border bg-background p-5">
        <h2 className="text-lg font-semibold">ยินดีต้อนรับสู่ ZOKY Admin</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          หลังบ้านของ ZOKY Food และ ZOKY Merchant — หน้าต่างๆ กำลังย้ายมาจาก WYNOS Admin
          ระหว่างนี้เมนูที่ยังไม่ย้ายจะแสดงเป็น &ldquo;เร็วๆ นี้&rdquo;
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
        </ul>
      </section>
    </div>
  );
}
