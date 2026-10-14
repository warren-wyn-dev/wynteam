import { AlertTriangle, KeyRound, ShieldCheck } from "lucide-react";

import type { AccountSecurityOverview } from "@/lib/admin-account-security";
import { ADMIN_SYSTEM_LABEL } from "@/lib/admin-systems";

export function AccountSecurityOverviewPanel({ overview }: { overview: AccountSecurityOverview }) {
  const { assurance, factors } = overview;
  const failed = [!assurance && "ระดับการยืนยันเซสชัน", !factors && "สถานะ MFA ของคุณ"].filter(Boolean);

  return (
    <div className="flex flex-col gap-6">
      {failed.length > 0 ? (
        <p role="alert" className="flex items-start gap-2 rounded-xl border p-4 text-sm text-muted-foreground">
          <AlertTriangle className="mt-0.5 size-4 shrink-0" aria-hidden />
          {`อ่านข้อมูลบางส่วนไม่สำเร็จ: ${failed.join(", ")} กรุณากดรีเฟรชเพื่อลองใหม่`}
        </p>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-2">
        <section aria-labelledby="account-session-heading" className="rounded-xl border bg-background p-5">
          <h3 id="account-session-heading" className="flex items-center gap-2 font-semibold">
            <ShieldCheck className="size-4 shrink-0" aria-hidden /> เซสชันที่คุณกำลังใช้งาน
          </h3>
          <p className="mt-4 text-lg font-semibold">
            {assurance ? assurance.currentLevel === "aal2" ? "ยืนยันด้วย MFA แล้ว" : "ยืนยันขั้นแรกแล้ว" : "ยังยืนยันสถานะไม่ได้"}
          </p>
          <p className="mt-2 text-sm text-muted-foreground">
            {assurance?.currentLevel === "aal2"
              ? "เซสชันนี้ผ่านการเข้าสู่ระบบและการยืนยันหลายปัจจัยแล้ว"
              : assurance?.currentLevel === "aal1"
                ? "เซสชันนี้ยังไม่ได้ยืนยันหลายปัจจัย แม้บัญชีอาจตั้งค่า MFA ไว้แล้ว"
                : "ยังไม่แสดงข้อสรุประดับการยืนยันจนกว่าจะอ่านข้อมูลสำเร็จ"}
          </p>
          {assurance?.currentLevel === "aal1" && assurance.nextLevel === "aal2" ? (
            <p className="mt-3 rounded-lg bg-muted/50 p-3 text-sm">บัญชีนี้มี MFA ที่พร้อมใช้ แต่เซสชันปัจจุบันยังไม่ได้ยืนยันด้วย MFA</p>
          ) : null}
        </section>

        <section aria-labelledby="account-factors-heading" className="rounded-xl border bg-background p-5">
          <h3 id="account-factors-heading" className="flex items-center gap-2 font-semibold">
            <KeyRound className="size-4 shrink-0" aria-hidden /> MFA ของบัญชีคุณ
          </h3>
          {factors ? (
            <>
              <p className="mt-4 text-lg font-semibold">
                {factors.verified > 0 ? `ยืนยันแล้ว ${factors.verified.toLocaleString("th-TH")} วิธี` : "ยังไม่มี MFA ที่ยืนยันแล้ว"}
              </p>
              <dl className="mt-3 grid grid-cols-[1fr_auto] gap-x-4 gap-y-2 text-sm">
                <dt className="text-muted-foreground">แอปยืนยันตัวตน</dt><dd>{factors.totp.toLocaleString("th-TH")}</dd>
                <dt className="text-muted-foreground">โทรศัพท์</dt><dd>{factors.phone.toLocaleString("th-TH")}</dd>
                <dt className="text-muted-foreground">Passkey / อุปกรณ์ยืนยันตัวตน</dt><dd>{factors.webauthn.toLocaleString("th-TH")}</dd>
                <dt className="text-muted-foreground">เริ่มตั้งค่าแต่ยังไม่ยืนยัน</dt><dd>{factors.unverified.toLocaleString("th-TH")}</dd>
              </dl>
            </>
          ) : (
            <p className="mt-4 text-sm text-muted-foreground">ยังอ่านจำนวนวิธียืนยันตัวตนไม่ได้</p>
          )}
          <p className="mt-4 text-xs text-muted-foreground">แสดงเฉพาะจำนวนของบัญชีคุณ โดยไม่แสดงหมายเลขโทรศัพท์หรือข้อมูลสำหรับตั้งค่า MFA</p>
        </section>
      </div>

      <section aria-labelledby="account-access-heading" className="flex flex-col gap-3">
        <h3 id="account-access-heading" className="font-semibold">สิทธิ์ดูแลระบบของคุณ</h3>
        <p className="text-sm text-muted-foreground">
          {overview.superAdmin ? "Super admin เข้าถึงได้ทุกระบบ"
            : overview.permissionSource === "system" ? "สิทธิ์รายระบบที่กำหนดให้บัญชีคุณ การแก้ไขรวมสิทธิ์ดูด้วย"
              : "ยังยืนยันสิทธิ์รายระบบไม่ได้ รายการนี้แสดงการเข้าถึงเมนูตามบทบาทเดิม และไม่ยืนยันสิทธิ์ข้อมูลในฐานข้อมูล"}
        </p>
        <div className="overflow-x-auto rounded-xl border bg-background">
          <table className="w-full text-left text-sm">
            <caption className="sr-only">สิทธิ์ดูและแก้ไขแต่ละระบบของบัญชีที่กำลังใช้งาน</caption>
            <thead className="border-b bg-muted/30">
              <tr><th scope="col" className="p-3 font-medium">ระบบ</th><th scope="col" className="p-3 font-medium">สิทธิ์</th></tr>
            </thead>
            <tbody className="divide-y">
              {overview.permissions.map((permission) => (
                <tr key={permission.system}>
                  <th scope="row" className="p-3 font-medium">{ADMIN_SYSTEM_LABEL[permission.system]}</th>
                  <td className="p-3">{permission.edit ? "ดูและแก้ไข" : permission.view ? "ดูอย่างเดียว" : "ไม่มีสิทธิ์"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section aria-labelledby="account-security-scope-heading" className="rounded-xl border border-dashed p-5 text-sm text-muted-foreground">
        <h3 id="account-security-scope-heading" className="font-semibold text-foreground">ขอบเขตข้อมูลในหน้านี้</h3>
        <p className="mt-2">แสดงสถานะบัญชีและเซสชันของคุณแบบอ่านอย่างเดียว ไม่ใช่รายงานความปลอดภัยของทุกบัญชี</p>
        <p className="mt-2">การเปิดใช้หรือบังคับ MFA ทั้งแพลตฟอร์ม การแก้ไขนโยบาย และการจัดการเซสชันของบัญชีอื่นยังไม่ได้ให้บริการในหน้านี้</p>
      </section>
    </div>
  );
}
