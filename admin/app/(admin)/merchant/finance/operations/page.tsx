import Link from "next/link";
import { NoAccess } from "@/components/admin/no-access";
import { FinanceOperationsPanel } from "@/components/admin/finance-operations-panel";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function FinanceOperationsPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "merchant")) return <NoAccess what="การเงินร้านค้า" />;
  return <main className="space-y-6 p-4 sm:p-6"><Link href="/merchant/finance">กลับภาพรวมการเงินและตั้งค่า GP</Link>
    <h1 className="text-xl font-semibold">ตรวจยอด คืนเงิน และปรับยอดร้าน</h1>
    <FinanceOperationsPanel userId={ctx.userId} canEdit={adminCan(ctx, "merchant", "edit")} />
  </main>;
}
