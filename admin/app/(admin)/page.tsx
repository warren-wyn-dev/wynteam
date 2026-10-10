import { Suspense } from "react";

import { DashboardMetrics } from "@/components/admin/dashboard-metrics";
import { DashboardSkeleton } from "@/components/admin/dashboard-skeleton";
import { RefreshButton } from "@/components/admin/refresh-button";
import { NoAccess } from "@/components/admin/no-access";
import { adminCanAny, requireAdminRole } from "@/lib/auth";

export default async function DashboardPage() {
  const ctx = await requireAdminRole();
  if (!(adminCanAny(ctx))) return <NoAccess what="ดู Dashboard" />;
  return (
    <div className="flex flex-1 flex-col">
      <div className="flex justify-end px-6 pt-4">
        <RefreshButton />
      </div>
      <Suspense fallback={<DashboardSkeleton />}>
        <DashboardMetrics />
      </Suspense>
    </div>
  );
}
