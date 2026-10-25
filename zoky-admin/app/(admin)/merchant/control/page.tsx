import { AdminControlCenter } from "@/components/admin/control-center";
import { NoAccess } from "@/components/admin/no-access";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function MerchantControlPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "merchant")) return <NoAccess what="ควบคุม WYNOS Merchant" />;
  return <AdminControlCenter area="merchant" ctx={ctx} />;
}
