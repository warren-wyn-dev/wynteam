import { Suspense } from "react";
import { ShieldCheck } from "lucide-react";

import { AccountSecurityOverviewPanel } from "@/components/admin/account-security-overview";
import { NoAccess } from "@/components/admin/no-access";
import { RefreshButton } from "@/components/admin/refresh-button";
import { fetchAccountSecurityOverview } from "@/lib/admin-account-security";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function AccountSecurityPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "account")) return <NoAccess what="ดูความปลอดภัยบัญชี" />;

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <section className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex min-w-0 flex-col gap-2">
          <h2 className="flex items-center gap-2 text-xl font-semibold">
            <ShieldCheck className="size-5 shrink-0" aria-hidden /> ความปลอดภัยบัญชี
          </h2>
          <p className="text-sm text-muted-foreground">ตรวจสถานะการยืนยันตัวตนและสิทธิ์ของบัญชีที่คุณกำลังใช้งาน</p>
        </div>
        <RefreshButton />
      </section>
      <Suspense fallback={<p role="status" className="rounded-xl border p-6 text-sm text-muted-foreground">กำลังอ่านสถานะความปลอดภัยบัญชีของคุณ...</p>}>
        <AccountSecurityDetails />
      </Suspense>
    </div>
  );
}

async function AccountSecurityDetails() {
  let overview;
  try {
    overview = await fetchAccountSecurityOverview();
  } catch {
    return <p role="alert" className="rounded-xl border p-5 text-sm text-muted-foreground">อ่านสถานะความปลอดภัยไม่สำเร็จ กรุณากดรีเฟรชเพื่อลองใหม่</p>;
  }
  return <AccountSecurityOverviewPanel overview={overview} />;
}
