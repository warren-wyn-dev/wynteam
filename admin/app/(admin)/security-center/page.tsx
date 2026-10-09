import Link from "next/link";
import { notFound } from "next/navigation";
import { KeyRound, LockKeyhole, ShieldCheck, Smartphone, CircleHelp } from "lucide-react";

import { requireAdminRole } from "@/lib/auth";
import { fetchOwnAdminSecuritySnapshot } from "@/lib/admin-security-snapshot";

export default async function AdminSecurityCenterPage() {
  await requireAdminRole();
  // Explicit build-time rollout gate; default is OFF.
  if (process.env.NEXT_PUBLIC_ADMIN_SECURITY_CENTER_ENABLED !== "true") notFound();

  const snapshot = await fetchOwnAdminSecuritySnapshot();
  const available = snapshot.mfa.status === "available";
  const count = snapshot.mfa.verifiedTotp;
  const status = !available || count === null
    ? "ยังตรวจสอบไม่ได้"
    : count > 0 ? "มี Authenticator ที่ยืนยันแล้ว" : "ไม่พบ Authenticator ที่ยืนยันแล้ว";

  return (
    <div className="flex flex-col gap-5 p-4 sm:p-6">
      <header className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          WYNOS Admin · ระบบส่วนกลาง
        </p>
        <h1 className="text-2xl font-semibold tracking-tight">ความปลอดภัยของบัญชีผู้ดูแล</h1>
        <p className="text-sm leading-relaxed text-muted-foreground">
          ตรวจสอบสถานะบัญชีที่เข้าสู่ระบบอยู่ โดยไม่แสดงรหัสผ่าน โทเคน
          ข้อมูลอุปกรณ์อื่น หรือรหัสสำรอง
        </p>
      </header>

      <section aria-label="สถานะความปลอดภัยของบัญชี" className="grid gap-4 md:grid-cols-2">
        <article className="rounded-xl border bg-background p-4 sm:p-5">
          <h2 className="flex items-center gap-2 font-semibold">
            <ShieldCheck aria-hidden="true" className="size-4" />
            เซสชันปัจจุบัน
          </h2>
          <p className="mt-3 text-sm font-medium">ยืนยันตัวตนและสิทธิ์เจ้าหน้าที่แล้ว</p>
          <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
            ตรวจสอบตัวตนด้วย Supabase Auth และสิทธิ์จากระบบฝั่ง Server
            การเปิดหน้านี้ไม่ได้ยืนยันอุปกรณ์อื่นหรือเซสชันทั้งหมดของบัญชี
          </p>
        </article>
        <article className="rounded-xl border bg-background p-4 sm:p-5">
          <h2 className="flex items-center gap-2 font-semibold">
            <KeyRound aria-hidden="true" className="size-4" />
            Authenticator (MFA)
          </h2>
          <p className="mt-3 text-sm font-medium">{status}</p>
          <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
            {available && count !== null
              ? `ปัจจัย TOTP ที่ยืนยันแล้ว ${count} รายการ`
              : "ไม่สามารถอ่านข้อมูลจากผู้ให้บริการยืนยันตัวตนได้ในขณะนี้"}
          </p>
          <p className="mt-2 text-xs text-muted-foreground">
            ระดับการยืนยันปัจจุบัน: {
              snapshot.mfa.assurance === "aal2" ? "AAL2"
                : snapshot.mfa.assurance === "aal1" ? "AAL1" : "ยังตรวจสอบไม่ได้"
            }
          </p>
        </article>
        <article className="rounded-xl border bg-background p-4 sm:p-5">
          <h2 className="flex items-center gap-2 font-semibold">
            <Smartphone aria-hidden="true" className="size-4" />
            อุปกรณ์และเซสชันอื่น
          </h2>
          <p className="mt-3 flex items-center gap-2 text-sm font-medium">
            <CircleHelp aria-hidden="true" className="size-4" /> ยังตรวจสอบไม่ได้
          </p>
          <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
            ยังไม่มีแหล่งข้อมูลที่ตรวจรับสำหรับแสดงหรือยกเลิกเซสชันรายอุปกรณ์
            จึงไม่แสดงรายการอุปกรณ์จำลอง
          </p>
        </article>
        <article className="rounded-xl border bg-background p-4 sm:p-5">
          <h2 className="flex items-center gap-2 font-semibold">
            <LockKeyhole aria-hidden="true" className="size-4" />
            การตั้งค่า MFA และการกู้คืนบัญชี
          </h2>
          <p className="mt-3 text-sm text-muted-foreground">
            อยู่ระหว่างเตรียมการทดสอบบน Staging ยังไม่มีปุ่มเปิด ปิด หรือบังคับใช้ MFA
            จนกว่าจะได้รับอนุมัติขั้นตอนการกู้คืนและนโยบายความปลอดภัย
          </p>
        </article>
      </section>

      <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border bg-background p-4 text-xs text-muted-foreground">
        <span>ตรวจจากบัญชีปัจจุบันเมื่อ {
          new Date(snapshot.checkedAt).toLocaleString("th-TH", {
            timeZone: "Asia/Bangkok", dateStyle: "medium", timeStyle: "short",
          })
        }</span>
        <Link href="/audit-log" className="inline-flex min-h-11 items-center text-sm font-medium text-foreground underline-offset-4 hover:underline">
          ไปยังประวัติการดำเนินงาน
        </Link>
      </div>
    </div>
  );
}
