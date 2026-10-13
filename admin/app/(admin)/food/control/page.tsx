import { AdminControlCenter } from "@/components/admin/control-center";
import { NoAccess } from "@/components/admin/no-access";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function FoodControlPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food")) return <NoAccess what="ควบคุม WYNOS Food" />;
  return <AdminControlCenter area="food" ctx={ctx} />;
}
